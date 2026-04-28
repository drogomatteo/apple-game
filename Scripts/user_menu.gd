extends Control

const LOG_TAG := "[UserMenu]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

# -------- NODES --------
@onready var http = $HTTPRequest
@onready var existing_key_label = $MarginContainer/fond/MarginContainer/VBoxContainer/jaiuncompte
@onready var token_input = $MarginContainer/fond/MarginContainer/VBoxContainer/CleBox/TokenInput
@onready var birth_year_input = $MarginContainer/fond/MarginContainer/VBoxContainer/BirthYearBox/BirthYearInput
@onready var doctor_key_input = $MarginContainer/fond/MarginContainer/VBoxContainer/MedecinBox/DoctorKeyInput
@onready var save_button = $MarginContainer/fond/MarginContainer/VBoxContainer/CreerOuCo/SaveButton
@onready var deco_button = $MarginContainer/fond/MarginContainer/VBoxContainer/LogoutButton
@onready var guest_button = $MarginContainer/fond/MarginContainer/VBoxContainer/CreerOuCo/GuestButton
@onready var status_label = $MarginContainer/fond/MarginContainer/VBoxContainer/StatusLabel
@onready var generate_button = $MarginContainer/fond/MarginContainer/VBoxContainer/CleBox/GenerateTokenButton
@onready var back_button = $BackButton

# -------- CONFIG --------
var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"
const DOCTOR_LOOKUP_PATH := "doctor/?token="
const REQUEST_TIMEOUT_SECONDS := 5.0
const TOKEN_LENGTH := 8
const MAX_TOKEN_GENERATION_ATTEMPTS := 20
const PREFILL_MIN_TOKEN_LENGTH := 1
const MAX_BIRTH_YEAR_AGE := 110
const MIN_BIRTH_YEAR_AGE := 6
const RESERVED_PATIENT_TOKENS := ["guest", "invite", "invité"]
const EXISTING_KEY_NORMAL_TEXT := "J'ai déjà une clé patient :"
const GENERATE_KEY_NORMAL_TEXT := "Je n'ai pas encore de clé patient :"
const GENERATE_BUTTON_NORMAL_TEXT := "Aléatoire"
const EXISTING_KEY_GUEST_TEXT := "Créez votre clé :"
const GENERATE_KEY_GUEST_TEXT := "Générez votre clé :"
const GENERATE_BUTTON_GUEST_TEXT := "Aléatoire"

# -------- STATE --------
var is_request_running = false
var pending_login_data : Dictionary = {}
var first_login := false

var is_user_token_lookup = false
var is_doctor_key_lookup = false
var pending_doctor_key = ""
var pending_doctor_id := -1
var pending_existing_doctors: Array[int] = []
var prefill_http := HTTPRequest.new()
var is_prefill_lookup_in_progress := false
var pending_prefill_token := ""
var pending_prefill_generation := 0
var token_input_generation := 0
var last_autofill_token := ""
var last_autofill_birth_year := ""
var last_autofill_doctor_key := ""
var is_generating_token = false
var generated_token = ""
var token_generation_attempts := 0
var generated_patient_token_value := ""
var offline_generated_token_value := ""

# -------- SHARED HELPERS --------
func _get_interface():
	return get_tree().get_meta("interface")

# -------- LIFECYCLE --------
func _ready():
	randomize()
	http.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(prefill_http)
	prefill_http.timeout = REQUEST_TIMEOUT_SECONDS
	prefill_http.request_completed.connect(_on_prefill_request_completed)
	token_input.focus_exited.connect(_on_token_input_focus_exited)
	token_input.focus_entered.connect(_on_token_input_focus_entered)

	if first_login:
		back_button.visible = false
		back_button.disabled = true
	else:
		back_button.visible = true
		back_button.disabled = false

	if PlayerData.user_id != -1:
		token_input.text = PlayerData.token
		birth_year_input.text = str(PlayerData.birth_year)
		doctor_key_input.text = PlayerData.doctor_key

	_sync_guest_creation_controls()
	_update_button()
	_show_pending_token_update_notice()

