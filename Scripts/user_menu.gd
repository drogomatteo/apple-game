extends Control

# -------- NODES --------
@onready var http = $HTTPRequest
@onready var existing_key_label = $MarginContainer/fond/MarginContainer/VBoxContainer/jaiuncompte
@onready var token_input = $MarginContainer/fond/MarginContainer/VBoxContainer/CleBox/TokenInput
@onready var birth_year_input = $MarginContainer/fond/MarginContainer/VBoxContainer/BirthYearBox/BirthYearInput
@onready var doctor_token_input = $MarginContainer/fond/MarginContainer/VBoxContainer/DoctorTokenBox/DoctorTokenInput
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
const BIRTH_YEAR_KEYS := ["birth_year", "user_birth_year", "patient_birth_year", "patientBirthYear", "userBirthYear"]

# -------- STATE --------
var is_request_running = false
var pending_login_data : Dictionary = {}
var first_login := false

var is_user_token_lookup = false
var is_doctor_token_lookup = false
var pending_doctor_token = ""
var prefill_http := HTTPRequest.new()
var is_prefill_lookup_in_progress := false
var pending_prefill_token := ""
var pending_prefill_generation := 0
var token_input_generation := 0
var last_autofill_token := ""
var last_autofill_birth_year := ""
var last_autofill_doctor_token := ""
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

	back_button.visible = not first_login
	back_button.disabled = first_login

	if PlayerData.user_id != -1:
		token_input.text = PlayerData.token
		birth_year_input.text = str(PlayerData.birth_year)
		doctor_token_input.text = PlayerData.doctor_token

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
	FileManager.save_game()

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
	if birth_year_text == "" or not birth_year_text.is_valid_int():
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
	doctor_token_input.editable = not locked and not _should_lock_doctor_token()
	generate_button.disabled = false
	if not locked:
		_sync_guest_creation_controls()
		_update_button()

func _should_lock_doctor_token() -> bool:
	return false

func _set_doctor_token_locked(locked: bool) -> void:
	if locked:
		doctor_token_input.text = ""
	doctor_token_input.editable = not locked
	doctor_token_input.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	if locked and doctor_token_input.has_focus():
		doctor_token_input.release_focus()

func _sync_guest_creation_controls() -> void:
	guest_button.disabled = false
	generate_button.disabled = false
	generate_button.text = GENERATE_BUTTON_NORMAL_TEXT
	_set_doctor_token_locked(false)

# -------- TOKEN HELPERS --------
func _generate_token() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var token = ""
	for i in range(TOKEN_LENGTH):
		token += chars[randi() % chars.length()]
	return token

func _clear_fields_for_generated_token() -> void:
	birth_year_input.text = ""
	doctor_token_input.text = ""
	_clear_generated_token_state()
	_clear_prefill_state()
	_clear_previous_autofill_if_still_present()
	_sync_guest_creation_controls()
	_update_button()

func _on_generate_token_button_pressed() -> void:
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
		_set_ui_locked(false)
		return

	generated_token = _generate_token()
	is_generating_token = true
	is_request_running = true

	var url = BASE_URL + "user/?token=" + generated_token
	var has_token = await GameManager.get_valid_token()
	if not has_token:
		is_generating_token = false
		is_request_running = false
		_generate_token_offline()
		return

	var err = http.request(url, GameManager.get_api_headers(), HTTPClient.METHOD_GET)

	if err != OK:
		is_generating_token = false
		is_request_running = false
		_generate_token_offline()

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

func _response_contains_token(response_data, token_to_find: String) -> bool:
	return not _find_user_by_token_in_parsed_response(response_data, token_to_find).is_empty()

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

	var doctor_token = str(data.get("doctor_token", "")).strip_edges()
	if doctor_token != "":
		payload["doctor_token"] = doctor_token

	var doctor_id = int(data.get("doctor_id", -1))
	if doctor_id >= 0:
		payload["doctor_id"] = doctor_id

	return payload

func _extract_user_by_token(body_text: String, token_to_find: String) -> Dictionary:
	var parsed = JSON.parse_string(body_text)
	return _find_user_by_token_in_parsed_response(parsed, token_to_find)

func _extract_lookup_id(response_code: int, body_text: String, token_to_find: String) -> int:
	if response_code == 404:
		return -1
	if response_code < 200 or response_code >= 300:
		return -1
	if body_text.strip_edges() == "":
		return -1

	var parsed = JSON.parse_string(body_text)
	var entry = _find_user_by_token_in_parsed_response(parsed, token_to_find)

	if entry.has("id"):
		return int(entry["id"])

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("id") and not parsed.has("token"):
		return int(parsed["id"])

	return -1

func _extract_user_birth_year_from_lookup(user_data: Dictionary) -> String:
	for key in BIRTH_YEAR_KEYS:
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

