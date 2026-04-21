extends Control

const LOG_TAG := "[UserMenu]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

@onready var http = $HTTPRequest
@onready var token_input = $CenterContainer/HBoxContainer/VBoxContainer/TokenInput
@onready var age_input = $CenterContainer/HBoxContainer/VBoxContainer/AgeInput
@onready var doctor_key_input = $CenterContainer/HBoxContainer/VBoxContainer/DoctorKeyInput
@onready var save_button = $CenterContainer/HBoxContainer/VBoxContainer/SaveButton
@onready var guest_button = $CenterContainer/HBoxContainer/VBoxContainer2/GuestButton
@onready var status_label = $CenterContainer/HBoxContainer/VBoxContainer2/StatusLabel
@onready var generate_button = $CenterContainer/HBoxContainer/VBoxContainer2/GenerateTokenButton
@onready var back_button = $BackButton

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"
const DOCTOR_LOOKUP_PATH := "medecin/?token="
const REQUEST_TIMEOUT_SECONDS := 5.0
const TOKEN_LENGTH := 8
const MAX_TOKEN_GENERATION_ATTEMPTS := 20
const PREFILL_MIN_TOKEN_LENGTH := 1

var is_request_running = false
var is_guest_mode = false
var pending_login_data : Dictionary = {}
var first_login := false
var is_doctor_key_lookup = false
var pending_doctor_key = ""
var pending_doctor_id := -1
var pending_existing_medecins: Array[int] = []
var prefill_http := HTTPRequest.new()
var is_prefill_lookup_in_progress := false
var pending_prefill_token := ""
var pending_prefill_generation := 0
var token_input_generation := 0
var last_autofill_token := ""
var last_autofill_age := ""
var last_autofill_doctor_key := ""

# -------- TOKEN GENERATION STATE --------
var is_generating_token = false
var generated_token = ""
var token_generation_attempts := 0
var offline_generated_token_value := ""

func _ready():
	randomize()
	http.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(prefill_http)
	prefill_http.timeout = REQUEST_TIMEOUT_SECONDS
	prefill_http.request_completed.connect(_on_prefill_request_completed)
	token_input.focus_exited.connect(_on_token_input_focus_exited)

	if first_login:
		back_button.visible = false
		back_button.disabled = true
	else:
		back_button.visible = true
		back_button.disabled = false

	if PlayerData.user_id != -1:
		token_input.text = PlayerData.token
		age_input.text = str(PlayerData.age)
		doctor_key_input.text = PlayerData.medecin_key

	update_button()

func _on_input_changed(_text=""):
	token_input_generation += 1
	var token = token_input.text.strip_edges().to_lower()
	if offline_generated_token_value != "" and token_input.text.strip_edges() != offline_generated_token_value:
		offline_generated_token_value = ""

	if token == "guest":
		is_guest_mode = true
		age_input.text = ""
		age_input.editable = false
		doctor_key_input.text = ""
		doctor_key_input.editable = false
	else:
		if is_guest_mode:
			age_input.text = ""
		is_guest_mode = false
		age_input.editable = true
		doctor_key_input.editable = true
		if token_input.text.strip_edges() != last_autofill_token:
			_clear_previous_autofill_if_still_present()

	update_button()

func update_button():
	var token = token_input.text.strip_edges()
	var age = age_input.text.strip_edges()

	save_button.disabled = (token == "" or age == "")

	if token != "" and age != "":
		status_label.text = ""

func get_device_uuid() -> String:
	return OS.get_unique_id()

func is_valid_age(age_text: String) -> bool:
	if age_text == "":
		return false
	for c in age_text:
		if not c.is_valid_int():
			return false
	return true

# -------- TOKEN GENERATION --------
func set_ui_locked(locked: bool) -> void:
	save_button.disabled = locked
	guest_button.disabled = locked
	back_button.disabled = locked or first_login
	token_input.editable = not locked
	age_input.editable = not locked and not is_guest_mode
	doctor_key_input.editable = not locked and not is_guest_mode
	generate_button.disabled = locked
	if not locked:
		update_button()
func generate_token() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var token = ""
	for i in range(TOKEN_LENGTH):
		token += chars[randi() % chars.length()]
	return token

