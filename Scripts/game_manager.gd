extends Node

signal access_token_check_completed

const BASE_URL := "https://alzheimer.magellan.fpms.ac.be/api/"
const GAME_API_KEY := "pL6UIb8R486IeTDv7arnpqm7NuJkQbHGesgpBIzClec"

const AUTH_TOKEN_PATH := "auth/token/"
const AUTH_REFRESH_PATH := "auth/refresh/"

const ACCESS_TOKEN_DEFAULT_LIFETIME_SECONDS := 900
const ACCESS_TOKEN_REFRESH_LEEWAY_SECONDS := 60
const REQUEST_TIMEOUT_SECONDS := 5.0

const LEVEL_GENERATION_VERSION := "levels-v1"
const QUEUED_UPLOAD_DIR := "user://offline_uploads"
const MULTIPART_BOUNDARY := "----GodotBoundary"

var auth_http := HTTPRequest.new()
var access_token_check_in_progress := false


func _ready() :
	add_child(auth_http)
	auth_http.timeout = REQUEST_TIMEOUT_SECONDS


func save_player_data() :
	var root := get_tree().root

	if root.has_node("FileManager"):
		root.get_node("FileManager").save_game()
	else:
		push_warning("No save manager found.")


func get_api_headers() -> PackedStringArray:
	var headers := PackedStringArray()
	var access_token := str(PlayerData.access_token).strip_edges()

	if access_token != "":
		headers.append("Authorization: Bearer " + access_token)

	return headers


func get_bootstrap_headers() -> PackedStringArray:
	return PackedStringArray([
		"X-Game-Api-Key: " + GAME_API_KEY
	])


func get_json_post_headers() -> PackedStringArray:
	var headers := get_api_headers()
	headers.insert(0, "Content-Type: application/json")
	return headers


func get_multipart_post_headers(boundary: String) -> PackedStringArray:
	var headers := get_api_headers()
	headers.insert(0, "Content-Type: multipart/form-data; boundary=" + boundary)
	return headers


func get_client_metadata() -> Dictionary:
	return {
		"app_version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
		"app_version_code": int(ProjectSettings.get_setting("application/config/version_code", 1)),
		"level_generation_version": LEVEL_GENERATION_VERSION,
		"client_platform": OS.get_name()
	}


func http_success(result: int, code: int) -> bool:
	return result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300


func request_json(request: HTTPRequest, url: String, headers: PackedStringArray, method: int, body := "") -> Dictionary:
	var error := request.request(url, headers, method, body)

	if error != OK:
		return {
			"ok": false,
			"error": error,
			"result": HTTPRequest.RESULT_CANT_CONNECT,
			"code": 0,
			"body_text": ""
		}

	var response = await request.request_completed

	var result := int(response[0])
	var code := int(response[1])
	var response_body: PackedByteArray = response[3]
	var body_text := response_body.get_string_from_utf8()

	return {"ok": http_success(result, code), "error": OK, "result": result, "code": code, "body_text": body_text
	}


func parse_json(body_text: String, context: String) -> Dictionary:
	var data: Variant = JSON.parse_string(body_text)

	if typeof(data) == TYPE_DICTIONARY:
		return data

	push_warning("%s response invalid | body=%s" % [context, body_text.strip_edges()])
	return {}


func duplicate_report_response(url: String, code: int, body_text: String) -> bool:
	if code != 400:
		return false

	if url.find("full-report/") == -1:
		return false

	return body_text.find("must make a unique set") != -1


func clear_api_tokens(save := true) -> void:
	PlayerData.access_token = ""
	PlayerData.refresh_token = ""
	PlayerData.access_token_expires_at = 0

	if save:
		save_player_data()


func valid_access_token() -> bool:
	var access_token := str(PlayerData.access_token).strip_edges()

	if access_token == "":
		return false

	var now := int(Time.get_unix_time_from_system())

	return PlayerData.access_token_expires_at > now + ACCESS_TOKEN_REFRESH_LEEWAY_SECONDS


func get_token_expiry(data: Dictionary) -> int:
	var candidates := [
		data.get("access_token_expires_at", 0),
		data.get("expires_at", 0),
		data.get("access_expires_at", 0)
	]

	for candidate in candidates:
		if typeof(candidate) == TYPE_INT or typeof(candidate) == TYPE_FLOAT:
			var timestamp := int(candidate)

			if timestamp > 0:
				return timestamp

		var candidate_text := str(candidate).strip_edges()

		if candidate_text.is_valid_int():
			var parsed_timestamp := int(candidate_text)

			if parsed_timestamp > 0:
				return parsed_timestamp

	var expires_in = data.get("expires_in", data.get("access_token_expires_in", 0))

	if typeof(expires_in) == TYPE_INT or typeof(expires_in) == TYPE_FLOAT:
		var duration := int(expires_in)

		if duration > 0:
			return int(Time.get_unix_time_from_system()) + duration

	var expires_in_text := str(expires_in).strip_edges()

	if expires_in_text.is_valid_int():
		var parsed_duration := int(expires_in_text)

		if parsed_duration > 0:
			return int(Time.get_unix_time_from_system()) + parsed_duration

	return int(Time.get_unix_time_from_system()) + ACCESS_TOKEN_DEFAULT_LIFETIME_SECONDS


