extends Node

const BASE_URL := "https://alzheimer.magellan.fpms.ac.be/api/"
const REQUEST_TIMEOUT_SECONDS := 5.0


func request(url: String, headers: PackedStringArray, method: int, body := "") -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS

	var error := http.request(url, headers, method, body)

	if error != OK:
		push_warning("API request failed immediately | url=%s | error=%s" % [url, str(error)])
		http.queue_free()
		return failed_request(error)

	var response = await http.request_completed
	http.queue_free()

	var result := int(response[0])
	var code := int(response[1])
	var response_body: PackedByteArray = response[3]
	var body_text := response_body.get_string_from_utf8()
	var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300

	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("API request failed | url=%s | result=%s" % [url, str(result)])
	elif not ok and code != 404:
		push_warning("API response not ok | url=%s | code=%s | body=%s" % [
			url,
			str(code),
			body_text.strip_edges()
		])

	return {
		"ok": ok,
		"auth": true,
		"error": OK,
		"result": result,
		"code": code,
		"body_text": body_text
	}


func failed_request(error: int) -> Dictionary:
	return {
		"ok": false,
		"auth": true,
		"error": error,
		"result": HTTPRequest.RESULT_CANT_CONNECT,
		"code": 0,
		"body_text": ""
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


func empty_token_response() -> Dictionary:
	return {
		"ok": false,
		"auth": true,
		"error": OK,
		"result": HTTPRequest.RESULT_SUCCESS,
		"code": 0,
		"body_text": ""
	}


func get_user(token: String) -> Dictionary:
	token = token.strip_edges()

	if token == "":
		return empty_token_response()

	if not await GameManager.get_valid_token():
		push_warning("API auth unavailable for user lookup.")
		return no_auth()

	return await request(
		BASE_URL + "user/?token=" + token,
		GameManager.get_api_headers(),
		HTTPClient.METHOD_GET
	)


func get_doctor(doctor_token: String) -> Dictionary:
	doctor_token = doctor_token.strip_edges()

	if doctor_token == "":
		return empty_token_response()

	if not await GameManager.get_valid_token():
		push_warning("API auth unavailable for doctor lookup.")
		return no_auth()

	return await request(
		BASE_URL + "doctor/?token=" + doctor_token,
		GameManager.get_api_headers(),
		HTTPClient.METHOD_GET
	)


func create_user(data: Dictionary) -> Dictionary:
	if not await GameManager.get_valid_token():
		push_warning("API auth unavailable for user creation.")
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
		"birth_year": data.get("birth_year", null)
	}

	if data.has("uuid"):
		payload["uuid"] = data.get("uuid")

	var doctor_token := str(data.get("doctor_token", "")).strip_edges()

	if doctor_token != "":
		payload["doctor_token"] = doctor_token

	return payload


func find_by_token(response: Dictionary, token: String) -> Dictionary:
	var data: Variant = JSON.parse_string(str(response.get("body_text", "")))

	if typeof(data) == TYPE_DICTIONARY:
		if str(data.get("token", "")) == token:
			return data

		var results = data.get("results", [])

		if typeof(results) == TYPE_ARRAY:
			for item in results:
				if typeof(item) == TYPE_DICTIONARY and str(item.get("token", "")) == token:
					return item

	elif typeof(data) == TYPE_ARRAY:
		for item in data:
			if typeof(item) == TYPE_DICTIONARY and str(item.get("token", "")) == token:
				return item

	return {}


func token_exists(response: Dictionary, token: String) -> bool:
	if int(response.get("code", 0)) == 404:
		return false

	if not bool(response.get("ok", false)):
		return false

	if str(response.get("body_text", "")).strip_edges() == "":
		return false

	return not find_by_token(response, token).is_empty()


func token_is_available(response: Dictionary, token: String) -> bool:
	if int(response.get("code", 0)) == 404:
		return true

	if not bool(response.get("ok", false)):
		return false

	if str(response.get("body_text", "")).strip_edges() == "":
		return true

	return find_by_token(response, token).is_empty()

func get_birth_year(data: Dictionary) -> String:
	var value = data.get("birth_year", null)

	if value == null:
		push_warning("User response has no birth_year.")
		return ""

	if typeof(value) == TYPE_INT:
		return str(int(value))

	if typeof(value) == TYPE_FLOAT:
		var year := float(value)

		if is_equal_approx(year, floor(year)):
			return str(int(year))

		push_warning("Invalid float birth_year in user response: %s" % str(value))
		return ""

	var text := str(value).strip_edges()

	if text != "" and text != "null" and text.is_valid_int():
		return str(int(text))

	push_warning("Invalid birth_year in user response: %s" % text)
	return ""