func _clear_fields_for_generated_token() -> void:
	age_input.text = ""
	doctor_key_input.text = ""
	pending_prefill_token = ""
	pending_prefill_generation = 0
	_clear_previous_autofill_if_still_present()
	update_button()

func _on_generate_token_button_pressed() -> void:
	if is_request_running:
		return
	_log("Token generation requested")
	token_generation_attempts = 0
	_clear_fields_for_generated_token()
	status_label.text = "Génération..."
	set_ui_locked(true)
	_try_generate_token()

func _try_generate_token():
	token_generation_attempts += 1
	if token_generation_attempts > MAX_TOKEN_GENERATION_ATTEMPTS:
		is_generating_token = false
		is_request_running = false
		status_label.text = "Impossible de générer une clé patient"
		_log("Token generation failed after max attempts")
		set_ui_locked(false)
		return

	generated_token = generate_token()
	is_generating_token = true
	is_request_running = true

	var url = BASE_URL + "user/?token=" + generated_token
	var has_token = await GameManager.ensure_valid_access_token()
	if not has_token:
		_log("API auth unavailable on token availability check, switching to offline token generation")
		is_generating_token = false
		is_request_running = false
		_generate_token_offline()
		return

	var err = http.request(url, GameManager.get_api_headers(), HTTPClient.METHOD_GET)

	if err != OK:
		_log("Network error on token availability check, switching to offline token generation")
		is_generating_token = false
		is_request_running = false
		_generate_token_offline()

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

func _find_user_by_token_in_parsed_response(parsed, token_to_find: String) -> Dictionary:
	if typeof(parsed) == TYPE_DICTIONARY:
		if str(parsed.get("token", "")) == token_to_find:
			return parsed
		if parsed.has("results") and typeof(parsed["results"]) == TYPE_ARRAY:
			for item in parsed["results"]:
				if typeof(item) == TYPE_DICTIONARY and str(item.get("token", "")) == token_to_find:
					return item

	if typeof(parsed) == TYPE_ARRAY:
		for item in parsed:
			if typeof(item) == TYPE_DICTIONARY and str(item.get("token", "")) == token_to_find:
				return item

	return {}

func _is_token_available(response_code: int, body_text: String) -> bool:
	if response_code == 404:
		return true

	if response_code < 200 or response_code >= 300:
		return false

	if body_text.strip_edges() == "":
		return true

	var response = JSON.parse_string(body_text)
	return not _response_contains_token(response, generated_token)

func _is_lookup_token_found(response_code: int, body_text: String, token_to_find: String) -> bool:
	if response_code == 404:
		return false
	if response_code < 200 or response_code >= 300:
		return false
	if body_text.strip_edges() == "":
		return false

	var response = JSON.parse_string(body_text)
	return _response_contains_token(response, token_to_find)

func _extract_lookup_doctor_id(response_code: int, body_text: String, token_to_find: String) -> int:
	if response_code == 404:
		return -1
	if response_code < 200 or response_code >= 300:
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

func _collect_local_reserved_tokens() -> Dictionary:
	var reserved := {}

	var current_player_token = str(PlayerData.token).strip_edges()
	if current_player_token != "" and current_player_token.to_lower() != "guest":
		reserved[current_player_token] = true

	for action in SyncManager.queue:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		if action.get("type", "") != "login":
			continue
		var data = action.get("data", {})
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var queued_token = str(data.get("token", "")).strip_edges()
		if queued_token != "":
			reserved[queued_token] = true

	return reserved

func _generate_token_offline() -> void:
	var reserved_tokens = _collect_local_reserved_tokens()

	for _i in range(MAX_TOKEN_GENERATION_ATTEMPTS):
		var candidate = generate_token()
		if reserved_tokens.has(candidate):
			continue

		token_input.text = candidate
		_clear_fields_for_generated_token()
		offline_generated_token_value = candidate
		status_label.text = "Clé générée hors ligne (vérification au prochain sync)"
		set_ui_locked(false)
		return

	status_label.text = "Impossible de générer une clé patient"
	_log("Offline token generation failed")
	set_ui_locked(false)

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
	if data.has("medecins") and typeof(data["medecins"]) == TYPE_ARRAY:
		payload["medecins"] = data["medecins"]

	return payload

