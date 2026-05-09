extends Node

const BASE_URL := "https://alzheimer.magellan.fpms.ac.be/api/"
const DOCTOR_LOOKUP_PATH := "doctor/?token="
const QUEUE_PATH := "user://offline_queue.json"

const REQUEST_TIMEOUT_SECONDS := 5.0
const MAX_RETRIES := 10
const MAX_RETRY_DELAY := 5.0

const TOKEN_LENGTH := 8
const MAX_TOKEN_CONFLICT_REGEN_ATTEMPTS := 20
const TOKEN_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

const MULTIPART_BOUNDARY := "----GodotBoundary"

var queue: Array = []
var http := HTTPRequest.new()

var is_running := false
var sync_done := false

var retry_delay := 0.5

var login_check_running := false
var login_check_mode := ""


func _ready() -> void:
	randomize()

	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS
	http.request_completed.connect(_on_request_completed)

	load_queue()


func add_action(action: Dictionary) :
	action["retries"] = action.get("retries", 0)
	queue.append(action)
	save_queue()


func force_sync() -> void:
	if queue.is_empty():
		sync_done = true
		return

	sync_done = false
	process_next()


func save_queue() -> void:
	var file := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)

	if file == null:
		push_error(" Could not save offline queue.")
		return

	file.store_string(JSON.stringify(queue))


func load_queue() -> void:
	if not FileAccess.file_exists(QUEUE_PATH):
		queue = []
		return

	var file := FileAccess.open(QUEUE_PATH, FileAccess.READ)

	if file == null:
		push_error("Could not load offline queue.")
		queue = []
		return

	var data: Variant = JSON.parse_string(file.get_as_text())

	if typeof(data) == TYPE_ARRAY:
		queue = data
	else:
		push_warning("Invalid queue file. Queue reset.")
		queue = []


func process_next() -> void:
	if queue.is_empty():
		finish_sync()
		return

	if is_running:
		return

	is_running = true

	var action: Dictionary = queue[0]

	fix_session_id(action)

	if migrate_old_doctor_report(action):
		is_running = false
		process_next()
		return

	match str(action.get("type", "")):
		"login":
			await sync_login(action)

		"create_seed":
			await sync_seed(action)

		"report":
			await sync_report(action)

		"file":
			await sync_file(action)

		_:
			push_error("Unknown action type: %s" % str(action.get("type", "")))
			drop_action(action)
			is_running = false
			process_next()


func finish_sync() -> void:
	sync_done = true
	is_running = false


func request_failed() -> void:
	is_running = false

	if queue.is_empty():
		finish_sync()
		return

	await retry_action(
		queue[0],
		"Immediate request error | type=%s | retries=%s",
		"Dropping action after max retries | type=%s"
	)


func sync_login(action: Dictionary) :
	var data: Dictionary = action.get("data", {})

	if bool(data.get("token_generated_offline", false)):
		var token := str(data.get("token", "")).strip_edges()

		if token != "":
			var has_token := await GameManager.ensure_valid_access_token()

			if not has_token:
				push_warning("Token precheck auth unavailable.")
				request_failed()
				return

			start_login_check(BASE_URL + "user/?token=" + token, "token")
			return

		data["token_generated_offline"] = false
		action["data"] = data
		save_queue()

	var doctor_token := get_doctor_token(data)

	if doctor_token != "" and not bool(data.get("doctor_token_prechecked", false)):
		var has_token := await GameManager.ensure_valid_access_token()

		if not has_token:
			push_warning("Doctor token precheck auth unavailable.")
			request_failed()
			return

		start_login_check(BASE_URL + DOCTOR_LOOKUP_PATH + doctor_token, "doctor_token")
		return

	var payload := data.duplicate(true)
	erase_keys(payload, ["token_generated_offline", "doctor_token_prechecked"])

	var has_login_token := await GameManager.ensure_valid_access_token()

	if not has_login_token:
		push_warning("Login sync auth unavailable.")
		request_failed()
		return

	var error := http.request(
		BASE_URL + "user/",
		GameManager.get_json_post_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(build_user_payload(payload))
	)

	if error != OK:
		push_warning("Login request failed immediately.")
		request_failed()

func clear_login_check() -> String:
	var mode := login_check_mode

	login_check_running = false
	login_check_mode = ""

	return mode

