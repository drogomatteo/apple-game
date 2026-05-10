extends Node

const BASE_URL := "https://alzheimer.magellan.fpms.ac.be/api/"
const DOCTOR_PATH := "doctor/?token="
const REQUEST_TIMEOUT_SECONDS := 5.0
const BIRTH_YEAR_KEYS := ["birth_year", "user_birth_year", "patient_birth_year", "patientBirthYear", "userBirthYear"]


func request(url: String, headers: PackedStringArray, method: int, body := "") -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS

	var error := http.request(url, headers, method, body)

	if error != OK:
		http.queue_free()
		return {
			"ok": false,
			"auth": true,
			"error": error,
			"result": HTTPRequest.RESULT_CANT_CONNECT,
			"code": 0,
			"body_text": ""
		}

	var response = await http.request_completed
	http.queue_free()

	var result := int(response[0])
	var code := int(response[1])
	var response_body: PackedByteArray = response[3]
	var body_text := response_body.get_string_from_utf8()

	return {
		"ok": result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300,
		"auth": true,
		"error": OK,
		"result": result,
		"code": code,
		"body_text": body_text
	}


func no_auth() -> Dictionary:
	return {
		"ok": false,
		"auth": false,
		"error": OK,
		"result": HTTPRequest.RESULT_CANT_CONNECT,
		"code": 0,
		"body_text": ""
	}


func get_user(token: String) -> Dictionary:
	if not await GameManager.get_valid_token():
		return no_auth()

	return await request(
		BASE_URL + "user/?token=" + token,
		GameManager.get_api_headers(),
		HTTPClient.METHOD_GET
	)


func get_doctor(doctor_token: String) -> Dictionary:
	if not await GameManager.get_valid_token():
		return no_auth()

	return await request(
		BASE_URL + DOCTOR_PATH + doctor_token,
		GameManager.get_api_headers(),
		HTTPClient.METHOD_GET
	)


func create_user(data: Dictionary) -> Dictionary:
	if not await GameManager.get_valid_token():
		return no_auth()

	return await request(
		BASE_URL + "user/",
		GameManager.get_json_post_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(user_payload(data))
	)


func user_payload(data: Dictionary) -> Dictionary:
	var payload := {
		"token": data.get("token", ""),
		"birth_year": data.get("birth_year", null),
		"user_birth_year": data.get("birth_year", null),
		"patient_birth_year": data.get("birth_year", null)
	}

	if data.has("uuid"):
		payload["uuid"] = data.get("uuid")

	var doctor_token := str(data.get("doctor_token", "")).strip_edges()
	if doctor_token != "":
		payload["doctor_token"] = doctor_token

	return payload


func parse(body_text: String) -> Variant:
	return JSON.parse_string(body_text)


func find_user(data: Variant, token: String) -> Dictionary:
	if typeof(data) == TYPE_DICTIONARY:
		if str(data.get("token", "")) == token:
			return data

		if data.has("results") and typeof(data["results"]) == TYPE_ARRAY:
			for item in data["results"]:
				if typeof(item) == TYPE_DICTIONARY and str(item.get("token", "")) == token:
					return item

	if typeof(data) == TYPE_ARRAY:
		for item in data:
			if typeof(item) == TYPE_DICTIONARY and str(item.get("token", "")) == token:
				return item

	return {}


func user_from_response(response: Dictionary, token: String) -> Dictionary:
	return find_user(parse(str(response.get("body_text", ""))), token)


func token_found(response: Dictionary, token: String) -> bool:
	if int(response.get("code", 0)) == 404:
		return false

	if not bool(response.get("ok", false)):
		return false

	if str(response.get("body_text", "")).strip_edges() == "":
		return false

	return not user_from_response(response, token).is_empty()


func token_available(response: Dictionary, token: String) -> bool:
	if int(response.get("code", 0)) == 404:
		return true

	if not bool(response.get("ok", false)):
		return false

	if str(response.get("body_text", "")).strip_edges() == "":
		return true

	return user_from_response(response, token).is_empty()


func user_birth_year(data: Dictionary) -> String:
	for key in BIRTH_YEAR_KEYS:
		var value = data.get(key, null)

		if value == null:
			continue

		if typeof(value) == TYPE_INT:
			return str(int(value))

		if typeof(value) == TYPE_FLOAT:
			var year := float(value)
			if is_equal_approx(year, floor(year)):
				return str(int(year))
			continue

		var text := str(value).strip_edges()
		if text != "" and text != "null" and text.is_valid_int():
			return str(int(text))

	return ""


func user_doctor_token(data: Dictionary) -> String:
	return str(data.get("doctor_token", "")).strip_edges()


func contains_any(text: String, words: Array[String]) -> bool:
	var lower_text := text.to_lower()

	for word in words:
		if lower_text.find(word) != -1:
			return true

	return false


func missing_doctor(response: Dictionary, has_doctor_token: bool) -> bool:
	if not has_doctor_token:
		return false

	var code := int(response.get("code", 0))

	if code != 400 and code != 404:
		return false

	var body_text := str(response.get("body_text", ""))
	var missing_terms: Array[String] = ["not found", "does not exist", "n'existe", "introuvable", "invalid", "invalide"]

	if body_text.to_lower().find("doctor_token") != -1 and contains_any(body_text, missing_terms):
		return true

	var data = parse(body_text)
	if typeof(data) == TYPE_DICTIONARY:
		for key in ["doctor_token", "detail", "message", "error"]:
			if not data.has(key):
				continue

			var value_text := str(data[key])
			if key == "doctor_token" or contains_any(value_text, missing_terms):
				return true

	return code == 404
