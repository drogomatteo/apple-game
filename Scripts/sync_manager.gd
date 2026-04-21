extends Node

const LOG_TAG := "[SyncManager]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"
const DOCTOR_LOOKUP_PATH := "medecin/?token="
var file_path = "user://offline_queue.json"
const REQUEST_TIMEOUT_SECONDS := 5.0
const MAX_RETRIES := 10
const TOKEN_LENGTH := 8
const MAX_TOKEN_CONFLICT_REGEN_ATTEMPTS := 20

var queue : Array = []
var http := HTTPRequest.new()
var is_running = false
var sync_done = false

var retry_delay = 0.5
var max_retry_delay = 5.0

# Variables de tracking pour le diagnostic
var sync_start_time = 0
var request_start_time = 0
var login_precheck_in_progress := false
var login_precheck_mode := ""

func _ready():
	randomize()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS
	http.request_completed.connect(_on_request_completed)
	load_queue()

func add_action(action : Dictionary):
	if not action.has("retries"):
		action["retries"] = 0
	queue.append(action)
	save_queue()
	_log("Action queued | type=%s | queue_size=%s" % [str(action.get("type", "unknown")), str(queue.size())])

func save_queue():
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(queue))
	f.close()

func load_queue():
	if not FileAccess.file_exists(file_path):
		queue = []
		return
	var f = FileAccess.open(file_path, FileAccess.READ)
	queue = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(queue) != TYPE_ARRAY:
		queue = []

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
		"age": data.get("age", null)
	}

	if data.has("uuid"):
		payload["uuid"] = data.get("uuid")

	# Compatibilité backend: certains endpoints lisent un alias différent pour l'âge.
	payload["user_age"] = payload["age"]
	payload["patient_age"] = payload["age"]

	var doctor_key = str(data.get("medecin_key", "")).strip_edges()
	if doctor_key != "":
		payload["medecin_key"] = doctor_key
	var doctor_id = int(data.get("medecin_id", -1))
	if doctor_id >= 0:
		payload["id_med"] = doctor_id

	return payload

func _string_contains_any(text: String, needles: Array[String]) -> bool:
	var haystack = text.to_lower()
	for needle in needles:
		if haystack.find(needle) != -1:
			return true
	return false

func _is_doctor_not_found_error(code: int, body_text: String, action: Dictionary) -> bool:
	if code != 400 and code != 404:
		return false

	var data = action.get("data", {})
	if typeof(data) != TYPE_DICTIONARY or not data.has("medecin_key"):
		return false

	var doctor_terms: Array[String] = ["medecin", "doctor", "physician"]
	var missing_terms: Array[String] = ["not found", "does not exist", "n'existe", "introuvable", "invalid", "invalide"]

	var lowered_body = body_text.to_lower()
	if _string_contains_any(lowered_body, doctor_terms) and _string_contains_any(lowered_body, missing_terms):
		return true

	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in ["medecin_key", "doctor_key", "doctor", "medecin", "physician", "detail", "message", "error"]:
			if not parsed.has(key):
				continue
			var value_text = str(parsed[key]).to_lower()
			if _string_contains_any(value_text, doctor_terms) and _string_contains_any(value_text, missing_terms):
				return true
			if key in ["medecin_key", "doctor_key", "doctor", "medecin", "physician"] and _string_contains_any(value_text, missing_terms):
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
	process_next()