func start_login_check(url: String, mode: String) :
	login_check_running = true
	login_check_mode = mode

	var error := http.request(
		url,
		GameManager.get_api_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		clear_login_check()
		request_failed()


func handle_login_check(action: Dictionary, code: int, result: int, body_text: String) :
	var mode := clear_login_check()

	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Login precheck network failed.")
		await retry_action(action, "", "")
		return

	if code != 404 and not is_success_code(code):
		push_warning("Login precheck failed with code: %s" % str(code))
		await retry_action(action, "", "")
		return

	var data: Dictionary = action.get("data", {})

	if mode == "doctor_token":
		handle_doctor_check(action, data, code, body_text)
		return

	handle_token_check(action, data, code, body_text)


func handle_doctor_check(action: Dictionary, data: Dictionary, code: int, body_text: String) -> void:
	var doctor_token := get_doctor_token(data)
	var found := lookup_token_found(code, body_text, doctor_token)

	data["doctor_token_prechecked"] = true

	if doctor_token != "" and not found:
		data.erase("doctor_token")
		data.erase("doctor_id")
		action["data"] = data
		save_queue()

		if PlayerData.user_id != -1 and str(PlayerData.doctor_token).strip_edges() == doctor_token:
			PlayerData.doctor_token = ""
			save_player_data()

		push_warning("Doctor token not found. Login will continue without doctor token.")
		process_next()
		return

	var doctor_id := extract_lookup_id(code, body_text, doctor_token)

	if doctor_id >= 0:
		data["doctor_id"] = doctor_id

	action["data"] = data
	save_queue()
	process_next()


func handle_token_check(action: Dictionary, data: Dictionary, code: int, body_text: String) -> void:
	var current_token := str(data.get("token", "")).strip_edges()
	var available := token_available(code, body_text, current_token)

	if available:
		data["token_generated_offline"] = false
		action["data"] = data
		action["token_conflict_regen_attempts"] = 0
		save_queue()
		process_next()
		return

	var attempts := int(action.get("token_conflict_regen_attempts", 0)) + 1
	action["token_conflict_regen_attempts"] = attempts

	if attempts > MAX_TOKEN_CONFLICT_REGEN_ATTEMPTS:
		action["token_conflict_regen_attempts"] = 0
		await retry_action(action, "", "")
		return

	var old_token := current_token
	var new_token := generate_token()

	data["token"] = new_token
	data["token_generated_offline"] = true
	action["data"] = data

	save_queue()

	if PlayerData.token == old_token:
		PlayerData.token = new_token
		PlayerData.token_update_pending = true
		PlayerData.previous_token = old_token
		PlayerData.updated_token = new_token
		save_player_data()

	process_next()


func save_synced_user(action: Dictionary, body_text: String) -> void:
	var response: Variant = JSON.parse_string(body_text)

	if typeof(response) != TYPE_DICTIONARY:
		return

	if not response.has("id"):
		return

	var data: Dictionary = action.get("data", {})

	var user_id := int(response["id"])
	var token := str(data.get("token", PlayerData.token))
	var uuid := str(response.get("uuid", data.get("uuid", PlayerData.uuid)))
	var birth_year := str(data.get("birth_year", ""))
	var doctor_token := get_doctor_token(data)

	PlayerData.set_user(user_id, uuid, token, birth_year, doctor_token)
	PlayerData.birth_year = birth_year if birth_year.is_valid_int() else ""

	for queued_action in queue:
		if queued_action.get("type", "") == "report":
			queued_action["data"]["user_id"] = PlayerData.user_id
			queued_action["data"]["birth_year"] = PlayerData.birth_year

	save_queue()
	save_player_data()


# ======================
# REPORT
# ======================

func sync_report(action: Dictionary) -> void:
	var has_token := await GameManager.ensure_valid_access_token()

	if not has_token:
		push_warning("Report sync auth unavailable.")
		request_failed()
		return

	var error := http.request(
		BASE_URL + "full-report/",
		GameManager.get_json_post_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(action["data"])
	)

	if error != OK:
		push_warning("Report request failed immediately.")
		request_failed()


# ======================
# SEED
# ======================

func sync_seed(action: Dictionary) -> void:
	var seed_value := str(action.get("seed_value", ""))
	var payload := build_seed_body(seed_value)

	if not bool(payload.get("ok", false)):
		request_failed()
		return

	var has_token := await GameManager.ensure_valid_access_token()

	if not has_token:
		push_warning("Seed upload auth unavailable.")
		request_failed()
		return

	var error := http.request_raw(
		BASE_URL + "seed/",
		GameManager.get_multipart_post_headers(str(payload.get("boundary", ""))),
		HTTPClient.METHOD_POST,
		payload.get("body", PackedByteArray())
	)

	if error != OK:
		push_warning("Seed upload request failed immediately.")
		request_failed()


func build_seed_body(seed_value: String) -> Dictionary:
	var temp_path := "user://temp_seed_%s.dat" % seed_value

	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)

	if temp_file == null:
		return {"ok": false}

	temp_file.store_string(seed_value)

	var seed_file := FileAccess.open(temp_path, FileAccess.READ)

	if seed_file == null:
		remove_temp_seed(seed_value)
		return {"ok": false}

	var file_bytes := seed_file.get_buffer(seed_file.get_length())

	var body := multipart_field("name", seed_value)
	body += "--" + MULTIPART_BOUNDARY + "\r\n"
	body += 'Content-Disposition: form-data; name="file"; filename="seed.dat"\r\n'
	body += "Content-Type: application/octet-stream\r\n\r\n"

	return {
		"ok": true,
		"boundary": MULTIPART_BOUNDARY,
		"body": body.to_utf8_buffer() + file_bytes + multipart_end()
	}