func _extract_medecin_ids_array(raw_value) -> Array[int]:
	var ids: Array[int] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return ids

	for item in raw_value:
		if typeof(item) == TYPE_INT or typeof(item) == TYPE_FLOAT:
			var id = int(item)
			if id >= 0 and not ids.has(id):
				ids.append(id)
		elif typeof(item) == TYPE_DICTIONARY and item.has("id"):
			var did = int(item["id"])
			if did >= 0 and not ids.has(did):
				ids.append(did)

	return ids

func _extract_user_by_token_medecins(body_text: String, token_to_find: String) -> Array[int]:
	var parsed = JSON.parse_string(body_text)
	var target = _find_user_by_token_in_parsed_response(parsed, token_to_find)

	if target.is_empty():
		return []

	return _extract_medecin_ids_array(target.get("medecins", []))

func _extract_user_by_token(body_text: String, token_to_find: String) -> Dictionary:
	var parsed = JSON.parse_string(body_text)
	return _find_user_by_token_in_parsed_response(parsed, token_to_find)

func _extract_user_age_from_lookup(user_data: Dictionary) -> String:
	for key in ["age", "user_age", "patient_age", "patientAge", "userAge"]:
		var raw_value = user_data.get(key, null)
		if raw_value == null:
			continue
		if typeof(raw_value) == TYPE_INT:
			return str(int(raw_value))
		if typeof(raw_value) == TYPE_FLOAT:
			var age_float = float(raw_value)
			if is_equal_approx(age_float, floor(age_float)):
				return str(int(age_float))
			continue

		var age_text = str(raw_value).strip_edges()
		if age_text == "" or age_text == "null":
			continue
		if age_text.is_valid_int():
			return str(int(age_text))
	return ""

