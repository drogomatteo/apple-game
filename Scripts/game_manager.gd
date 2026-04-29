extends Node

signal access_token_check_completed

const LOG_TAG := "[GameManager]"

# -------- CONFIG --------
const GAME_API_KEY := "pL6UIb8R486IeTDv7arnpqm7NuJkQbHGesgpBIzClec"
const AUTH_TOKEN_PATH := "auth/token/"
const AUTH_REFRESH_PATH := "auth/refresh/"
const ACCESS_TOKEN_DEFAULT_LIFETIME_SECONDS := 900
const ACCESS_TOKEN_REFRESH_LEEWAY_SECONDS := 60
const REQUEST_TIMEOUT_SECONDS := 5.0
const LEVEL_GENERATION_VERSION := "levels-v1"
var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"

# -------- STATE --------
var auth_http := HTTPRequest.new()
var access_token_check_in_progress := false

func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

# -------- LIFECYCLE --------
func _ready() -> void:
	add_child(auth_http)
	auth_http.timeout = REQUEST_TIMEOUT_SECONDS

# -------- HEADER HELPERS --------
func _is_http_success(result: int, code: int) -> bool:
	return result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300

func _is_duplicate_report_response(url: String, code: int, body_text: String) -> bool:
	if code != 400:
		return false
	if url.find("full-report/") == -1 and url.find("doctor-report/") == -1:
		return false
	return body_text.find("must make a unique set") != -1

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

func get_client_metadata() -> Dictionary:
	return {
		"app_version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
		"app_version_code": int(ProjectSettings.get_setting("application/config/version_code", 1)),
		"level_generation_version": LEVEL_GENERATION_VERSION,
		"client_platform": OS.get_name()
	}

# -------- QUEUE HELPERS --------
func _queue_file_upload(filepath, url, session_id := "", extra_fields := {}) -> void:
	SyncManager.add_action({
		"type": "file",
		"path": filepath,
		"url": url,
		"session_id": session_id,
		"extra_fields": extra_fields
	})

# -------- TOKEN HELPERS --------
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

func _parse_token_response(body_text: String, context: String) -> Dictionary:
	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	_log("%s response invalid | body=%s" % [context, body_text.strip_edges()])
	return {}

# -------- TOKEN FLOW --------
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
			var parsed_timestamp = int(candidate_text)
			if parsed_timestamp > 0:
				return parsed_timestamp

	var expires_in = response_data.get("expires_in", response_data.get("access_token_expires_in", 0))
	if typeof(expires_in) == TYPE_INT or typeof(expires_in) == TYPE_FLOAT:
		var duration = int(expires_in)
		if duration > 0:
			return int(Time.get_unix_time_from_system()) + duration
	var expires_in_text = str(expires_in).strip_edges()
	if expires_in_text.is_valid_int():
		var parsed_duration = int(expires_in_text)
		if parsed_duration > 0:
			return int(Time.get_unix_time_from_system()) + parsed_duration

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

	var parsed = _parse_token_response(str(response.get("body_text", "")), "Bootstrap token")
	if parsed.is_empty():
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

	var parsed = _parse_token_response(str(response.get("body_text", "")), "Refresh token")
	if parsed.is_empty():
		clear_api_tokens(false)
		return false

	return _store_api_tokens(parsed)

func ensure_valid_access_token() -> bool:
	if _has_usable_access_token():
		return true

	if access_token_check_in_progress:
		await access_token_check_completed
		return _has_usable_access_token()

	access_token_check_in_progress = true
	var success := false

	if await refresh_api_tokens():
		success = true
	else:
		success = await fetch_api_tokens()

	access_token_check_in_progress = false
	access_token_check_completed.emit()
	return success

# -------- FILE UPLOADS --------
func send_file(filepath, url, session_id := "", extra_fields := {}):
	_log("send_file -> %s" % filepath)
	if PlayerData.user_id < 0:
		_log("No server user_id: queue file upload")
		_queue_file_upload(filepath, url, session_id, extra_fields)
		if not SyncManager.is_running:
			SyncManager.force_sync()
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
	body += 'Content-Disposition: form-data; name="file"; filename="report.dat"\r\n'
	body += "Content-Type: application/octet-stream\r\n\r\n"

	var body_bytes = body.to_utf8_buffer()
	var end = ("\r\n--" + boundary + "--\r\n").to_utf8_buffer()
	var final_body = body_bytes + file_bytes + end

	var has_token = await ensure_valid_access_token()
	if not has_token:
		_log("ERROR: no API access token available, queueing upload")
		_queue_file_upload(filepath, url, session_id, extra_fields)
		return

	var headers = get_multipart_post_headers(boundary)

	var http = HTTPRequest.new()
	add_child(http)

	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, final_body)

	if err != OK:
		_log("ERROR: immediate upload request failed, queueing")
		_queue_file_upload(filepath, url, session_id, extra_fields)
		http.queue_free()
		return

	http.request_completed.connect(func(result, code, _headers, _body):
		if _is_http_success(result, code):
			_log("Upload success | code=%s" % str(code))
		if not _is_http_success(result, code):
			var body_text: String = _body.get_string_from_utf8().strip_edges()
			if _is_duplicate_report_response(url, code, body_text):
				_log("Upload already persisted remotely | url=%s | body=%s" % [url, body_text])
				http.queue_free()
				return
			_log("Upload failed, queueing retry | code=%s | result=%s | url=%s | body=%s" % [
				str(code),
				str(result),
				url,
				body_text
			])
			_queue_file_upload(filepath, url, session_id, extra_fields)

		http.queue_free()
	)

func send_full_report(session_id := ""):
	send_file("user://rapport_complet.dat", BASE_URL + "full-report/", session_id, get_client_metadata())

func send_doctor_report(session_id := "", seed_value := ""):
	_log("Queue create_seed action")
	SyncManager.add_action({
		"type": "create_seed",
		"seed_value": seed_value,
		"session_id": session_id,
		"report_path": "user://doctor_report.dat",
		"report_url": BASE_URL + "doctor-report/",
		"extra_fields": get_client_metadata()
	})
	if not SyncManager.is_running:
		SyncManager.force_sync()