func _extract_latest_doctor_token_from_lookup(user_data: Dictionary) -> String:
	return str(user_data.get("doctor_token", "")).strip_edges()

func _clear_previous_autofill_if_still_present() -> void:
	if last_autofill_birth_year != "" and birth_year_input.text.strip_edges() == last_autofill_birth_year:
		birth_year_input.text = ""
	if last_autofill_doctor_token != "" and doctor_token_input.text.strip_edges() == last_autofill_doctor_token:
		doctor_token_input.text = ""
	last_autofill_token = ""
	last_autofill_birth_year = ""
	last_autofill_doctor_token = ""

func _clear_login_fields() -> void:
	token_input.text = ""
	birth_year_input.text = ""
	doctor_token_input.text = ""
	_clear_generated_token_state(true)
	_clear_prefill_state()
	_clear_previous_autofill_if_still_present()
	_sync_guest_creation_controls()
	_update_button()

func _clear_fields_after_patient_token_input() -> void:
	_clear_prefill_state()

func _clear_prefill_state() -> void:
	pending_prefill_token = ""
	pending_prefill_generation = 0

func _clear_generated_token_state(include_offline := false) -> void:
	generated_patient_token_value = ""
	if include_offline:
		offline_generated_token_value = ""

func _set_general_error(message: String) -> void:
	pending_login_data.clear()
	_clear_generated_token_state(true)
	_clear_prefill_state()
	_clear_previous_autofill_if_still_present()
	_sync_guest_creation_controls()
	_update_button()
	status_label.text = message

func _apply_lookup_prefill(user_data: Dictionary, looked_up_token: String) -> void:
	var looked_up_birth_year = _extract_user_birth_year_from_lookup(user_data)
	var looked_up_doctor_token = _extract_latest_doctor_token_from_lookup(user_data)

	if looked_up_birth_year != "":
		birth_year_input.text = looked_up_birth_year
	if looked_up_doctor_token != "" and not _should_lock_doctor_token():
		doctor_token_input.text = looked_up_doctor_token

	last_autofill_token = looked_up_token
	last_autofill_birth_year = looked_up_birth_year
	last_autofill_doctor_token = looked_up_doctor_token
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
	if is_request_running or is_doctor_token_lookup or is_generating_token:
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
	var has_token = await GameManager.get_valid_token()
	if pending_prefill_token != token:
		return
	if request_generation != token_input_generation:
		return
	if not has_token:
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
		return

	if response_code == 404:
		return

	if response_code < 200 or response_code >= 300:
		return

	var user_data = _extract_user_by_token(body_text, requested_token)
	if user_data.is_empty():
		return

	_apply_lookup_prefill(user_data, requested_token)

func _string_contains_any(text: String, needles: Array[String]) -> bool:
	var haystack = text.to_lower()
	for needle in needles:
		if haystack.find(needle) != -1:
			return true
	return false

func _is_doctor_not_found_error(response_code: int, body_text: String) -> bool:
	if not pending_login_data.has("doctor_token"):
		return false

	if response_code != 400 and response_code != 404:
		return false

	var missing_terms: Array[String] = ["not found", "does not exist", "n'existe", "introuvable", "invalid", "invalide"]

	var lowered_body = body_text.to_lower()
	if lowered_body.find("doctor_token") != -1 and _string_contains_any(lowered_body, missing_terms):
		return true

	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in ["doctor_token", "detail", "message", "error"]:
			if not parsed.has(key):
				continue
			var value_text = str(parsed[key]).to_lower()
			if key == "doctor_token" or _string_contains_any(value_text, missing_terms):
				return true

	if response_code == 404:
		return true

	return false

func _clear_invalid_doctor_token(reason: String) -> void:
	doctor_token_input.text = ""
	pending_doctor_token = ""
	pending_login_data.erase("doctor_token")
	pending_login_data.erase("doctor_id")
	if str(PlayerData.doctor_token).strip_edges() != "":
		PlayerData.doctor_token = ""
		FileManager.save_game()

func _reset_doctor_lookup_state() -> void:
	_reset_request_flags()
	_reset_doctor_state()
	pending_login_data.clear()

func _reset_request_flags() -> void:
	is_request_running = false
	is_user_token_lookup = false
	is_doctor_token_lookup = false

func _reset_doctor_state() -> void:
	pending_doctor_token = ""

func _handle_doctor_lookup_blocked(status_message: String, log_message: String) -> void:
	if log_message.find("login blocked") != -1:
		_fallback_doctor_lookup_to_offline(log_message.replace("login blocked", "fallback to offline login"))
		return
	status_label.text = status_message
	_reset_doctor_lookup_state()

