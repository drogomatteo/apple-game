extends Node

const LOG_TAG := "[SyncManager]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

# -------- CONFIG --------
var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"
const DOCTOR_LOOKUP_PATH := "doctor/?token="
var queue_file_path = "user://offline_queue.json"
const REQUEST_TIMEOUT_SECONDS := 5.0
const MAX_RETRIES := 10
const TOKEN_LENGTH := 8
const MAX_TOKEN_CONFLICT_REGEN_ATTEMPTS := 20

# -------- STATE --------
var queue : Array = []
var http := HTTPRequest.new()
var is_running = false
var sync_done = false
var retry_delay = 0.5
var max_retry_delay = 5.0

# -------- DIAGNOSTICS --------
var sync_start_time = 0
var request_start_time = 0
var login_precheck_in_progress := false
var login_precheck_mode := ""

# -------- LIFECYCLE --------
func _ready():
	randomize()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS
	http.request_completed.connect(_on_request_completed)
	_load_queue()

# -------- PUBLIC API --------
func add_action(action : Dictionary):
	if not action.has("retries"):
		action["retries"] = 0
	queue.append(action)
	_save_queue()
	_log("Action queued | type=%s | queue_size=%s" % [str(action.get("type", "unknown")), str(queue.size())])

# -------- QUEUE PERSISTENCE --------
func _save_queue():
	var f = FileAccess.open(queue_file_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(queue))
	f.close()

func _load_queue():
	if not FileAccess.file_exists(queue_file_path):
		queue = []
		return
	var f = FileAccess.open(queue_file_path, FileAccess.READ)
	if f == null:
		queue = []
		return
	queue = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(queue) != TYPE_ARRAY:
		queue = []

func _build_multipart_file_body(filepath: String, session_id := "", extra_fields := {}) -> Dictionary:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return {"ok": false}

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
	return {
		"ok": true,
		"boundary": boundary,
		"body": body_bytes + file_bytes + end
	}

# -------- TOKEN HELPERS --------
func _generate_token() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var token = ""
	for _i in range(TOKEN_LENGTH):
		token += chars[randi() % chars.length()]
	return token

func _response_contains_token(response_data, token_to_find: String) -> bool:
	if typeof(response_data) == TYPE_DICTIONARY:
		if response_data.has("token") and str(response_data["token"]) == token_to_find:
			return true
		if response_data.has("results") and typeof(response_data["results"]) == TYPE_ARRAY:
			for item in response_data["results"]:
				if typeof(item) == TYPE_DICTIONARY and item.has("token") and str(item["token"]) == token_to_find:
					return true
		return false

	if typeof(response_data) == TYPE_ARRAY:
		for item in response_data:
			if typeof(item) == TYPE_DICTIONARY and item.has("token") and str(item["token"]) == token_to_find:
				return true
		return false

	return false

func _remove_temp_seed_file(seed_value: String) -> void:
	if seed_value == "":
		return
	var temp_file_path = "user://temp_seed_%s.dat" % seed_value
	if FileAccess.file_exists(temp_file_path):
		DirAccess.remove_absolute(temp_file_path)

func _drop_current_action(action: Dictionary) -> void:
	if action.get("type", "") == "create_seed":
		_remove_temp_seed_file(str(action.get("seed_value", "")))
	queue.pop_front()
	_save_queue()
	retry_delay = 0.5

func _has_pending_login_action() -> bool:
	for action in queue:
		if str(action.get("type", "")) == "login":
			return true
	return false

func _defer_current_action(reason: String) -> void:
	if queue.is_empty():
		return

	var action = queue.pop_front()
	queue.append(action)
	_save_queue()
	retry_delay = 0.5
	if reason != "":
		_log(reason)

func _normalize_queued_session_id(action: Dictionary) -> void:
	var session_id = str(action.get("session_id", ""))
	if session_id.find("_-2_") == -1:
		return

	var player_token = str(PlayerData.token).strip_edges()
	if player_token == "":
		return

	action["session_id"] = session_id.replace("_-2_", "_" + player_token + "_")
	_save_queue()
	_log("Queued session_id migrated from local user_id to player token")