func _show_pending_token_update_notice() -> void:
	if not PlayerData.token_update_pending:
		return
	if PlayerData.updated_token == "":
		return

	status_label.text = "Identifiant mis à jour : " + PlayerData.updated_token
	PlayerData.token_update_pending = false
	PlayerData.previous_token = ""
	PlayerData.updated_token = ""
	GestionFichier.save_data()

# -------- UI HELPERS --------
func _on_token_input_text_changed(_text=""):
	token_input_generation += 1
	if offline_generated_token_value != "" and token_input.text.strip_edges() != offline_generated_token_value:
		offline_generated_token_value = ""
	if generated_patient_token_value != "" and token_input.text.strip_edges() != generated_patient_token_value:
		generated_patient_token_value = ""

	_clear_fields_after_patient_token_input()
	_clear_previous_autofill_if_still_present()
	_sync_guest_creation_controls()

	_update_button()

func _on_input_changed(_text=""):
	_update_button()

func _on_token_input_focus_entered() -> void:
	_clear_fields_after_patient_token_input()
	_clear_previous_autofill_if_still_present()
	_sync_guest_creation_controls()
	_update_button()

func _update_button():
	var token = token_input.text.strip_edges()
	var birth_year = birth_year_input.text.strip_edges()

	save_button.disabled = false

	if token != "" and not _is_reserved_patient_token(token) and _is_valid_birth_year(birth_year):
		status_label.text = ""

func _get_device_uuid() -> String:
	return OS.get_unique_id()

func _is_reserved_patient_token(token: String) -> bool:
	return RESERVED_PATIENT_TOKENS.has(token.strip_edges().to_lower())

func _is_valid_birth_year(birth_year_text: String) -> bool:
	if birth_year_text == "":
		return false
	for c in birth_year_text:
		if not c.is_valid_int():
			return false

	var birth_year = int(birth_year_text)
	var current_year = int(Time.get_datetime_dict_from_system()["year"])
	return birth_year >= current_year - MAX_BIRTH_YEAR_AGE and birth_year <= current_year - MIN_BIRTH_YEAR_AGE

func _get_birth_year_range_text() -> String:
	var current_year = int(Time.get_datetime_dict_from_system()["year"])
	return "%s et %s" % [str(current_year - MAX_BIRTH_YEAR_AGE), str(current_year -  MIN_BIRTH_YEAR_AGE)]

# -------- FORM HELPERS --------
func _set_ui_locked(locked: bool) -> void:
	save_button.disabled = locked
	guest_button.disabled = false
	back_button.disabled = locked or first_login
	token_input.editable = not locked
	birth_year_input.editable = not locked
	doctor_key_input.editable = not locked and not _should_lock_doctor_key()
	generate_button.disabled = false
	if not locked:
		_sync_guest_creation_controls()
		_update_button()

func _should_lock_doctor_key() -> bool:
	return false

func _set_doctor_key_locked(locked: bool) -> void:
	if locked:
		doctor_key_input.text = ""
	doctor_key_input.editable = not locked
	doctor_key_input.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	if locked and doctor_key_input.has_focus():
		doctor_key_input.release_focus()

func _sync_guest_creation_controls() -> void:
	guest_button.disabled = false
	generate_button.disabled = false
	generate_button.text = GENERATE_BUTTON_NORMAL_TEXT
	_set_doctor_key_locked(false)

# -------- TOKEN HELPERS --------
func _generate_token() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var token = ""
	for i in range(TOKEN_LENGTH):
		token += chars[randi() % chars.length()]
	return token

func _clear_fields_for_generated_token() -> void:
	birth_year_input.text = ""
	doctor_key_input.text = ""
	generated_patient_token_value = ""
	pending_prefill_token = ""
	pending_prefill_generation = 0
	_clear_previous_autofill_if_still_present()
	_sync_guest_creation_controls()
	_update_button()

func _on_generate_token_button_pressed() -> void:
	_log("Token generation requested")
	token_generation_attempts = 0
	_clear_fields_for_generated_token()
	status_label.text = "Génération..."
	_set_ui_locked(true)
	_try_generate_token()