func save_api_tokens(data: Dictionary) -> bool:
	var access_token := str(data.get("access_token", "")).strip_edges()
	var refresh_token := str(data.get("refresh_token", "")).strip_edges()

	if access_token == "" or refresh_token == "":
		return false

	PlayerData.access_token = access_token
	PlayerData.refresh_token = refresh_token
	PlayerData.access_token_expires_at = get_token_expiry(data)

	save_player_data()
	return true


func fetch_api_tokens() -> bool:
	var response := await request_json(
		auth_http,
		BASE_URL + AUTH_TOKEN_PATH,
		get_bootstrap_headers(),
		HTTPClient.METHOD_POST
	)

	if not bool(response.get("ok", false)):
		push_warning("Bootstrap token request failed | code=%s result=%s body=%s" % [
			str(response.get("code", 0)),
			str(response.get("result", 0)),
			str(response.get("body_text", "")).strip_edges()
		])
		return false

	var data := parse_json(str(response.get("body_text", "")), "Bootstrap token")

	if data.is_empty():
		return false

	return save_api_tokens(data)


func refresh_api_tokens() -> bool:
	var refresh_token := str(PlayerData.refresh_token).strip_edges()

	if refresh_token == "":
		return false

	var response := await request_json(
		auth_http,
		BASE_URL + AUTH_REFRESH_PATH,
		PackedStringArray([
			"Content-Type: application/json"
		]),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"refresh_token": refresh_token
		})
	)

	if not bool(response.get("ok", false)):
		push_warning("Refresh token request failed | code=%s result=%s body=%s" % [
			str(response.get("code", 0)),
			str(response.get("result", 0)),
			str(response.get("body_text", "")).strip_edges()
		])
		clear_api_tokens(false)
		return false

	var data := parse_json(str(response.get("body_text", "")), "Refresh token")

	if data.is_empty():
		clear_api_tokens(false)
		return false

	return save_api_tokens(data)


func get_valid_token() -> bool:
	if valid_access_token():
		return true

	if access_token_check_in_progress:
		await access_token_check_completed
		return valid_access_token()

	access_token_check_in_progress = true

	var success := false

	if await refresh_api_tokens():
		success = true
	else:
		success = await fetch_api_tokens()

	access_token_check_in_progress = false
	access_token_check_completed.emit()

	return success


func prepare_upload_dir() :
	if not DirAccess.dir_exists_absolute(QUEUED_UPLOAD_DIR):
		DirAccess.make_dir_recursive_absolute(QUEUED_UPLOAD_DIR)


func get_file_extension(filepath: String) -> String:
	var filename := filepath.get_file()
	var dot_index := filename.rfind(".")

	if dot_index == -1:
		return ""

	return filename.substr(dot_index)


func create_upload_copy(filepath: String) -> Dictionary:
	if filepath == "" or not FileAccess.file_exists(filepath):
		return {
			"path": filepath,
			"is_copy": false
		}

	var source := FileAccess.open(filepath, FileAccess.READ)

	if source == null:
		return {
			"path": filepath,
			"is_copy": false
		}

	prepare_upload_dir()

	var extension := get_file_extension(filepath)

	var copy_path := "%s/%s_%s_%s%s" % [
		QUEUED_UPLOAD_DIR,
		filepath.get_file().replace(".", "_"),
		str(Time.get_unix_time_from_system()),
		str(randi()),
		extension
	]

	var target := FileAccess.open(copy_path, FileAccess.WRITE)

	if target == null:
		source.close()

		return {
			"path": filepath,
			"is_copy": false
		}

	target.store_buffer(source.get_buffer(source.get_length()))

	source.close()
	target.close()

	return {
		"path": copy_path,
		"is_copy": true
	}


func delete_upload_copy(copy: Dictionary) -> void:
	if not bool(copy.get("is_copy", false)):
		return

	var filepath := str(copy.get("path", ""))

	if filepath != "" and FileAccess.file_exists(filepath):
		DirAccess.remove_absolute(filepath)




func queue_file_upload(
	filepath: String,
	url: String,
	session_id := "",
	extra_fields := {}
) -> void:
	var copy := create_upload_copy(filepath)

	SyncManager.add_action({
		"type": "file",
		"path": str(copy["path"]),
		"url": url,
		"session_id": session_id,
		"extra_fields": extra_fields,
		"snapshot_file": bool(copy["is_copy"])
	})