func handle_seed_success(action: Dictionary, body_text: String) -> void:
	remove_temp_seed(str(action.get("seed_value", "")))

	var response: Variant = JSON.parse_string(body_text)

	if typeof(response) != TYPE_DICTIONARY or not response.has("id"):
		push_error("Invalid seed creation response.")
		remove_snapshot(action, "report_path", "report_snapshot_file")
		return

	var extra_fields = action.get("extra_fields", {})

	if typeof(extra_fields) != TYPE_DICTIONARY:
		extra_fields = {}
	else:
		extra_fields = extra_fields.duplicate(true)

	extra_fields["seed"] = int(response["id"])

	queue.insert(0, {
		"type": "file",
		"path": str(action.get("report_path", "user://doctor_report.dat")),
		"url": str(action.get("report_url", BASE_URL + "doctor-report/")),
		"session_id": str(action.get("session_id", "")),
		"retries": 0,
		"extra_fields": extra_fields,
		"snapshot_file": bool(action.get("report_snapshot_file", false))
	})

	save_queue()


# ======================
# FILE
# ======================

func sync_file(action: Dictionary) -> void:
	if PlayerData.user_id < 0:
		if has_pending_login():
			move_action_to_end("File upload deferred until login sync provides a valid user_id.")
			is_running = false
			process_next()
			return

		push_warning("File upload has no valid user_id yet.")
		await retry_action(
			action,
			"File upload waiting for valid user_id | type=%s | retries=%s",
			"Dropping action after max retries | type=%s"
		)
		return

	var filepath := str(action.get("path", ""))

	if filepath == "" or not FileAccess.file_exists(filepath):
		push_error("File action dropped. Missing file: %s" % filepath)
		drop_action(action)
		process_next()
		return

	var payload := build_file_body(
		filepath,
		str(action.get("session_id", "")),
		action.get("extra_fields", {})
	)

	if not bool(payload.get("ok", false)):
		push_error("Could not read file: %s" % filepath)
		drop_action(action)
		process_next()
		return

	var has_token := await GameManager.ensure_valid_access_token()

	if not has_token:
		push_warning("File upload auth unavailable.")
		request_failed()
		return

	var error := http.request_raw(
		str(action.get("url", "")),
		GameManager.get_multipart_post_headers(str(payload.get("boundary", ""))),
		HTTPClient.METHOD_POST,
		payload.get("body", PackedByteArray())
	)

	if error != OK:
		push_warning("File upload request failed immediately.")
		request_failed()


func build_file_body(filepath: String, session_id := "", extra_fields := {}) -> Dictionary:
	var file := FileAccess.open(filepath, FileAccess.READ)

	if file == null:
		return {"ok": false}

	var file_bytes := file.get_buffer(file.get_length())

	var body := multipart_field("user", PlayerData.user_id)

	if session_id != "":
		body += multipart_field("session_id", session_id)

	for field_name in extra_fields.keys():
		body += multipart_field(str(field_name), extra_fields[field_name])

	body += "--" + MULTIPART_BOUNDARY + "\r\n"
	body += 'Content-Disposition: form-data; name="file"; filename="report.dat"\r\n'
	body += "Content-Type: application/octet-stream\r\n\r\n"

	return {
		"ok": true,
		"boundary": MULTIPART_BOUNDARY,
		"body": body.to_utf8_buffer() + file_bytes + multipart_end()
	}