func _try_generate_token():
	token_generation_attempts += 1
	if token_generation_attempts > MAX_TOKEN_GENERATION_ATTEMPTS:
		is_generating_token = false
		is_request_running = false
		_set_general_error("Impossible de générer un identifiant")
		_log("Token generation failed after max attempts")
		_set_ui_locked(false)
		return

	generated_token = _generate_token()
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
	if current_player_token != "":
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
		var candidate = _generate_token()
		if reserved_tokens.has(candidate):
			continue

		token_input.text = candidate
		_clear_fields_for_generated_token()
		generated_patient_token_value = candidate
		offline_generated_token_value = candidate
		status_label.text = "Identifiant généré hors ligne (vérification à la prochaine connection)"
		_set_ui_locked(false)
		return

	_set_general_error("Impossible de générer une clé patient")
	_log("Offline token generation failed")
	_set_ui_locked(false)

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
	var doctors = data.get("doctors", data.get("medecins", null))
	if typeof(doctors) == TYPE_ARRAY:
		payload["doctors"] = doctors

	return payload

func _extract_doctor_ids_array(raw_value) -> Array[int]:
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

func _extract_user_by_token_doctors(body_text: String, token_to_find: String) -> Array[int]:
	var parsed = JSON.parse_string(body_text)
	var target = _find_user_by_token_in_parsed_response(parsed, token_to_find)

	if target.is_empty():
		return []

	return _extract_doctor_ids_array(target.get("doctors", target.get("medecins", [])))

func _extract_user_by_token(body_text: String, token_to_find: String) -> Dictionary:
	var parsed = JSON.parse_string(body_text)
	return _find_user_by_token_in_parsed_response(parsed, token_to_find)

func _extract_user_birth_year_from_lookup(user_data: Dictionary) -> String:
	for key in ["birth_year", "user_birth_year", "patient_birth_year", "patientBirthYear", "userBirthYear"]:
		var raw_value = user_data.get(key, null)
		if raw_value == null:
			continue
		if typeof(raw_value) == TYPE_INT:
			return str(int(raw_value))
		if typeof(raw_value) == TYPE_FLOAT:
			var birth_year_float = float(raw_value)
			if is_equal_approx(birth_year_float, floor(birth_year_float)):
				return str(int(birth_year_float))
			continue

		var birth_year_text = str(raw_value).strip_edges()
		if birth_year_text == "" or birth_year_text == "null":
			continue
		if birth_year_text.is_valid_int():
			return str(int(birth_year_text))
	return ""