func _migrate_legacy_doctor_report_action(action: Dictionary) -> bool:
	if str(action.get("type", "")) != "file":
		return false

	var url = str(action.get("url", ""))
	if url.find("doctor-report/") == -1:
		return false

	var extra_fields = action.get("extra_fields", {})
	if typeof(extra_fields) != TYPE_DICTIONARY or not extra_fields.has("seed"):
		return false

	var raw_seed = extra_fields.get("seed")
	if typeof(raw_seed) != TYPE_STRING:
		return false

	var seed_value = str(raw_seed).strip_edges()
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
	_save_queue()
	_log("Migrated legacy doctor report action to create_seed flow")
	return true

func _schedule_retry_for_action(action: Dictionary, retry_log: String, drop_log: String) -> void:
	action["retries"] = int(action.get("retries", 0)) + 1
	if retry_log != "":
		_log(retry_log % [str(action.get("type", "unknown")), str(action["retries"])])

	if action["retries"] > MAX_RETRIES:
		if drop_log != "":
			_log(drop_log % str(action.get("type", "unknown")))
		_drop_current_action(action)
		_process_next()
		return

	_save_queue()
	await get_tree().create_timer(retry_delay).timeout
	retry_delay = min(retry_delay * 2.0, max_retry_delay)
	_process_next()

# -------- API HELPERS --------
func _is_token_available_from_lookup(code: int, body_text: String, token_to_find: String) -> bool:
	if code == 404:
		return true
	if code < 200 or code >= 300:
		return false
	if body_text.strip_edges() == "":
		return true

	var parsed = JSON.parse_string(body_text)
	return not _response_contains_token(parsed, token_to_find)

func _is_lookup_token_found(code: int, body_text: String, token_to_find: String) -> bool:
	if code == 404:
		return false
	if code < 200 or code >= 300:
		return false
	if body_text.strip_edges() == "":
		return false

	var parsed = JSON.parse_string(body_text)
	return _response_contains_token(parsed, token_to_find)

func _extract_lookup_doctor_id(code: int, body_text: String, token_to_find: String) -> int:
	if code == 404:
		return -1
	if code < 200 or code >= 300:
		return -1
	if body_text.strip_edges() == "":
		return -1

	var response = JSON.parse_string(body_text)

	if typeof(response) == TYPE_DICTIONARY:
		if response.has("id"):
			if response.has("token"):
				if str(response["token"]) == token_to_find:
					return int(response["id"])
			else:
				return int(response["id"])

		if response.has("results") and typeof(response["results"]) == TYPE_ARRAY:
			for item in response["results"]:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				if not item.has("id"):
					continue
				if item.has("token") and str(item["token"]) != token_to_find:
					continue
				return int(item["id"])

	if typeof(response) == TYPE_ARRAY:
		for item in response:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			if not item.has("id"):
				continue
			if item.has("token") and str(item["token"]) != token_to_find:
				continue
			return int(item["id"])

	return -1

func _build_user_request_payload(data: Dictionary) -> Dictionary:
	var payload := {
		"token": data.get("token", ""),
		"birth_year": data.get("birth_year", null)
	}

	if data.has("uuid"):
		payload["uuid"] = data.get("uuid")

	payload["user_birth_year"] = payload["birth_year"]
	payload["patient_birth_year"] = payload["birth_year"]

	var doctor_key = str(data.get("doctor_key", data.get("medecin_key", ""))).strip_edges()
	if doctor_key != "":
		payload["doctor_key"] = doctor_key
	var doctor_id = int(data.get("doctor_id", data.get("medecin_id", -1)))
	if doctor_id >= 0:
		payload["doctor_id"] = doctor_id

	return payload