func _fallback_doctor_lookup_to_offline(log_message: String) -> void:
	status_label.text = "Mode hors ligne"
	_reset_request_flags()
	_reset_doctor_state()
	_offline_login(pending_login_data)

func _finalize_login_and_go_to_menu() -> void:
	PlayerData.print_data()
	FileManager.save_game()
	pending_login_data.clear()
	_reset_doctor_state()
	_clear_generated_token_state(true)
	call_deferred("_go_to_menu")

func _can_create_missing_user_from_token(_token: String) -> bool:
	return bool(pending_login_data.get("guest_created", false))

func _handle_user_token_not_found() -> void:
	var token = str(pending_login_data.get("token", "")).strip_edges()
	if _can_create_missing_user_from_token(token):
		_send_login_request(pending_login_data)
		return

	is_request_running = false
	is_user_token_lookup = false
	pending_login_data.clear()
	_set_general_error("L'utilisateur n'existe pas")

func _handle_user_token_lookup_blocked(log_message: String) -> void:
	is_request_running = false
	is_user_token_lookup = false
	if not pending_login_data.is_empty():
		_offline_login(pending_login_data)
		return
	pending_login_data.clear()
	_set_general_error("Impossible de vérifier l'utilisateur")
	_sync_guest_creation_controls()

func _handle_guest_creation_token_exists() -> void:
	is_request_running = false
	is_user_token_lookup = false
	pending_login_data.clear()
	offline_generated_token_value = ""
	_set_general_error("Cet identifiant existe déjà, choisissez en un autre")
	_sync_guest_creation_controls()


func _handle_guest_creation_failed(log_message: String, status_message := "Impossible de créer l'utilisateur") -> void:
	_reset_request_flags()
	_reset_doctor_state()
	pending_login_data.clear()
	_set_general_error(status_message)
	_sync_guest_creation_controls()

func _start_user_token_lookup(token: String) -> void:
	is_user_token_lookup = true
	status_label.text = "Vérification utilisateur..."
	var has_token = await GameManager.get_valid_token()
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

	if pending_login_data.has("doctor_token"):
		pending_doctor_token = str(pending_login_data.get("doctor_token", "")).strip_edges()
		is_doctor_token_lookup = true
		status_label.text = "Vérification médecin..."
		var has_token = await GameManager.get_valid_token()
		if not has_token:
			_handle_doctor_lookup_blocked(
				"Impossible de vérifier l'identifiant du médecin",
				"Doctor token auth bootstrap/refresh failed, login blocked"
			)
			return
		var check_err = http.request(
			BASE_URL + DOCTOR_LOOKUP_PATH + pending_doctor_token,
			GameManager.get_api_headers(),
			HTTPClient.METHOD_GET
		)
		if check_err != OK:
			_handle_doctor_lookup_blocked(
				"Impossible de vérifier l'identifiant du médecin",
				"Doctor token check request failed immediately, login blocked"
			)
	else:
		_send_login_request(pending_login_data)


# -------- LOGIN --------
func _get_validated_form_data(is_guest: bool) -> Dictionary:
	var token = token_input.text.strip_edges()
	var birth_year = birth_year_input.text.strip_edges()
	var doctor_token = doctor_token_input.text.strip_edges()

	if token == "" and birth_year == "":
		status_label.text = "Identifiant et année de naissance requis"
		return {}
	if token == "":
		status_label.text = "Identifiant requis"
		return {}

	if _is_reserved_patient_token(token):
		_set_general_error("Cet identifiant est invalide")
		return {}

	if birth_year == "":
		status_label.text = "Année de naissance requise"
		return {}

	if not _is_valid_birth_year(birth_year):
		status_label.text = "L'année de naissance doit être comprise entre " + _get_birth_year_range_text()
		return {}

	var data = {
		"token": token,
		"uuid": _get_device_uuid(),
		"birth_year": int(birth_year)
	}

	if is_guest:
		data["guest_created"] = true

	if doctor_token != "":
		data["doctor_token"] = doctor_token

	data["token_generated_offline"] = is_guest and offline_generated_token_value != "" and token == offline_generated_token_value
	return data

func _start_login_flow(data: Dictionary, status_message: String) -> void:
	pending_login_data = data.duplicate(true)
	is_request_running = true
	status_label.text = status_message
	_start_user_token_lookup(str(data.get("token", "")).strip_edges())

func _on_save_button_pressed():
	if is_request_running:
		return

	var data = _get_validated_form_data(false)
	if data.is_empty():
		return

	_start_login_flow(data, "Connexion...")


func _send_login_request(data: Dictionary) -> void:
	is_request_running = true
	status_label.text = "Connexion..."
	var payload = _build_user_request_payload(data)
	var has_token = await GameManager.get_valid_token()
	if not has_token:
		if bool(data.get("guest_created", false)):
			_offline_login(data)
		else:
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
			_offline_login(data)
		else:
			_offline_login(data)