func _extract_doctor_token_from_entry(entry: Dictionary) -> String:
	for key in ["token", "doctor_key", "doctor_token", "medecin_key", "token_medecin", "medecin_token"]:
		var value = str(entry.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""

func _extract_latest_doctor_token_from_lookup(user_data: Dictionary) -> String:
	for key in ["doctor_key", "latest_doctor_token", "doctor_token", "medecin_key", "token_medecin", "latest_medecin_token", "medecin_token"]:
		var direct_value = str(user_data.get(key, "")).strip_edges()
		if direct_value != "":
			return direct_value

	var doctors = user_data.get("doctors", user_data.get("medecins", []))
	if typeof(doctors) != TYPE_ARRAY:
		return ""

	var latest_token := ""
	var latest_created_at := ""
	var latest_id := -1

	for item in doctors:
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
	if last_autofill_birth_year != "" and birth_year_input.text.strip_edges() == last_autofill_birth_year:
		birth_year_input.text = ""
	if last_autofill_doctor_key != "" and doctor_key_input.text.strip_edges() == last_autofill_doctor_key:
		doctor_key_input.text = ""
	last_autofill_token = ""
	last_autofill_birth_year = ""
	last_autofill_doctor_key = ""

func _clear_login_fields() -> void:
	token_input.text = ""
	birth_year_input.text = ""
	doctor_key_input.text = ""
	generated_patient_token_value = ""
	offline_generated_token_value = ""
	pending_prefill_token = ""
	pending_prefill_generation = 0
	_clear_previous_autofill_if_still_present()
	_sync_guest_creation_controls()
	_update_button()

func _clear_fields_after_patient_token_input() -> void:
	pending_prefill_token = ""
	pending_prefill_generation = 0

func _set_general_error(message: String) -> void:
	pending_login_data.clear()
	generated_patient_token_value = ""
	offline_generated_token_value = ""
	pending_prefill_token = ""
	pending_prefill_generation = 0
	_clear_previous_autofill_if_still_present()
	_sync_guest_creation_controls()
	_update_button()
	status_label.text = message

func _apply_lookup_prefill(user_data: Dictionary, looked_up_token: String) -> void:
	var looked_up_birth_year = _extract_user_birth_year_from_lookup(user_data)
	var looked_up_doctor_key = _extract_latest_doctor_token_from_lookup(user_data)

	if looked_up_birth_year != "":
		birth_year_input.text = looked_up_birth_year
	if looked_up_doctor_key != "" and not _should_lock_doctor_key():
		doctor_key_input.text = looked_up_doctor_key

	last_autofill_token = looked_up_token
	last_autofill_birth_year = looked_up_birth_year
	last_autofill_doctor_key = looked_up_doctor_key
	_update_button()

func _maybe_prefill_user_fields() -> void:
	var token = token_input.text.strip_edges()
	if token == "" or _is_reserved_patient_token(token):
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
			pending_login_data["doctors"] = [new_doctor_id]
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
			pending_login_data["doctors"] = [new_doctor_id]
		_send_login_request(pending_login_data)

func _on_existing_doctors_lookup_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_node: HTTPRequest, user_token: String, new_doctor_id: int) -> void:
	if is_instance_valid(request_node):
		request_node.queue_free()

	var body_text = body.get_string_from_utf8()
	pending_existing_doctors.clear()
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		pending_existing_doctors = _extract_user_by_token_doctors(body_text, user_token)
	else:
		_log("Doctor merge lookup failed | code=%s result=%s" % [str(response_code), str(result)])

	if new_doctor_id >= 0 and not pending_existing_doctors.has(new_doctor_id):
		pending_existing_doctors.append(new_doctor_id)

	if not pending_existing_doctors.is_empty():
		pending_login_data["doctors"] = pending_existing_doctors.duplicate()
		_log("Doctor merge result | doctors=%s" % str(pending_existing_doctors))

	_send_login_request(pending_login_data)

func _string_contains_any(text: String, needles: Array[String]) -> bool:
	var haystack = text.to_lower()
	for needle in needles:
		if haystack.find(needle) != -1:
			return true
	return false

func _is_doctor_not_found_error(response_code: int, body_text: String) -> bool:
	if not pending_login_data.has("doctor_key") and not pending_login_data.has("medecin_key"):
		return false

	if response_code != 400 and response_code != 404:
		return false

	var doctor_terms: Array[String] = ["doctor", "physician", "medecin"]
	var missing_terms: Array[String] = ["not found", "does not exist", "n'existe", "introuvable", "invalid", "invalide"]

	var lowered_body = body_text.to_lower()
	if _string_contains_any(lowered_body, doctor_terms) and _string_contains_any(lowered_body, missing_terms):
		return true

	# Certains backends renvoient une erreur sur le nom du champ plutôt que dans le message.
	if _string_contains_any(lowered_body, ["doctor_key", "token_medecin", "medecin_key"]):
		return true

	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in ["doctor_key", "token_medecin", "medecin_key", "doctor", "medecin", "physician", "detail", "message", "error"]:
			if not parsed.has(key):
				continue
			var value_text = str(parsed[key]).to_lower()
			if _string_contains_any(value_text, doctor_terms) and _string_contains_any(value_text, missing_terms):
				return true
			if key in ["doctor_key", "token_medecin", "medecin_key", "doctor", "medecin", "physician"] and _string_contains_any(value_text, missing_terms):
				return true
			if key in ["doctor_key", "token_medecin", "medecin_key", "doctor", "medecin", "physician"]:
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
	pending_existing_doctors.clear()
	if pending_login_data.has("doctor_key"):
		pending_login_data.erase("doctor_key")
	if pending_login_data.has("doctor_id"):
		pending_login_data.erase("doctor_id")
	if pending_login_data.has("doctors"):
		pending_login_data.erase("doctors")
	if str(PlayerData.doctor_key).strip_edges() != "":
		PlayerData.doctor_key = ""
		GestionFichier.save_data()
	_log("Doctor key cleared | %s" % reason)