func multipart_field(field_name: String, value) -> String:
	return "--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [
		MULTIPART_BOUNDARY,
		field_name,
		str(value)
	]


func build_file_body( filepath: String, session_id := "", extra_fields := {} ) -> Dictionary:
	var file := FileAccess.open(filepath, FileAccess.READ)

	if file == null:
		return {
			"ok": false
		}

	var file_bytes := file.get_buffer(file.get_length())
	file.close()

	var body := ""

	body += multipart_field("user", PlayerData.user_id)

	if session_id != "":
		body += multipart_field("session_id", session_id)

	for field_name in extra_fields.keys():
		var normalized_field_name := "seed_levels" if str(field_name) == "seed" else str(field_name)
		var value = extra_fields[field_name]

		if typeof(value) == TYPE_ARRAY:
			for item in value:
				body += multipart_field(normalized_field_name, item)
		else:
			body += multipart_field(normalized_field_name, value)

	body += "--" + MULTIPART_BOUNDARY + "\r\n"
	body += 'Content-Disposition: form-data; name="file"; filename="report.dat"\r\n'
	body += "Content-Type: application/octet-stream\r\n\r\n"

	var end := ("\r\n--" + MULTIPART_BOUNDARY + "--\r\n").to_utf8_buffer()

	return {
		"ok": true,
		"boundary": MULTIPART_BOUNDARY,
		"body": body.to_utf8_buffer() + file_bytes + end
	}


func send_file(filepath: String, url: String, session_id := "", extra_fields := {}) -> void:
	if PlayerData.user_id < 0:
		queue_file_upload(filepath, url, session_id, extra_fields)

		if not SyncManager.is_running:
			SyncManager.force_sync()

		return

	var backup_copy := create_upload_copy(filepath)
	var payload := build_file_body(filepath, session_id, extra_fields)

	if not bool(payload.get("ok", false)):
		push_error("File open failed -> %s" % filepath)
		delete_upload_copy(backup_copy)
		return

	if not await get_valid_token():
		push_warning("No API access token available, queueing upload")

		SyncManager.add_action({
			"type": "file",
			"path": str(backup_copy["path"]),
			"url": url,
			"session_id": session_id,
			"extra_fields": extra_fields,
			"snapshot_file": bool(backup_copy["is_copy"])
		})

		return

	var http := HTTPRequest.new()
	add_child(http)

	var error := http.request_raw(
		url,
		get_multipart_post_headers(str(payload["boundary"])),
		HTTPClient.METHOD_POST,
		payload["body"]
	)

	if error != OK:
		push_warning("Immediate upload request failed, queueing")

		SyncManager.add_action({
			"type": "file",
			"path": str(backup_copy["path"]),
			"url": url,
			"session_id": session_id,
			"extra_fields": extra_fields,
			"snapshot_file": bool(backup_copy["is_copy"])
		})

		http.queue_free()
		return

	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			if http_success(result, code):
				delete_upload_copy(backup_copy)
				http.queue_free()
				return

			var body_text := body.get_string_from_utf8().strip_edges()

			if duplicate_report_response(url, code, body_text):
				delete_upload_copy(backup_copy)
				http.queue_free()
				return

			push_warning("Upload failed, queueing retry | code=%s | result=%s | url=%s | body=%s" % [
				str(code),
				str(result),
				url,
				body_text
			])

			SyncManager.add_action({
				"type": "file",
				"path": str(backup_copy["path"]),
				"url": url,
				"session_id": session_id,
				"extra_fields": extra_fields,
				"snapshot_file": bool(backup_copy["is_copy"])
			})

			http.queue_free()
	)


func queue_full_report(session_id := "", seed_value := "", report_path := "user://rapport_complet.dat") -> void:
	if seed_value == "":
		queue_file_upload(
			report_path,
			BASE_URL + "full-report/",
			session_id,
			get_client_metadata()
		)
		return

	var copy := create_upload_copy(report_path)

	SyncManager.add_action({
		"type": "create_seed",
		"seed_value": seed_value,
		"session_id": session_id,
		"report_path": str(copy["path"]),
		"extra_fields": get_client_metadata(),
		"report_snapshot_file": bool(copy["is_copy"])
	})


func send_full_report(session_id := "", seed_value := "", report_path := "user://rapport_complet.dat") -> void:
	if seed_value == "":
		send_file(
			report_path,
			BASE_URL + "full-report/",
			session_id,
			get_client_metadata()
		)
		return

	queue_full_report(session_id, seed_value, report_path)

	if not SyncManager.is_running:
		SyncManager.force_sync()