func _handle_immediate_request_error() -> void:
	is_running = false

	if queue.is_empty():
		var elapsed = Time.get_ticks_msec() - sync_start_time
		sync_done = true
		_log("Sync complete | elapsed_ms=%s" % str(elapsed))
		return

	var action = queue[0]
	action["retries"] += 1
	
	# Vérifier si on a dépassé le nombre maximal de retries
	if action["retries"] > MAX_RETRIES:
		print("[SyncManager] CRITICAL: Action type=%s has exceeded max retries (%d). Abandoning it." % [action.get("type", "unknown"), MAX_RETRIES])
		
		# Nettoyer le fichier temporaire si c'est une création de seed
		if action.get("type", "") == "create_seed":
			var seed_value = str(action.get("seed_value", ""))
			var temp_file_path = "user://temp_seed_%s.dat" % seed_value
			if FileAccess.file_exists(temp_file_path):
				DirAccess.remove_absolute(temp_file_path)
				print("[SyncManager] Cleaned up temp seed file: %s" % temp_file_path)
		
		queue.pop_front()
		save_queue()
		retry_delay = 0.5  # Réinitialiser le délai
		process_next()
		return

	save_queue()
	await get_tree().create_timer(retry_delay).timeout
	retry_delay = min(retry_delay * 2.0, max_retry_delay)
	process_next()