func _reset_doctor_lookup_state() -> void:
	is_request_running = false
	is_user_token_lookup = false
	is_doctor_key_lookup = false
	pending_doctor_key = ""
	pending_doctor_id = -1
	pending_login_data.clear()

func _handle_doctor_lookup_blocked(status_message: String, log_message: String) -> void:
	if log_message.find("login blocked") != -1:
		_fallback_doctor_lookup_to_offline(log_message.replace("login blocked", "fallback to offline login"))
		return
	status_label.text = status_message
	_log(log_message)
	_reset_doctor_lookup_state()

func _fallback_doctor_lookup_to_offline(log_message: String) -> void:
	_log(log_message)
	status_label.text = "Mode hors ligne"
	is_request_running = false
	is_user_token_lookup = false
	is_doctor_key_lookup = false
	pending_doctor_key = ""
	pending_doctor_id = -1
	_offline_login(pending_login_data)

func _finalize_login_and_go_to_menu() -> void:
	PlayerData.print_data()
	GestionFichier.save_data()
	pending_login_data.clear()
	pending_doctor_id = -1
	pending_existing_doctors.clear()
	offline_generated_token_value = ""
	generated_patient_token_value = ""
	call_deferred("_go_to_menu")

func _can_create_missing_user_from_token(_token: String) -> bool:
	return bool(pending_login_data.get("guest_created", false))

func _handle_user_token_not_found() -> void:
	_log("User token lookup returned no matching user")
	var token = str(pending_login_data.get("token", "")).strip_edges()
	if _can_create_missing_user_from_token(token):
		_send_login_request(pending_login_data)
		return

	is_request_running = false
	is_user_token_lookup = false
	pending_login_data.clear()
	_set_general_error("L'utilisateur n'existe pas")

func _handle_user_token_lookup_blocked(log_message: String) -> void:
	_log(log_message)
	is_request_running = false
	is_user_token_lookup = false
	pending_login_data.clear()
	_set_general_error("Impossible de vérifier l'utilisateur")
	_sync_guest_creation_controls()

func _handle_guest_creation_token_exists() -> void:
	_log("Guest creation blocked: token already exists")
	is_request_running = false
	is_user_token_lookup = false
	pending_login_data.clear()
	offline_generated_token_value = ""
	_set_general_error("Cet identifiant existe déjà, choisissez en un autre")
	_sync_guest_creation_controls()


func _handle_guest_creation_failed(log_message: String, status_message := "Impossible de créer l'utilisateur") -> void:
	_log(log_message)
	is_request_running = false
	is_user_token_lookup = false
	is_doctor_key_lookup = false
	pending_doctor_key = ""
	pending_doctor_id = -1
	pending_login_data.clear()
	_set_general_error(status_message)
	_sync_guest_creation_controls()