func _string_contains_any(text: String, needles: Array[String]) -> bool:
	var haystack = text.to_lower()
	for needle in needles:
		if haystack.find(needle) != -1:
			return true
	return false

func _is_duplicate_report_error(action: Dictionary, code: int, body_text: String) -> bool:
	if code != 400:
		return false
	var action_type = str(action.get("type", ""))
	if action_type != "file":
		return false
	var url = str(action.get("url", ""))
	if url.find("full-report/") == -1 and url.find("doctor-report/") == -1:
		return false
	return body_text.find("must make a unique set") != -1

func _is_doctor_not_found_error(code: int, body_text: String, action: Dictionary) -> bool:
	if code != 400 and code != 404:
		return false

	var data = action.get("data", {})
	if typeof(data) != TYPE_DICTIONARY or (not data.has("doctor_key") and not data.has("medecin_key")):
		return false

	var doctor_terms: Array[String] = ["doctor", "physician", "medecin"]
	var missing_terms: Array[String] = ["not found", "does not exist", "n'existe", "introuvable", "invalid", "invalide"]

	var lowered_body = body_text.to_lower()
	if _string_contains_any(lowered_body, doctor_terms) and _string_contains_any(lowered_body, missing_terms):
		return true

	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in ["doctor_key", "doctor", "physician", "medecin", "detail", "message", "error"]:
			if not parsed.has(key):
				continue
			var value_text = str(parsed[key]).to_lower()
			if _string_contains_any(value_text, doctor_terms) and _string_contains_any(value_text, missing_terms):
				return true
			if key in ["doctor_key", "doctor", "physician", "medecin"] and _string_contains_any(value_text, missing_terms):
				return true

	return false

func force_sync():
	if queue.is_empty():
		print("[SyncManager] Queue is empty, sync_done = true")
		sync_done = true
		_log("force_sync called with empty queue")
		return
	sync_start_time = Time.get_ticks_msec()
	sync_done = false
	_log("force_sync started | queue_size=%s" % str(queue.size()))
	_process_next()

func _handle_immediate_request_error() -> void:
	is_running = false

	if queue.is_empty():
		var elapsed = Time.get_ticks_msec() - sync_start_time
		sync_done = true
		_log("Sync complete | elapsed_ms=%s" % str(elapsed))
		return

	var action = queue[0]
	await _schedule_retry_for_action(
		action,
		"Immediate request error | type=%s | retries=%s",
		"Dropping action after max retries | type=%s"
	)