# -------- HTTP RESPONSE --------
func _on_http_request_request_completed(result, response_code, _headers, body):
	is_request_running = false

	if is_generating_token:
		is_generating_token = false

		if result != HTTPRequest.RESULT_SUCCESS:
			_generate_token_offline()
			return

		if response_code != 404 and (response_code < 200 or response_code >= 300):
			_generate_token_offline()
			return

		var token_body_text = body.get_string_from_utf8()
		if _is_token_available(response_code, token_body_text):
			token_input.text = generated_token
			_clear_fields_for_generated_token()
			generated_patient_token_value = generated_token
			offline_generated_token_value = ""
			status_label.text = "Identifiant généré ✔"
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

	if is_doctor_token_lookup:
		is_doctor_token_lookup = false
		var doctor_token = pending_doctor_token
		pending_doctor_token = ""
		var doctor_body_text = body.get_string_from_utf8()

		if result != HTTPRequest.RESULT_SUCCESS:
			status_label.text = "Impossible de vérifier l'identifiant du médecin"
			_fallback_doctor_lookup_to_offline("Doctor token lookup network failure, fallback to offline login")
			return

		if response_code == 404:
			status_label.text = "Le médecin n'existe pas"
			_clear_invalid_doctor_token("lookup 404")
			_reset_doctor_lookup_state()
			return

		if response_code < 200 or response_code >= 300:
			status_label.text = "Impossible de vérifier l'identifiant du médecin"
			_fallback_doctor_lookup_to_offline("Doctor token lookup failed with code=%s, fallback to offline login" % str(response_code))
			return

		var doctor_found = _is_lookup_token_found(response_code, doctor_body_text, doctor_token)
		if not doctor_found:
			status_label.text = "Le médecin n'existe pas"
			_clear_invalid_doctor_token("lookup no matching token")
			_reset_doctor_lookup_state()
			return

		var doctor_id = _extract_lookup_id(response_code, doctor_body_text, doctor_token)
		if doctor_id >= 0:
			pending_login_data["doctor_id"] = doctor_id

		_send_login_request(pending_login_data)
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		if bool(pending_login_data.get("guest_created", false)):
			_offline_login(pending_login_data)
		else:
			_offline_login(pending_login_data)
		return

	var body_text = body.get_string_from_utf8()

	if _is_doctor_not_found_error(response_code, body_text):
		status_label.text = "Le médecin n'existe pas"
		_clear_invalid_doctor_token("backend rejected token")
		pending_login_data.clear()
		return

	if response_code != 200 and response_code != 201:
		if bool(pending_login_data.get("guest_created", false)):
			_handle_guest_creation_failed("Guest creation rejected | code=%s" % str(response_code))
		else:
			_offline_login(pending_login_data)
		return

	var response = JSON.parse_string(body_text)

	if typeof(response) != TYPE_DICTIONARY or not response.has("id"):
		if bool(pending_login_data.get("guest_created", false)):
			_handle_guest_creation_failed("Invalid guest creation response payload")
		else:
			_offline_login(pending_login_data)
		return

	var user_id = int(response["id"])

	var resolved_uuid = str(response.get("uuid", pending_login_data.get("uuid", _get_device_uuid())))

	var birth_year = pending_login_data.get("birth_year", "")
	if str(birth_year).is_valid_int():
		birth_year = int(birth_year)

	PlayerData.set_user(
		user_id,
		resolved_uuid,
		str(pending_login_data.get("token")),
		birth_year,
		str(pending_login_data.get("doctor_token", ""))
	)

	PlayerData.birth_year = birth_year

	_finalize_login_and_go_to_menu()

# -------- OFFLINE --------
func _offline_login(data):
	var local_id = -2
	var birth_year = data.get("birth_year", "")
	if str(birth_year).is_valid_int():
		birth_year = int(birth_year)

	PlayerData.set_user(
		local_id,
		str(data.get("uuid", _get_device_uuid())),
		data["token"],
		birth_year,
		str(data.get("doctor_token", ""))
	)

	PlayerData.birth_year = birth_year
	SyncManager.add_action({
		"type": "login",
		"data": data
	})

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

	var data = _get_validated_form_data(true)
	if data.is_empty():
		return

	_start_login_flow(data, "Création du compte...")


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
		doctor_token_input.text = sanitized
		return

	_update_button()

func _on_logout_button_pressed() -> void:
	PlayerData.logout_user()
	SaveRgpd.set_accepted(false, true)
	FileManager.save_game()

	var interface = _get_interface()
	if interface:
		interface.first_login_flow = true
		interface.show_gdpr()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")