# ======================
# REQUEST COMPLETED
# ======================

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_running = false

	if queue.is_empty():
		return

	var action: Dictionary = queue[0]
	var action_type := str(action.get("type", "unknown"))
	var body_text := body.get_string_from_utf8().strip_edges()

	if action_type == "login" and login_check_running:
		await handle_login_check(action, code, result, body_text)
		return

	if request_has_failed(result, code):
		await handle_failed_response(action, action_type, code, result, body_text)
		return

	retry_delay = 0.5
	queue.pop_front()
	save_queue()

	if action_type == "login":
		save_synced_user(action, body_text)

	elif action_type == "create_seed":
		handle_seed_success(action, body_text)

	elif action_type == "file":
		remove_snapshot(action)

	process_next()


func handle_failed_response(action: Dictionary, action_type: String, code: int, result: int, body_text: String) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and action_type == "login":
		if doctor_not_found(code, body_text, action):
			var data: Dictionary = action.get("data", {})
			data.erase("doctor_token")
			action["data"] = data

			if PlayerData.user_id != -1:
				PlayerData.doctor_token = ""
				save_player_data()

			save_queue()
			push_warning("Doctor token not found. Retrying login without doctor token.")
			process_next()
			return

	if result == HTTPRequest.RESULT_SUCCESS and duplicate_report(action, code, body_text):
		queue.pop_front()
		save_queue()
		retry_delay = 0.5
		process_next()
		return

	push_warning("Request failed | type=%s | code=%s | result=%s | body=%s" % [
		action_type,
		str(code),
		str(result),
		body_text
	])

	await retry_action(
		action,
		"",
		"Dropping action after max retries | type=%s"
	)


func request_has_failed(result: int, code: int) -> bool:
	return result != HTTPRequest.RESULT_SUCCESS or (code != 200 and code != 201)


func retry_action(action: Dictionary, retry_message: String, drop_message: String) -> void:
	action["retries"] = int(action.get("retries", 0)) + 1

	if retry_message != "":
		push_warning("" + retry_message % [
			str(action.get("type", "unknown")),
			str(action["retries"])
		])

	if action["retries"] > MAX_RETRIES:
		if drop_message != "":
			push_error("" + drop_message % str(action.get("type", "unknown")))

		drop_action(action)
		process_next()
		return

	save_queue()

	await get_tree().create_timer(retry_delay).timeout

	retry_delay = min(retry_delay * 2.0, MAX_RETRY_DELAY)
	process_next()


func drop_action(action: Dictionary) -> void:
	if action.get("type", "") == "create_seed":
		remove_temp_seed(str(action.get("seed_value", "")))
		remove_snapshot(action, "report_path", "report_snapshot_file")

	elif action.get("type", "") == "file":
		remove_snapshot(action)

	queue.pop_front()
	save_queue()
	retry_delay = 0.5


func move_action_to_end(message: String) -> void:
	if queue.is_empty():
		return

	var action: Dictionary = queue.pop_front()
	queue.append(action)

	save_queue()
	retry_delay = 0.5

	if message != "":
		push_warning("" + message)


# ======================
# HELPERS
# ======================

func build_user_payload(data: Dictionary) -> Dictionary:
	var payload := {
		"token": data.get("token", ""),
		"birth_year": data.get("birth_year", null),
		"user_birth_year": data.get("birth_year", null),
		"patient_birth_year": data.get("birth_year", null)
	}

	if data.has("uuid"):
		payload["uuid"] = data.get("uuid")

	var doctor_token := get_doctor_token(data)

	if doctor_token != "":
		payload["doctor_token"] = doctor_token

	var doctor_id := int(data.get("doctor_id", -1))
	if doctor_id >= 0:
		payload["doctor_id"] = doctor_id

	return payload


func get_doctor_token(data: Dictionary) -> String:
	return str(data.get("doctor_token", "")).strip_edges()


func erase_keys(data: Dictionary, keys: Array) -> void:
	for key in keys:
		data.erase(key)


func is_success_code(code: int) -> bool:
	return code >= 200 and code < 300


func generate_token() -> String:
	var token := ""

	for _i in range(TOKEN_LENGTH):
		token += TOKEN_CHARS[randi() % TOKEN_CHARS.length()]

	return token


