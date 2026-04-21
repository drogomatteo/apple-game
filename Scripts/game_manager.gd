extends Node

const LOG_TAG := "[GameManager]"
const GAME_API_KEY := "pL6UIb8R486IeTDv7arnpqm7NuJkQbHGesgpBIzClec"
const AUTH_TOKEN_PATH := "auth/token/"
const AUTH_REFRESH_PATH := "auth/refresh/"
const ACCESS_TOKEN_DEFAULT_LIFETIME_SECONDS := 900
const ACCESS_TOKEN_REFRESH_LEEWAY_SECONDS := 60
const REQUEST_TIMEOUT_SECONDS := 5.0

var auth_http := HTTPRequest.new()

func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"

func _ready() -> void:
	add_child(auth_http)
	auth_http.timeout = REQUEST_TIMEOUT_SECONDS

func _is_http_success(result: int, code: int) -> bool:
	return result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300

func get_api_headers() -> PackedStringArray:
	var headers := PackedStringArray()
	var access_token = str(PlayerData.access_token).strip_edges()
	if access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	return headers

func get_bootstrap_headers() -> PackedStringArray:
	return PackedStringArray([
		"X-Game-Api-Key: " + GAME_API_KEY
	])

func get_json_post_headers() -> PackedStringArray:
	var headers = get_api_headers()
	headers.insert(0, "Content-Type: application/json")
	return headers

func get_multipart_post_headers(boundary: String) -> PackedStringArray:
	var headers = get_api_headers()
	headers.insert(0, "Content-Type: multipart/form-data; boundary=" + boundary)
	return headers

func clear_api_tokens(save := true) -> void:
	PlayerData.access_token = ""
	PlayerData.refresh_token = ""
	PlayerData.access_token_expires_at = 0
	if save:
		GestionFichier.save_data()

func _has_usable_access_token() -> bool:
	var access_token = str(PlayerData.access_token).strip_edges()
	if access_token == "":
		return false
	var now = int(Time.get_unix_time_from_system())
	return PlayerData.access_token_expires_at > now + ACCESS_TOKEN_REFRESH_LEEWAY_SECONDS

func _perform_http_request(request: HTTPRequest, url: String, headers: PackedStringArray, method: int, body := "") -> Dictionary:
	var err = request.request(url, headers, method, body)
	if err != OK:
		return {"ok": false, "error": err, "result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body_text": ""}

	var response = await request.request_completed
	var result = int(response[0])
	var code = int(response[1])
	var response_body: PackedByteArray = response[3]
	return {
		"ok": _is_http_success(result, code),
		"error": OK,
		"result": result,
		"code": code,
		"body_text": response_body.get_string_from_utf8()
	}

func _extract_expiry_timestamp(response_data: Dictionary) -> int:
	var candidates = [
		response_data.get("access_token_expires_at", 0),
		response_data.get("expires_at", 0),
		response_data.get("access_expires_at", 0)
	]

	for candidate in candidates:
		if typeof(candidate) == TYPE_INT or typeof(candidate) == TYPE_FLOAT:
			var timestamp = int(candidate)
			if timestamp > 0:
				return timestamp
		var candidate_text = str(candidate).strip_edges()
		if candidate_text.is_valid_int():
			return int(candidate_text)

	var expires_in = response_data.get("expires_in", response_data.get("access_token_expires_in", 0))
	if typeof(expires_in) == TYPE_INT or typeof(expires_in) == TYPE_FLOAT:
		var duration = int(expires_in)
		if duration > 0:
			return int(Time.get_unix_time_from_system()) + duration

	return int(Time.get_unix_time_from_system()) + ACCESS_TOKEN_DEFAULT_LIFETIME_SECONDS

func _store_api_tokens(response_data: Dictionary) -> bool:
	var access_token = str(response_data.get("access_token", "")).strip_edges()
	var refresh_token = str(response_data.get("refresh_token", "")).strip_edges()
	if access_token == "" or refresh_token == "":
		return false

	PlayerData.access_token = access_token
	PlayerData.refresh_token = refresh_token
	PlayerData.access_token_expires_at = _extract_expiry_timestamp(response_data)
	GestionFichier.save_data()
	_log("API tokens updated | expires_at=%s" % str(PlayerData.access_token_expires_at))
	return true