func _extract_doctor_token_from_entry(entry: Dictionary) -> String:
	for key in ["token", "medecin_key", "doctor_key", "token_medecin", "doctor_token", "medecin_token"]:
		var value = str(entry.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""

func _extract_latest_doctor_token_from_lookup(user_data: Dictionary) -> String:
	for key in ["medecin_key", "doctor_key", "token_medecin", "latest_medecin_token", "latest_doctor_token", "doctor_token", "medecin_token"]:
		var direct_value = str(user_data.get(key, "")).strip_edges()
		if direct_value != "":
			return direct_value

	var medecins = user_data.get("medecins", [])
	if typeof(medecins) != TYPE_ARRAY:
		return ""

	var latest_token := ""
	var latest_created_at := ""
	var latest_id := -1

	for item in medecins:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var current_token = _extract_doctor_token_from_entry(item)
		if current_token == "":
			continue

		var created_at = str(item.get("created_at", item.get("updated_at", item.get("date_creation", "")))).strip_edges()
		var current_id = int(item.get("id", -1))

		if latest_token == "":
			latest_token = current_token
			latest_created_at = created_at
			latest_id = current_id
			continue

		if created_at != "" and created_at >= latest_created_at:
			latest_token = current_token
			latest_created_at = created_at
			latest_id = current_id
			continue

		if latest_created_at == "" and current_id >= latest_id:
			latest_token = current_token
			latest_id = current_id

	return latest_token

func _clear_previous_autofill_if_still_present() -> void:
	if last_autofill_age != "" and age_input.text.strip_edges() == last_autofill_age:
		age_input.text = ""
	if last_autofill_doctor_key != "" and doctor_key_input.text.strip_edges() == last_autofill_doctor_key:
		doctor_key_input.text = ""
	last_autofill_token = ""
	last_autofill_age = ""
	last_autofill_doctor_key = ""

func _apply_lookup_prefill(user_data: Dictionary, looked_up_token: String) -> void:
	var looked_up_age = _extract_user_age_from_lookup(user_data)
	var looked_up_doctor_key = _extract_latest_doctor_token_from_lookup(user_data)

	if looked_up_age != "":
		age_input.text = looked_up_age
	if looked_up_doctor_key != "":
		doctor_key_input.text = looked_up_doctor_key

	last_autofill_token = looked_up_token
	last_autofill_age = looked_up_age
	last_autofill_doctor_key = looked_up_doctor_key
	update_button()

func _maybe_prefill_user_fields() -> void:
	var token = token_input.text.strip_edges()
	if token == "" or token.to_lower() == "guest":
		pending_prefill_token = ""
		_clear_previous_autofill_if_still_present()
		return
	if token.length() < PREFILL_MIN_TOKEN_LENGTH:
		pending_prefill_token = ""
		_clear_previous_autofill_if_still_present()
		return
	if is_request_running or is_doctor_key_lookup or is_generating_token:
		return
	if is_prefill_lookup_in_progress or pending_prefill_token == token:
		return
	if last_autofill_token == token:
		return

	_clear_previous_autofill_if_still_present()
	_start_prefill_lookup(token)

func _start_prefill_lookup(token: String) -> void:
	pending_prefill_token = token
	pending_prefill_generation = token_input_generation
	_run_prefill_lookup(token, pending_prefill_generation)

func _on_token_input_focus_exited() -> void:
	_maybe_prefill_user_fields()

func _run_prefill_lookup(token: String, request_generation: int) -> void:
	var has_token = await GameManager.ensure_valid_access_token()
	if pending_prefill_token != token:
		return
	if request_generation != token_input_generation:
		return
	if not has_token:
		_log("User prefill auth unavailable")
		pending_prefill_token = ""
		return

	is_prefill_lookup_in_progress = true
	var headers = GameManager.get_api_headers()
	var err = prefill_http.request(
		BASE_URL + "user/?token=" + token,
		headers,
		HTTPClient.METHOD_GET
	)
	if err != OK:
		_log("User prefill lookup request failed immediately")
		is_prefill_lookup_in_progress = false
		pending_prefill_token = ""

func _on_prefill_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_prefill_lookup_in_progress = false
	var requested_token = pending_prefill_token
	var request_generation = pending_prefill_generation
	pending_prefill_token = ""
	pending_prefill_generation = 0
	var body_text = body.get_string_from_utf8()

	if token_input.text.strip_edges() != requested_token:
		return
	if request_generation != token_input_generation:
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_log("User prefill lookup failed | result=%s" % str(result))
		return

	if response_code == 404:
		return

	if response_code < 200 or response_code >= 300:
		_log("User prefill lookup failed | code=%s" % str(response_code))
		return

	var user_data = _extract_user_by_token(body_text, requested_token)
	if user_data.is_empty():
		_log("User prefill lookup returned no matching user")
		return

	_apply_lookup_prefill(user_data, requested_token)

func _merge_doctor_and_send_login(user_token: String, new_doctor_id: int) -> void:
	_log("Doctor merge lookup started")
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = REQUEST_TIMEOUT_SECONDS
	request.request_completed.connect(_on_existing_doctors_lookup_completed.bind(request, user_token, new_doctor_id))

	var has_token = await GameManager.ensure_valid_access_token()
	if not has_token:
		_log("Doctor merge lookup auth unavailable")
		if new_doctor_id >= 0:
			pending_login_data["medecins"] = [new_doctor_id]
		_send_login_request(pending_login_data)
		return

	var err = request.request(
		BASE_URL + "user/?token=" + user_token,
		GameManager.get_api_headers(),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		_log("Doctor merge lookup request failed immediately")
		if new_doctor_id >= 0:
			pending_login_data["medecins"] = [new_doctor_id]
		_send_login_request(pending_login_data)

func _on_existing_doctors_lookup_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_node: HTTPRequest, user_token: String, new_doctor_id: int) -> void:
	if is_instance_valid(request_node):
		request_node.queue_free()

	var body_text = body.get_string_from_utf8()
	pending_existing_medecins.clear()
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		pending_existing_medecins = _extract_user_by_token_medecins(body_text, user_token)
	else:
		_log("Doctor merge lookup failed | code=%s result=%s" % [str(response_code), str(result)])

	if new_doctor_id >= 0 and not pending_existing_medecins.has(new_doctor_id):
		pending_existing_medecins.append(new_doctor_id)

	if not pending_existing_medecins.is_empty():
		pending_login_data["medecins"] = pending_existing_medecins.duplicate()
		_log("Doctor merge result | medecins=%s" % str(pending_existing_medecins))

	_send_login_request(pending_login_data)

func _string_contains_any(text: String, needles: Array[String]) -> bool:
	var haystack = text.to_lower()
	for needle in needles:
		if haystack.find(needle) != -1:
			return true
	return false

func _is_doctor_not_found_error(response_code: int, body_text: String) -> bool:
	if not pending_login_data.has("medecin_key"):
		return false

	if response_code != 400 and response_code != 404:
		return false

	var doctor_terms: Array[String] = ["medecin", "doctor", "physician"]
	var missing_terms: Array[String] = ["not found", "does not exist", "n'existe", "introuvable", "invalid", "invalide"]

	var lowered_body = body_text.to_lower()
	if _string_contains_any(lowered_body, doctor_terms) and _string_contains_any(lowered_body, missing_terms):
		return true

	# Certains backends renvoient une erreur sur le nom du champ plutôt que dans le message.
	if _string_contains_any(lowered_body, ["medecin_key", "doctor_key", "token_medecin"]):
		return true

	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in ["medecin_key", "doctor_key", "token_medecin", "doctor", "medecin", "physician", "detail", "message", "error"]:
			if not parsed.has(key):
				continue
			var value_text = str(parsed[key]).to_lower()
			if _string_contains_any(value_text, doctor_terms) and _string_contains_any(value_text, missing_terms):
				return true
			if key in ["medecin_key", "doctor_key", "token_medecin", "doctor", "medecin", "physician"] and _string_contains_any(value_text, missing_terms):
				return true
			if key in ["medecin_key", "doctor_key", "token_medecin", "doctor", "medecin", "physician"]:
				return true

	# Fallback volontaire: si une clé médecin est fournie et que le backend renvoie 404,
	# on considère le médecin introuvable pour éviter le fallback offline silencieux.
	if response_code == 404:
		return true

	return false

func _clear_invalid_doctor_key(reason: String) -> void:
	doctor_key_input.text = ""
	pending_doctor_key = ""
	pending_doctor_id = -1
	pending_existing_medecins.clear()
	if pending_login_data.has("medecin_key"):
		pending_login_data.erase("medecin_key")
	if pending_login_data.has("medecin_id"):
		pending_login_data.erase("medecin_id")
	if pending_login_data.has("medecins"):
		pending_login_data.erase("medecins")
	if str(PlayerData.medecin_key).strip_edges() != "":
		PlayerData.medecin_key = ""
		GestionFichier.save_data()
	_log("Doctor key cleared | %s" % reason)

func _reset_doctor_lookup_state() -> void:
	is_request_running = false
	is_doctor_key_lookup = false
	pending_doctor_key = ""
	pending_doctor_id = -1
	pending_login_data.clear()

func _handle_doctor_lookup_blocked(status_message: String, log_message: String) -> void:
	status_label.text = status_message
	_log(log_message)
	_reset_doctor_lookup_state()

func _finalize_login_and_go_to_menu() -> void:
	PlayerData.print_data()
	GestionFichier.save_data()
	pending_login_data.clear()
	pending_doctor_id = -1
	pending_existing_medecins.clear()
	offline_generated_token_value = ""
	call_deferred("_go_to_menu")

# -------- LOGIN --------
func _on_save_button_pressed():
	if is_request_running:
		return

	var token = token_input.text.strip_edges()
	var age = age_input.text.strip_edges()
 
	if token == "" and age =="":
		status_label.text = "Champs requis"
		return
	if token == "":
		status_label.text = "Clé patient requise"
		return
	if age == "":
		status_label.text = "Age du patient requis"
		return

	if token.to_lower() == "guest":
		_on_guest_button_pressed()
		return

	if not is_valid_age(age):
		status_label.text = "Age invalide"
		return

	is_guest_mode = false

	var uuid = get_device_uuid()

	var data = {
		"token": token,
		"uuid": uuid,
		"age": int(age)
	}
	data["medecin_key"] = doctor_key_input.text.strip_edges()
	data["token_generated_offline"] = (offline_generated_token_value != "" and token == offline_generated_token_value)
	if data["medecin_key"] == "":
		data.erase("medecin_key")

	pending_login_data = data.duplicate(true)

	is_request_running = true
	if data.has("medecin_key"):
		_log("Doctor key verification started")
		pending_doctor_key = str(data.get("medecin_key", "")).strip_edges()
		pending_doctor_id = -1
		is_doctor_key_lookup = true
		status_label.text = "Vérification médecin..."
		var has_token = await GameManager.ensure_valid_access_token()
		if not has_token:
			_handle_doctor_lookup_blocked(
				"Impossible de vérifier la clé médecin",
				"Doctor key auth bootstrap/refresh failed, login blocked"
			)
			return
		var check_err = http.request(
			BASE_URL + DOCTOR_LOOKUP_PATH + pending_doctor_key,
			GameManager.get_api_headers(),
			HTTPClient.METHOD_GET
		)
		if check_err != OK:
			_handle_doctor_lookup_blocked(
				"Impossible de vérifier la clé médecin",
				"Doctor key check request failed immediately, login blocked"
			)
	else:
		_send_login_request(data)

# -------- GUEST --------
func _on_guest_button_pressed():
	if is_request_running:
		return

	is_guest_mode = true
	offline_generated_token_value = ""

	token_input.text = "guest"
	age_input.text = ""
	age_input.editable = false

	var data = {
		"token": "guest",
		"age": null
	}
	data["token_generated_offline"] = false

	pending_login_data = data.duplicate(true)

	is_request_running = true
	status_label.text = "Mode invité..."
	_log("Sending guest login request")
	var has_token = await GameManager.ensure_valid_access_token()
	if not has_token:
		_log("API auth unavailable for guest login, fallback to offline login")
		_offline_login(data)
		return

	var err = http.request(
		BASE_URL + "user/",
		GameManager.get_json_post_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(_build_user_request_payload(data))
	)

	if err != OK:
		_log("Immediate guest request error, fallback to offline login")
		_offline_login(data)

func _send_login_request(data: Dictionary) -> void:
	is_request_running = true
	status_label.text = "Connexion..."
	var payload = _build_user_request_payload(data)
	_log("Sending /api/user/ login request")
	var has_token = await GameManager.ensure_valid_access_token()
	if not has_token:
		_log("API auth unavailable for login, fallback to offline login")
		_offline_login(data)
		return
	var err = http.request(
		BASE_URL + "user/",
		GameManager.get_json_post_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		_log("Immediate login request error, fallback to offline login")
		_offline_login(data)

# -------- HTTP RESPONSE --------
func _on_http_request_request_completed(result, response_code, _headers, body):
	is_request_running = false

	if is_generating_token:
		is_generating_token = false

		if result != HTTPRequest.RESULT_SUCCESS:
			_log("Token generation HTTP failure, fallback offline")
			_generate_token_offline()
			return

		if response_code != 404 and (response_code < 200 or response_code >= 300):
			_log("Token check returned code %s, fallback offline" % str(response_code))
			_generate_token_offline()
			return

		var body_text = body.get_string_from_utf8()
		if _is_token_available(response_code, body_text):
			token_input.text = generated_token
			_clear_fields_for_generated_token()
			offline_generated_token_value = ""
			status_label.text = "Token généré ✔"
			_log("Token generation success")
			set_ui_locked(false)  
		else:
			_try_generate_token()

		return

	if is_doctor_key_lookup:
		is_doctor_key_lookup = false
		var doctor_key = pending_doctor_key
		pending_doctor_key = ""
		pending_doctor_id = -1
		var doctor_body_text = body.get_string_from_utf8()

		if result != HTTPRequest.RESULT_SUCCESS:
			status_label.text = "Impossible de vérifier la clé médecin"
			_log("Doctor key lookup network failure, login blocked")
			_reset_doctor_lookup_state()
			return

		if response_code == 404:
			status_label.text = "Le médecin n'existe pas"
			_log("Doctor key lookup failed: key not found")
			_clear_invalid_doctor_key("lookup 404")
			_reset_doctor_lookup_state()
			return

		if response_code < 200 or response_code >= 300:
			status_label.text = "Impossible de vérifier la clé médecin"
			_log("Doctor key lookup failed with code=%s, login blocked" % str(response_code))
			_reset_doctor_lookup_state()
			return

		var doctor_found = _is_lookup_token_found(response_code, doctor_body_text, doctor_key)
		if not doctor_found:
			status_label.text = "Le médecin n'existe pas"
			_log("Doctor key lookup returned no matching token")
			_clear_invalid_doctor_key("lookup no matching token")
			_reset_doctor_lookup_state()
			return

		var doctor_id = _extract_lookup_doctor_id(response_code, doctor_body_text, doctor_key)
		if doctor_id >= 0:
			pending_doctor_id = doctor_id
			pending_login_data["medecin_id"] = doctor_id
			_log("Doctor key validated | medecin_id=%s" % str(doctor_id))

		var login_token = str(pending_login_data.get("token", "")).strip_edges()
		if doctor_id >= 0 and login_token != "" and login_token.to_lower() != "guest":
			_merge_doctor_and_send_login(login_token, doctor_id)
			return

		_send_login_request(pending_login_data)
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_log("Login HTTP failure, fallback offline")
		_offline_login(pending_login_data)
		return

	var body_text = body.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		_log("Login non-2xx response | code=%s | body=%s" % [str(response_code), body_text])

	if _is_doctor_not_found_error(response_code, body_text):
		status_label.text = "Le médecin n'existe pas"
		_log("Doctor key rejected by backend (not found)")
		_clear_invalid_doctor_key("backend rejected key")
		pending_login_data.clear()
		return

	if response_code != 200 and response_code != 201:
		_log("Login rejected (code=%s), fallback offline" % str(response_code))
		_offline_login(pending_login_data)
		return

	var response = JSON.parse_string(body_text)

	if typeof(response) != TYPE_DICTIONARY or not response.has("id"):
		_log("Invalid login response payload, fallback offline")
		_offline_login(pending_login_data)
		return

	var user_id = int(response["id"])
	_log("Login success | user_id=%s" % str(user_id))

	if is_guest_mode:
		PlayerData.set_guest(user_id)
		PlayerData.token = "guest"
		PlayerData.uuid = "none"
		PlayerData.age = ""
		PlayerData.medecin_key = ""
	else:
		var resolved_uuid = str(response.get("uuid", pending_login_data.get("uuid", get_device_uuid())))

		var age = pending_login_data.get("age", "")
		if str(age).is_valid_int():
			age = int(age)

		PlayerData.set_user(
			user_id,
			resolved_uuid,
			str(pending_login_data.get("token")),
			age,
			str(pending_login_data.get("medecin_key", ""))
		)

		PlayerData.age = age

	_finalize_login_and_go_to_menu()

# -------- OFFLINE --------
func _offline_login(data):
	_log("Offline login mode enabled")
	var local_id = 1 if is_guest_mode else -1

	if is_guest_mode:
		data["age"] = null
		data.erase("medecin_key")
		PlayerData.set_guest(local_id)
		PlayerData.age = ""
	else:
		var age = data.get("age", "")
		if str(age).is_valid_int():
			age = int(age)

		PlayerData.set_user(
			local_id,
			str(data.get("uuid", get_device_uuid())),
			data["token"],
			age,
			str(data.get("medecin_key", ""))
		)

		PlayerData.age = age
	SyncManager.add_action({
		"type": "login",
		"data": data
	})
	_log("Offline login queued for sync")

	status_label.text = "Mode hors ligne"

	_finalize_login_and_go_to_menu()

# -------- NAV --------
func _go_to_menu():
	var interface = get_tree().get_meta("interface")

	if interface:
		interface.show_menu()

func _on_back_button_pressed():
	if first_login:
		return
	
	get_tree().get_meta("interface").show_menu()

# -------- INPUT AGE --------
func _on_age_input_text_changed(new_text: String) -> void:
	if is_guest_mode:
		age_input.text = ""
		return

	var filtered = ""
	for c in new_text:
		if c.is_valid_int():
			filtered += c

	if filtered != new_text:
		age_input.text = filtered

	update_button()


func _on_doctor_token_input_text_changed(new_text: String) -> void:
	if is_guest_mode:
		doctor_key_input.text = ""
		return

	var sanitized = new_text.strip_edges()
	if sanitized != new_text:
		doctor_key_input.text = sanitized
		return

	update_button()