func find_token_entry(data: Variant, token: String) -> Dictionary:
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


func token_available(code: int, body_text: String, token: String) -> bool:
	if code == 404:
		return true

	if not is_success_code(code):
		return false

	if body_text.strip_edges() == "":
		return true

	var data: Variant = JSON.parse_string(body_text)

	return find_token_entry(data, token).is_empty()


func lookup_token_found(code: int, body_text: String, token: String) -> bool:
	if code == 404:
		return false

	if not is_success_code(code):
		return false

	if body_text.strip_edges() == "":
		return false

	var data: Variant = JSON.parse_string(body_text)

	return not find_token_entry(data, token).is_empty()


func extract_lookup_id(code: int, body_text: String, token: String) -> int:
	if code == 404 or not is_success_code(code) or body_text.strip_edges() == "":
		return -1

	var data: Variant = JSON.parse_string(body_text)
	var entry := find_token_entry(data, token)

	if entry.has("id"):
		return int(entry["id"])

	if typeof(data) == TYPE_DICTIONARY and data.has("id") and not data.has("token"):
		return int(data["id"])

	return -1


func duplicate_report(action: Dictionary, code: int, body_text: String) -> bool:
	if code != 400:
		return false

	if str(action.get("type", "")) != "file":
		return false

	var url := str(action.get("url", ""))

	if url.find("full-report/") == -1 and url.find("doctor-report/") == -1:
		return false

	return body_text.find("must make a unique set") != -1


func doctor_not_found(code: int, body_text: String, action: Dictionary) -> bool:
	if code != 400 and code != 404:
		return false

	var data = action.get("data", {})

	if typeof(data) != TYPE_DICTIONARY or get_doctor_token(data) == "":
		return false

	if code == 404:
		return true

	var parsed: Variant = JSON.parse_string(body_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return body_text.find("doctor_token") != -1 and is_missing_text(body_text)

	if not parsed.has("doctor_token"):
		return false

	return is_missing_text(str(parsed["doctor_token"]))


func is_missing_text(text: String) -> bool:
	var lower_text := text.to_lower()
	return (
		lower_text.find("not found") != -1
		or lower_text.find("does not exist") != -1
		or lower_text.find("n'existe") != -1
		or lower_text.find("introuvable") != -1
		or lower_text.find("invalid") != -1
		or lower_text.find("invalide") != -1
	)


func has_pending_login() -> bool:
	for action in queue:
		if str(action.get("type", "")) == "login":
			return true

	return false


func fix_session_id(action: Dictionary) -> void:
	var session_id := str(action.get("session_id", ""))

	if session_id.find("_-2_") == -1:
		return

	var token := str(PlayerData.token).strip_edges()

	if token == "":
		return

	action["session_id"] = session_id.replace("_-2_", "_" + token + "_")
	save_queue()


func migrate_old_doctor_report(action: Dictionary) -> bool:
	if str(action.get("type", "")) != "file":
		return false

	var url := str(action.get("url", ""))

	if url.find("doctor-report/") == -1:
		return false

	var extra_fields = action.get("extra_fields", {})

	if typeof(extra_fields) != TYPE_DICTIONARY:
		return false

	var seed_value := str(extra_fields.get("seed", "")).strip_edges()

	if seed_value == "" or not seed_value.is_valid_int():
		return false

	queue.pop_front()

	queue.insert(0, {
		"type": "create_seed",
		"seed_value": seed_value,
		"session_id": str(action.get("session_id", "")),
		"report_path": str(action.get("path", "user://doctor_report.dat")),
		"report_url": url,
		"extra_fields": extra_fields,
		"retries": int(action.get("retries", 0))
	})

	save_queue()

	return true


func save_player_data() -> void:
	FileManager.save_game()


func remove_temp_seed(seed_value: String) -> void:
	if seed_value == "":
		return

	var path := "user://temp_seed_%s.dat" % seed_value

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func remove_snapshot(action: Dictionary, path_key := "path", flag_key := "snapshot_file") -> void:
	if not bool(action.get(flag_key, false)):
		return

	var path := str(action.get(path_key, ""))

	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func multipart_field(name: String, value) -> String:
	return "--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [
		MULTIPART_BOUNDARY,
		name,
		str(value)
	]


func multipart_end() -> PackedByteArray:
	return ("\r\n--" + MULTIPART_BOUNDARY + "--\r\n").to_utf8_buffer()