func fetch_api_tokens() -> bool:
	var response = await _perform_http_request(
		auth_http,
		BASE_URL + AUTH_TOKEN_PATH,
		get_bootstrap_headers(),
		HTTPClient.METHOD_POST
	)
	if not response.get("ok", false):
		_log("Bootstrap token request failed | code=%s result=%s body=%s" % [
			str(response.get("code", 0)),
			str(response.get("result", 0)),
			str(response.get("body_text", "")).strip_edges()
		])
		return false

	var parsed = JSON.parse_string(str(response.get("body_text", "")))
	if typeof(parsed) != TYPE_DICTIONARY:
		_log("Bootstrap token response invalid | body=%s" % str(response.get("body_text", "")).strip_edges())
		return false

	return _store_api_tokens(parsed)

func refresh_api_tokens() -> bool:
	var current_refresh_token = str(PlayerData.refresh_token).strip_edges()
	if current_refresh_token == "":
		return false

	var response = await _perform_http_request(
		auth_http,
		BASE_URL + AUTH_REFRESH_PATH,
		PackedStringArray([
			"Content-Type: application/json"
		]),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"refresh_token": current_refresh_token
		})
	)
	if not response.get("ok", false):
		_log("Refresh token request failed | code=%s result=%s body=%s" % [
			str(response.get("code", 0)),
			str(response.get("result", 0)),
			str(response.get("body_text", "")).strip_edges()
		])
		clear_api_tokens(false)
		return false

	var parsed = JSON.parse_string(str(response.get("body_text", "")))
	if typeof(parsed) != TYPE_DICTIONARY:
		_log("Refresh token response invalid | body=%s" % str(response.get("body_text", "")).strip_edges())
		clear_api_tokens(false)
		return false

	return _store_api_tokens(parsed)

func ensure_valid_access_token() -> bool:
	if _has_usable_access_token():
		return true

	if await refresh_api_tokens():
		return true

	return await fetch_api_tokens()

func send_file(filepath, url, session_id := "", extra_fields := {}):
	_log("send_file -> %s" % filepath)
	if PlayerData.user_id == -1:
		_log("No user_id: queue file upload")
		SyncManager.add_action({
			"type": "file",
			"path": filepath,
			"url": url,
			"session_id": session_id,
			"extra_fields": extra_fields
		})
		return

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		_log("ERROR: file open failed -> %s" % filepath)
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()

	var boundary = "----GodotBoundary"
	var body = ""

	body += "--" + boundary + "\r\n"
	body += 'Content-Disposition: form-data; name="user"\r\n\r\n'
	body += str(PlayerData.user_id) + "\r\n"

	if session_id != "":
		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="session_id"\r\n\r\n'
		body += session_id + "\r\n"

	for field_name in extra_fields.keys():
		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="' + str(field_name) + '"\r\n\r\n'
		body += str(extra_fields[field_name]) + "\r\n"

	body += "--" + boundary + "\r\n"
	body += 'Content-Disposition: form-data; name="fichier"; filename="rapport.dat"\r\n'
	body += "Content-Type: application/octet-stream\r\n\r\n"

	var body_bytes = body.to_utf8_buffer()
	var end = ("\r\n--" + boundary + "--\r\n").to_utf8_buffer()
	var final_body = body_bytes + file_bytes + end

	var has_token = await ensure_valid_access_token()
	if not has_token:
		_log("ERROR: no API access token available, queueing upload")
		SyncManager.add_action({
			"type": "file",
			"path": filepath,
			"url": url,
			"session_id": session_id,
			"extra_fields": extra_fields
		})
		return

	var headers = get_multipart_post_headers(boundary)

	var http = HTTPRequest.new()
	add_child(http)

	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, final_body)

	if err != OK:
		_log("ERROR: immediate upload request failed, queueing")
		SyncManager.add_action({
			"type": "file",
			"path": filepath,
			"url": url,
			"session_id": session_id,
			"extra_fields": extra_fields
		})
		return

	http.request_completed.connect(func(result, code, headers, body):
		if _is_http_success(result, code):
			_log("Upload success | code=%s" % str(code))
		if not _is_http_success(result, code):
			_log("Upload failed, queueing retry")
			SyncManager.add_action({
				"type": "file",
				"path": filepath,
				"url": url,
				"session_id": session_id,
				"extra_fields": extra_fields
			})

		http.queue_free()
	)


func send_rapport_complet(session_id := ""):
	send_file("user://rapport_complet.dat", BASE_URL + "rapport_complet/", session_id)


func send_rapport_medecin(session_id := "", seed_value := ""):
	# Au lieu d'envoyer la seed directement, on crée la Seed_Level d'abord
	_log("Queue create_seed action")
	SyncManager.add_action({
		"type": "create_seed",
		"seed_value": seed_value,
		"session_id": session_id
	})