# -------- SYNC FLOW --------
func _process_next():
	if queue.is_empty():
		var elapsed = Time.get_ticks_msec() - sync_start_time
		print("[SyncManager] Queue processed. Total sync time: %d ms" % elapsed)
		sync_done = true
		return

	if is_running:
		print("[SyncManager] Already running, waiting...")
		return

	is_running = true
	var action = queue[0]
	_normalize_queued_session_id(action)
	request_start_time = Time.get_ticks_msec()
	_log("Processing action | type=%s | retries=%s" % [str(action.get("type", "unknown")), str(action.get("retries", 0))])

	if _migrate_legacy_doctor_report_action(action):
		is_running = false
		_process_next()
		return

	if action["type"] == "login":
		var login_data = action.get("data", {})
		if bool(login_data.get("token_generated_offline", false)):
			var token_to_check = str(login_data.get("token", "")).strip_edges()
			if token_to_check != "":
				var has_lookup_token = await GameManager.ensure_valid_access_token()
				if not has_lookup_token:
					_log("Token precheck auth unavailable")
					_handle_immediate_request_error()
					return
				login_precheck_in_progress = true
				login_precheck_mode = "token"
				var check_err := http.request(
					BASE_URL + "user/?token=" + token_to_check,
					GameManager.get_api_headers(),
					HTTPClient.METHOD_GET
				)
				if check_err != OK:
					_log("Token precheck request failed immediately")
					login_precheck_in_progress = false
					login_precheck_mode = ""
					_handle_immediate_request_error()
				return

			login_data["token_generated_offline"] = false
			action["data"] = login_data
			_save_queue()

		var doctor_key_to_check = str(login_data.get("doctor_key", login_data.get("medecin_key", ""))).strip_edges()
		if doctor_key_to_check != "" and not bool(login_data.get("doctor_key_prechecked", false)):
			var has_doctor_lookup_token = await GameManager.ensure_valid_access_token()
			if not has_doctor_lookup_token:
				_log("Doctor key precheck auth unavailable")
				_handle_immediate_request_error()
				return
			login_precheck_in_progress = true
			login_precheck_mode = "doctor"
			var doctor_check_err := http.request(
				BASE_URL + DOCTOR_LOOKUP_PATH + doctor_key_to_check,
				GameManager.get_api_headers(),
				HTTPClient.METHOD_GET
			)
			if doctor_check_err != OK:
				_log("Doctor key precheck request failed immediately")
				login_precheck_in_progress = false
				login_precheck_mode = ""
				_handle_immediate_request_error()
			return

		var request_payload = action["data"].duplicate(true)
		request_payload.erase("token_generated_offline")
		request_payload.erase("doctor_key_prechecked")
		var has_login_token = await GameManager.ensure_valid_access_token()
		if not has_login_token:
			_log("Login sync auth unavailable")
			_handle_immediate_request_error()
			return
		var err := http.request(
			BASE_URL + "user/",
			GameManager.get_json_post_headers(),
			HTTPClient.METHOD_POST,
			JSON.stringify(_build_user_request_payload(request_payload))
		)
		if err != OK:
			_log("Login request failed immediately")
			_handle_immediate_request_error()

	elif action["type"] == "create_seed":
		var seed_value = str(action.get("seed_value", ""))
		var temp_file_path = "user://temp_seed_%s.dat" % seed_value
		
		var temp_file = FileAccess.open(temp_file_path, FileAccess.WRITE)
		if temp_file:
			temp_file.store_string(seed_value)
			temp_file.close()
		else:
			_handle_immediate_request_error()
			return
		
		var seed_file = FileAccess.open(temp_file_path, FileAccess.READ)
		if seed_file == null:
			if FileAccess.file_exists(temp_file_path):
				DirAccess.remove_absolute(temp_file_path)
			_handle_immediate_request_error()
			return
		
		var file_bytes = seed_file.get_buffer(seed_file.get_length())
		seed_file.close()
		
		var boundary = "----GodotBoundary"
		var body = ""
		
		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="name"\r\n\r\n'
		body += seed_value + "\r\n"
		
		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="file"; filename="seed.dat"\r\n'
		body += "Content-Type: application/octet-stream\r\n\r\n"
		
		var body_bytes = body.to_utf8_buffer()
		var end = ("\r\n--" + boundary + "--\r\n").to_utf8_buffer()
		var final_body = body_bytes + file_bytes + end
		var has_seed_token = await GameManager.ensure_valid_access_token()
		if not has_seed_token:
			_log("Seed upload auth unavailable")
			_handle_immediate_request_error()
			return
		
		var err := http.request_raw(
			BASE_URL + "seed/",
			GameManager.get_multipart_post_headers(boundary),
			HTTPClient.METHOD_POST,
			final_body
		)
		if err != OK:
			_log("Seed upload request failed immediately")
			_handle_immediate_request_error()

	elif action["type"] == "report":
		var has_report_token = await GameManager.ensure_valid_access_token()
		if not has_report_token:
			_log("Report sync auth unavailable")
			_handle_immediate_request_error()
			return
		var err := http.request(
			BASE_URL + "full-report/",
			GameManager.get_json_post_headers(),
			HTTPClient.METHOD_POST,
			JSON.stringify(action["data"])
		)
		if err != OK:
			print("[SyncManager] ERROR: Report request failed with error code: %d" % err)
			_handle_immediate_request_error()

	elif action["type"] == "file":
		if PlayerData.user_id < 0:
			if _has_pending_login_action():
				_defer_current_action("File upload deferred until login sync provides a valid user_id")
				is_running = false
				_process_next()
				return
			_log("File upload has no valid user_id yet")
			await _schedule_retry_for_action(
				action,
				"File upload waiting for valid user_id | type=%s | retries=%s",
				"Dropping action after max retries | type=%s"
			)
			return

		var filepath = str(action.get("path", ""))
		if filepath == "" or not FileAccess.file_exists(filepath):
			_log("File action dropped, missing file | path=%s" % filepath)
			_drop_current_action(action)
			_process_next()
			return

		var upload_payload = _build_multipart_file_body(
			filepath,
			str(action.get("session_id", "")),
			action.get("extra_fields", {})
		)
		if not bool(upload_payload.get("ok", false)):
			_log("File action could not read file | path=%s" % filepath)
			_drop_current_action(action)
			_process_next()
			return

		var has_file_token = await GameManager.ensure_valid_access_token()
		if not has_file_token:
			_log("File upload auth unavailable")
			_handle_immediate_request_error()
			return

		var err := http.request_raw(
			str(action.get("url", "")),
			GameManager.get_multipart_post_headers(str(upload_payload.get("boundary", ""))),
			HTTPClient.METHOD_POST,
			upload_payload.get("body", PackedByteArray())
		)
		if err != OK:
			_log("File upload request failed immediately")
			_handle_immediate_request_error()