func _start_user_token_lookup(token: String) -> void:
	is_user_token_lookup = true
	status_label.text = "Vérification utilisateur..."
	var has_token = await GameManager.ensure_valid_access_token()
	if not has_token:
		_handle_user_token_lookup_blocked("User token lookup auth unavailable")
		return

	var err = http.request(
		BASE_URL + "user/?token=" + token,
		GameManager.get_api_headers(),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		_handle_user_token_lookup_blocked("User token lookup request failed immediately")

func _continue_login_after_user_token_verified() -> void:
	is_request_running = true

	if bool(pending_login_data.get("guest_created", false)):
		_handle_guest_creation_token_exists()
		return

	if pending_login_data.has("doctor_key"):
		_log("Doctor key verification started")
		pending_doctor_key = str(pending_login_data.get("doctor_key", "")).strip_edges()
		pending_doctor_id = -1
		is_doctor_key_lookup = true
		status_label.text = "Vérification médecin..."
		var has_token = await GameManager.ensure_valid_access_token()
		if not has_token:
			_handle_doctor_lookup_blocked(
				"Impossible de vérifier l'identifiant du médecin",
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
				"Impossible de vérifier l'identifiant du médecin",
				"Doctor key check request failed immediately, login blocked"
			)
	else:
		_send_login_request(pending_login_data)
	
	
# -------- LOGIN --------
func _on_save_button_pressed():
	if is_request_running:
		return

	var token = token_input.text.strip_edges()
	var birth_year = birth_year_input.text.strip_edges()
	var doctor_key = doctor_key_input.text.strip_edges()

	if token == "" and birth_year == "":
		status_label.text = "Identifiant et année de naissance requis"
		return
	if token == "":
		status_label.text = "Identifiant requis"
		return

	if _is_reserved_patient_token(token):
		_set_general_error("Cet identifiant est invalide")
		return

	if birth_year == "":
		status_label.text = "Année de naissance requise"
		return

	if not _is_valid_birth_year(birth_year):
		status_label.text = "L'année de naissance doit être comprise entre " + _get_birth_year_range_text()
		return

	var uuid = _get_device_uuid()

	var data = {
		"token": token,
		"uuid": uuid,
		"birth_year": int(birth_year)
	}

	if doctor_key != "":
		data["doctor_key"] = doctor_key

	data["token_generated_offline"] = false

	pending_login_data = data.duplicate(true)

	is_request_running = true
	status_label.text = "Connexion..."

	_start_user_token_lookup(token)
	
	
func _send_login_request(data: Dictionary) -> void:
	is_request_running = true
	status_label.text = "Connexion..."
	var payload = _build_user_request_payload(data)
	_log("Sending /api/user/ login request")
	var has_token = await GameManager.ensure_valid_access_token()
	if not has_token:
		if bool(data.get("guest_created", false)):
			_handle_guest_creation_failed("API auth unavailable for guest creation")
		else:
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
		if bool(data.get("guest_created", false)):
			_handle_guest_creation_failed("Immediate guest creation request error")
		else:
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

		var token_body_text = body.get_string_from_utf8()
		if _is_token_available(response_code, token_body_text):
			token_input.text = generated_token
			_clear_fields_for_generated_token()
			generated_patient_token_value = generated_token
			offline_generated_token_value = ""
			status_label.text = "Identifiant généré ✔"
			_log("Token generation success")
			_set_ui_locked(false)  
		else:
			_try_generate_token()

		return

	if is_user_token_lookup:
		is_user_token_lookup = false
		var lookup_token = str(pending_login_data.get("token", "")).strip_edges()
		var user_body_text = body.get_string_from_utf8()

		if result != HTTPRequest.RESULT_SUCCESS:
			_handle_user_token_lookup_blocked("User token lookup failed | result=%s" % str(result))
			return

		if response_code != 404 and (response_code < 200 or response_code >= 300):
			_handle_user_token_lookup_blocked("User token lookup failed | code=%s" % str(response_code))
			return

		if not _is_lookup_token_found(response_code, user_body_text, lookup_token):
			_handle_user_token_not_found()
			return

		_continue_login_after_user_token_verified()
		return

	if is_doctor_key_lookup:
		is_doctor_key_lookup = false
		var doctor_key = pending_doctor_key
		pending_doctor_key = ""
		pending_doctor_id = -1
		var doctor_body_text = body.get_string_from_utf8()

		if result != HTTPRequest.RESULT_SUCCESS:
			status_label.text = "Impossible de vérifier l'identifiant du médecin"
			_fallback_doctor_lookup_to_offline("Doctor key lookup network failure, fallback to offline login")
			return

		if response_code == 404:
			status_label.text = "Le médecin n'existe pas"
			_log("Doctor key lookup failed: key not found")
			_clear_invalid_doctor_key("lookup 404")
			_reset_doctor_lookup_state()
			return

		if response_code < 200 or response_code >= 300:
			status_label.text = "Impossible de vérifier l'identifiant du médecin"
			_fallback_doctor_lookup_to_offline("Doctor key lookup failed with code=%s, fallback to offline login" % str(response_code))
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
			pending_login_data["doctor_id"] = doctor_id
			_log("Doctor key validated | doctor_id=%s" % str(doctor_id))

		var login_token = str(pending_login_data.get("token", "")).strip_edges()
		if doctor_id >= 0 and login_token != "":
			_merge_doctor_and_send_login(login_token, doctor_id)
			return

		_send_login_request(pending_login_data)
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		if bool(pending_login_data.get("guest_created", false)):
			_handle_guest_creation_failed("Guest creation HTTP failure")
		else:
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
		if bool(pending_login_data.get("guest_created", false)):
			_handle_guest_creation_failed("Guest creation rejected | code=%s" % str(response_code))
		else:
			_log("Login rejected (code=%s), fallback offline" % str(response_code))
			_offline_login(pending_login_data)
		return

	var response = JSON.parse_string(body_text)

	if typeof(response) != TYPE_DICTIONARY or not response.has("id"):
		if bool(pending_login_data.get("guest_created", false)):
			_handle_guest_creation_failed("Invalid guest creation response payload")
		else:
			_log("Invalid login response payload, fallback offline")
			_offline_login(pending_login_data)
		return

	var user_id = int(response["id"])
	_log("Login success | user_id=%s" % str(user_id))

	var resolved_uuid = str(response.get("uuid", pending_login_data.get("uuid", _get_device_uuid())))

	var birth_year = pending_login_data.get("birth_year", "")
	if str(birth_year).is_valid_int():
		birth_year = int(birth_year)

	PlayerData.set_user(
		user_id,
		resolved_uuid,
		str(pending_login_data.get("token")),
		birth_year,
		str(pending_login_data.get("doctor_key", pending_login_data.get("medecin_key", "")))
	)

	PlayerData.birth_year = birth_year

	_finalize_login_and_go_to_menu()

# -------- OFFLINE --------
func _offline_login(data):
	_log("Offline login mode enabled")
	var local_id = -2
	var birth_year = data.get("birth_year", "")
	if str(birth_year).is_valid_int():
		birth_year = int(birth_year)

	PlayerData.set_user(
		local_id,
		str(data.get("uuid", _get_device_uuid())),
		data["token"],
		birth_year,
		str(data.get("doctor_key", data.get("medecin_key", "")))
	)

	PlayerData.birth_year = birth_year
	SyncManager.add_action({
		"type": "login",
		"data": data
	})
	_log("Offline login queued for sync")

	status_label.text = "Mode hors ligne"

	_finalize_login_and_go_to_menu()

# -------- NAV --------
func _go_to_menu():
	var interface = _get_interface()
	if interface:
		interface.show_menu()

# -------- BUTTON CALLBACKS --------
func _on_back_button_pressed():
	if first_login:
		return
	
	_get_interface().show_menu()

func _on_guest_button_pressed() -> void:
	if is_request_running:
		return

	var token = token_input.text.strip_edges()
	var birth_year = birth_year_input.text.strip_edges()
	var doctor_key = doctor_key_input.text.strip_edges()

	if token == "" and birth_year == "":
		status_label.text = "Identifiant et année de naissance requis"
		return

	if token == "":
		status_label.text = "Identifiant requis"
		return

	if _is_reserved_patient_token(token):
		_set_general_error("Cet identifiant est invalide")
		return

	if birth_year == "":
		status_label.text = "Année de naissance requise"
		return

	if not _is_valid_birth_year(birth_year):
		status_label.text = "L'année de naissance doit être comprise entre " + _get_birth_year_range_text()
		return

	var uuid = _get_device_uuid()

	var data = {
		"token": token,
		"uuid": uuid,
		"birth_year": int(birth_year),
		"guest_created": true
	}

	if doctor_key != "":
		data["doctor_key"] = doctor_key

	data["token_generated_offline"] = (offline_generated_token_value != "" and token == offline_generated_token_value)

	pending_login_data = data.duplicate(true)

	is_request_running = true
	status_label.text = "Création du compte..."

	_start_user_token_lookup(token)
	
	
# -------- INPUT CALLBACKS --------
func _on_birth_year_input_text_changed(new_text: String) -> void:
	var filtered = ""
	for c in new_text:
		if c.is_valid_int():
			filtered += c

	if filtered != new_text:
		birth_year_input.text = filtered

	_update_button()

func _on_doctor_token_input_text_changed(new_text: String) -> void:
	var sanitized = new_text.strip_edges()
	if sanitized != new_text:
		doctor_key_input.text = sanitized
		return

	_update_button()

func _on_logout_button_pressed() -> void:
	PlayerData.logout_user()
	SaveRgpd.set_accepted(false, true)
	GestionFichier.save_data()

	var interface = _get_interface()
	if interface:
		interface.first_login_flow = true
		interface.show_gdpr()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")