func process_next():
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
	request_start_time = Time.get_ticks_msec()
	_log("Processing action | type=%s | retries=%s" % [str(action.get("type", "unknown")), str(action.get("retries", 0))])

	if action["type"] == "login":
		var login_data = action.get("data", {})
		if str(login_data.get("token", "")).to_lower() == "guest":
			login_data["age"] = null
			login_data.erase("medecin_key")
			login_data["token_generated_offline"] = false
			action["data"] = login_data
			save_queue()

		if bool(login_data.get("token_generated_offline", false)):
			var token_to_check = str(login_data.get("token", "")).strip_edges()
			if token_to_check != "" and token_to_check.to_lower() != "guest":
				login_precheck_in_progress = true
				login_precheck_mode = "token"
				var check_err := http.request(
					BASE_URL + "user/?token=" + token_to_check,
					[],
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
			save_queue()

		var doctor_key_to_check = str(login_data.get("medecin_key", "")).strip_edges()
		if doctor_key_to_check != "" and not bool(login_data.get("doctor_key_prechecked", false)):
			login_precheck_in_progress = true
			login_precheck_mode = "doctor"
			var doctor_check_err := http.request(
				BASE_URL + DOCTOR_LOOKUP_PATH + doctor_key_to_check,
				[],
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
		var err := http.request(
			BASE_URL + "user/",
			["Content-Type: application/json"],
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
		body += 'Content-Disposition: form-data; name="nom"\r\n\r\n'
		body += seed_value + "\r\n"
		
		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="seed_file"; filename="seed.dat"\r\n'
		body += "Content-Type: application/octet-stream\r\n\r\n"
		
		var body_bytes = body.to_utf8_buffer()
		var end = ("\r\n--" + boundary + "--\r\n").to_utf8_buffer()
		var final_body = body_bytes + file_bytes + end
		
		var err := http.request_raw(
			BASE_URL + "seed/",
			["Content-Type: multipart/form-data; boundary=" + boundary],
			HTTPClient.METHOD_POST,
			final_body
		)
		if err != OK:
			_log("Seed upload request failed immediately")
			_handle_immediate_request_error()

	elif action["type"] == "report":
		var err := http.request(
			BASE_URL + "rapport_complet/",
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(action["data"])
		)
		if err != OK:
			print("[SyncManager] ERROR: Report request failed with error code: %d" % err)
			_handle_immediate_request_error()

	elif action["type"] == "file":

		var filepath = action["path"]
		var url = action["url"]
		var session_id = action.get("session_id", "")
		var extra_fields = action.get("extra_fields", {})

		var file = FileAccess.open(filepath, FileAccess.READ)
		if file == null:
			queue.pop_front()
			save_queue()
			is_running = false
			process_next()
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

		var err := http.request_raw(
			url,
			["Content-Type: multipart/form-data; boundary=" + boundary],
			HTTPClient.METHOD_POST,
			final_body
		)
		if err != OK:
			_handle_immediate_request_error()

func _on_request_completed(result, code, headers, body):
	var elapsed = Time.get_ticks_msec() - request_start_time
	is_running = false

	if queue.is_empty():
		return

	var action = queue[0]
	var action_type = action.get("type", "unknown")

	if action_type == "login" and login_precheck_in_progress:
		login_precheck_in_progress = false
		var precheck_mode = login_precheck_mode
		login_precheck_mode = ""

		if result != HTTPRequest.RESULT_SUCCESS:
			_log("Login precheck failed (network) | mode=%s | retrying" % precheck_mode)
			action["retries"] += 1

			if action["retries"] > MAX_RETRIES:
				queue.pop_front()
				save_queue()
				retry_delay = 0.5
				process_next()
				return

			await get_tree().create_timer(retry_delay).timeout
			retry_delay = min(retry_delay * 2.0, max_retry_delay)
			save_queue()
			process_next()
			return

		var login_data = action.get("data", {})
		var current_token = str(login_data.get("token", "")).strip_edges()
		var lookup_body_text = body.get_string_from_utf8()

		if code != 404 and (code < 200 or code >= 300):
			_log("Login precheck failed (code=%s) | mode=%s | retrying" % [str(code), precheck_mode])
			action["retries"] += 1

			if action["retries"] > MAX_RETRIES:
				queue.pop_front()
				save_queue()
				retry_delay = 0.5
				process_next()
				return

			await get_tree().create_timer(retry_delay).timeout
			retry_delay = min(retry_delay * 2.0, max_retry_delay)
			save_queue()
			process_next()
			return

		if precheck_mode == "doctor":
			var doctor_key = str(login_data.get("medecin_key", "")).strip_edges()
			var doctor_found = _is_lookup_token_found(code, lookup_body_text, doctor_key)

			login_data["doctor_key_prechecked"] = true
			if doctor_key != "" and not doctor_found:
				login_data.erase("medecin_key")
				action["data"] = login_data
				save_queue()
				if PlayerData.user_id != -1 and str(PlayerData.medecin_key).strip_edges() == doctor_key:
					PlayerData.medecin_key = ""
					GestionFichier.save_data()
				_log("Doctor key not found during precheck. Sync login will continue without doctor key.")
				process_next()
				return

			var doctor_id = _extract_lookup_doctor_id(code, lookup_body_text, doctor_key)
			if doctor_id >= 0:
				login_data["medecin_id"] = doctor_id
			action["data"] = login_data
			save_queue()
			process_next()
			return

		var token_available = _is_token_available_from_lookup(code, lookup_body_text, current_token)

		if token_available:
			login_data["token_generated_offline"] = false
			action["data"] = login_data
			action["token_conflict_regen_attempts"] = 0
			save_queue()
			process_next()
			return

		var regen_attempts = int(action.get("token_conflict_regen_attempts", 0)) + 1
		action["token_conflict_regen_attempts"] = regen_attempts

		if regen_attempts > MAX_TOKEN_CONFLICT_REGEN_ATTEMPTS:
			_log("Too many token conflict regenerations, counting as retry")
			action["retries"] += 1
			action["token_conflict_regen_attempts"] = 0

			if action["retries"] > MAX_RETRIES:
				queue.pop_front()
				save_queue()
				retry_delay = 0.5
				process_next()
				return

			await get_tree().create_timer(retry_delay).timeout
			retry_delay = min(retry_delay * 2.0, max_retry_delay)
			save_queue()
			process_next()
			return

		var old_token = current_token
		var new_token = _generate_token()
		login_data["token"] = new_token
		login_data["token_generated_offline"] = true
		action["data"] = login_data
		save_queue()

		if PlayerData.token == old_token:
			PlayerData.token = new_token
			GestionFichier.save_data()
		process_next()
		return

	if result != HTTPRequest.RESULT_SUCCESS or (code != 200 and code != 201):
		if result == HTTPRequest.RESULT_SUCCESS and action_type == "login":
			var body_text = body.get_string_from_utf8()
			if _is_doctor_not_found_error(code, body_text, action):
				var login_data = action.get("data", {})
				login_data.erase("medecin_key")
				action["data"] = login_data
				if PlayerData.user_id != -1:
					PlayerData.medecin_key = ""
					GestionFichier.save_data()
				save_queue()
				_log("Doctor key not found during sync. Retrying login without doctor key.")
				process_next()
				return

		_log("Request failed | type=%s | code=%s | result=%s" % [action_type, str(code), str(result)])
		action["retries"] += 1
		print("[SyncManager] ERROR: Request failed. Result=%d, Code=%d, Retries=%d. Retry delay: %.1f s" % [result, code, action["retries"], retry_delay])
		print("[SyncManager] Response body: %s" % body.get_string_from_utf8())

		if action["retries"] > MAX_RETRIES:
			_log("Dropping action after max retries | type=%s" % action_type)
			queue.pop_front()
			save_queue()
			retry_delay = 0.5
			process_next()
			return

		await get_tree().create_timer(retry_delay).timeout
		retry_delay = min(retry_delay * 2.0, max_retry_delay)
		save_queue()
		process_next()
		return

	retry_delay = 0.5
	queue.pop_front()
	save_queue()

	# -------- LOGIN --------
	if action["type"] == "login":
		var response = JSON.parse_string(body.get_string_from_utf8())

		if typeof(response) == TYPE_DICTIONARY and response.has("id"):
			var synced_user_id = int(response["id"])
			var login_data = action.get("data", {})

			var synced_token = str(login_data.get("token", PlayerData.token))
			var synced_uuid = str(response.get("uuid", login_data.get("uuid", PlayerData.uuid)))
			var synced_age = login_data.get("age", "") # ← AGE
			var synced_medecin_key = str(login_data.get("medecin_key", ""))

			if synced_token.to_lower() == "guest":
				PlayerData.set_guest(synced_user_id)
				PlayerData.token = "guest"
				PlayerData.uuid = "none"
				PlayerData.age = "" # ← AGE
				PlayerData.medecin_key = ""
			else:
				PlayerData.set_user(synced_user_id, synced_uuid, synced_token, synced_age, synced_medecin_key)

				if str(synced_age).is_valid_int(): # ← AGE
					PlayerData.age = int(synced_age)
				else:
					PlayerData.age = -1

			for a in queue:
				if a["type"] == "report":
					a["data"]["user_id"] = PlayerData.user_id
					a["data"]["age"] = PlayerData.age # ← AGE

			save_queue()
			GestionFichier.save_data()

	elif action["type"] == "create_seed":
		var response = JSON.parse_string(body.get_string_from_utf8())
		print("[SyncManager] SeedLevel creation response: %s" % response)
		
		if typeof(response) == TYPE_DICTIONARY and response.has("id"):
			var seed_id = int(response["id"])
			var session_id = action.get("session_id", "")
			var seed_value = str(action.get("seed_value", ""))
			
			print("[SyncManager] SeedLevel created with ID: %d" % seed_id)
			
			# Nettoyer le fichier temporaire
			var temp_file_path = "user://temp_seed_%s.dat" % seed_value
			if FileAccess.file_exists(temp_file_path):
				DirAccess.remove_absolute(temp_file_path)
				print("[SyncManager] Cleaned up temp seed file: %s" % temp_file_path)
			
			# Ajouter l'action pour envoyer le rapport médecin avec l'ID de la seed
			queue.insert(0, {
				"type": "file",
				"path": "user://rapport_medecin.dat",
				"url": BASE_URL + "rapport_medecin/",
				"session_id": session_id,
				"extra_fields": {"seed": seed_id},
				"retries": 0
			})
			save_queue()
			print("[SyncManager] Queued rapport_medecin to be sent with seed ID: %d" % seed_id)
		else:
			print("[SyncManager] ERROR: Invalid response format for create_seed")

	process_next()