func _on_request_completed(result, code, _headers, body):
	is_running = false

	if queue.is_empty():
		return

	var action = queue[0]
	var action_type = action.get("type", "unknown")
	var body_text: String = body.get_string_from_utf8().strip_edges()

	if action_type == "login" and login_precheck_in_progress:
		login_precheck_in_progress = false
		var precheck_mode = login_precheck_mode
		login_precheck_mode = ""

		if result != HTTPRequest.RESULT_SUCCESS:
			_log("Login precheck failed (network) | mode=%s | retrying" % precheck_mode)
			await _schedule_retry_for_action(action, "", "")
			return

		var login_data = action.get("data", {})
		var current_token = str(login_data.get("token", "")).strip_edges()
		var lookup_body_text = body.get_string_from_utf8()

		if code != 404 and (code < 200 or code >= 300):
			_log("Login precheck failed (code=%s) | mode=%s | retrying" % [str(code), precheck_mode])
			await _schedule_retry_for_action(action, "", "")
			return

		if precheck_mode == "doctor":
			var doctor_key = str(login_data.get("doctor_key", login_data.get("medecin_key", ""))).strip_edges()
			var doctor_found = _is_lookup_token_found(code, lookup_body_text, doctor_key)

			login_data["doctor_key_prechecked"] = true
			if doctor_key != "" and not doctor_found:
				login_data.erase("doctor_key")
				login_data.erase("medecin_key")
				action["data"] = login_data
				_save_queue()
				if PlayerData.user_id != -1 and str(PlayerData.doctor_key).strip_edges() == doctor_key:
					PlayerData.doctor_key = ""
					GestionFichier.save_data()
				_log("Doctor key not found during precheck. Sync login will continue without doctor key.")
				_process_next()
				return

			var doctor_id = _extract_lookup_doctor_id(code, lookup_body_text, doctor_key)
			if doctor_id >= 0:
				login_data["doctor_id"] = doctor_id
				login_data.erase("medecin_id")
			action["data"] = login_data
			_save_queue()
			_process_next()
			return

		var token_available = _is_token_available_from_lookup(code, lookup_body_text, current_token)

		if token_available:
			login_data["token_generated_offline"] = false
			action["data"] = login_data
			action["token_conflict_regen_attempts"] = 0
			_save_queue()
			_process_next()
			return

		var regen_attempts = int(action.get("token_conflict_regen_attempts", 0)) + 1
		action["token_conflict_regen_attempts"] = regen_attempts

		if regen_attempts > MAX_TOKEN_CONFLICT_REGEN_ATTEMPTS:
			_log("Too many token conflict regenerations, counting as retry")
			action["token_conflict_regen_attempts"] = 0
			await _schedule_retry_for_action(action, "", "")
			return

		var old_token = current_token
		var new_token = _generate_token()
		login_data["token"] = new_token
		login_data["token_generated_offline"] = true
		action["data"] = login_data
		_save_queue()

		if PlayerData.token == old_token:
			PlayerData.token = new_token
			PlayerData.token_update_pending = true
			PlayerData.previous_token = old_token
			PlayerData.updated_token = new_token
			GestionFichier.save_data()
		_process_next()
		return

	if result != HTTPRequest.RESULT_SUCCESS or (code != 200 and code != 201):
		if result == HTTPRequest.RESULT_SUCCESS and action_type == "login":
			if _is_doctor_not_found_error(code, body_text, action):
				var login_data = action.get("data", {})
				login_data.erase("doctor_key")
				login_data.erase("medecin_key")
				action["data"] = login_data
				if PlayerData.user_id != -1:
					PlayerData.doctor_key = ""
					GestionFichier.save_data()
				_save_queue()
				_log("Doctor key not found during sync. Retrying login without doctor key.")
				_process_next()
				return
		if result == HTTPRequest.RESULT_SUCCESS and _is_duplicate_report_error(action, code, body_text):
			_log("Remote report already exists, dropping duplicate queued upload | url=%s" % str(action.get("url", "")))
			queue.pop_front()
			_save_queue()
			retry_delay = 0.5
			_process_next()
			return

		_log("Request failed | type=%s | code=%s | result=%s | url=%s | body=%s" % [
			action_type,
			str(code),
			str(result),
			str(action.get("url", "")),
			body_text
		])
		await _schedule_retry_for_action(
			action,
			"",
			"Dropping action after max retries | type=%s"
		)
		return

	retry_delay = 0.5
	queue.pop_front()
	_save_queue()

	# -------- LOGIN --------
	if action["type"] == "login":
		var response = JSON.parse_string(body.get_string_from_utf8())

		if typeof(response) == TYPE_DICTIONARY and response.has("id"):
			var synced_user_id = int(response["id"])
			var login_data = action.get("data", {})

			var synced_token = str(login_data.get("token", PlayerData.token))
			var synced_uuid = str(response.get("uuid", login_data.get("uuid", PlayerData.uuid)))
			var synced_birth_year = login_data.get("birth_year", "")
			var synced_doctor_key = str(login_data.get("doctor_key", login_data.get("medecin_key", "")))

			PlayerData.set_user(synced_user_id, synced_uuid, synced_token, synced_birth_year, synced_doctor_key)

			if str(synced_birth_year).is_valid_int():
				PlayerData.birth_year = int(synced_birth_year)
			else:
				PlayerData.birth_year = -1

			for a in queue:
				if a["type"] == "report":
					a["data"]["user_id"] = PlayerData.user_id
					a["data"]["birth_year"] = PlayerData.birth_year

			_save_queue()
			GestionFichier.save_data()

	elif action["type"] == "create_seed":
		var response = JSON.parse_string(body_text)
		if typeof(response) == TYPE_DICTIONARY and response.has("id"):
			var seed_id = int(response["id"])
			var extra_fields = action.get("extra_fields", {})
			if typeof(extra_fields) != TYPE_DICTIONARY:
				extra_fields = {}
			else:
				extra_fields = extra_fields.duplicate(true)
			extra_fields["seed"] = seed_id
			queue.insert(0, {
				"type": "file",
				"path": str(action.get("report_path", "user://doctor_report.dat")),
				"url": str(action.get("report_url", BASE_URL + "doctor-report/")),
				"session_id": str(action.get("session_id", "")),
				"retries": 0,
				"extra_fields": extra_fields
			})
			_save_queue()
		else:
			_log("Seed creation response invalid | body=%s" % body_text)

	_process_next()
