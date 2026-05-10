extends Control

@onready var token_input = $MarginContainer/fond/MarginContainer/VBoxContainer/CleBox/TokenInput
@onready var birth_year_input = $MarginContainer/fond/MarginContainer/VBoxContainer/BirthYearBox/BirthYearInput
@onready var doctor_token_input = $MarginContainer/fond/MarginContainer/VBoxContainer/DoctorTokenBox/DoctorTokenInput
@onready var save_button = $MarginContainer/fond/MarginContainer/VBoxContainer/CreerOuCo/SaveButton
@onready var guest_button = $MarginContainer/fond/MarginContainer/VBoxContainer/CreerOuCo/GuestButton
@onready var status_label = $MarginContainer/fond/MarginContainer/VBoxContainer/StatusLabel
@onready var generate_button = $MarginContainer/fond/MarginContainer/VBoxContainer/CleBox/GenerateTokenButton
@onready var back_button = $BackButton

const TOKEN_LENGTH := 8
const MAX_TOKEN_GENERATION_ATTEMPTS := 20
const PREFILL_MIN_TOKEN_LENGTH := 1
const MAX_BIRTH_YEAR_AGE := 110
const MIN_BIRTH_YEAR_AGE := 6
const RESERVED_PATIENT_TOKENS := ["guest", "invite", "invité"]
const GENERATE_BUTTON_NORMAL_TEXT := "Aléatoire"

var is_request_running = false
var pending_login_data : Dictionary = {}
var first_login := false

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

func get_interface():
	return get_tree().get_meta("interface")

func _ready():
	randomize()
	token_input.focus_exited.connect(_on_token_input_focus_exited)
	token_input.focus_entered.connect(_on_token_input_focus_entered)

	back_button.visible = not first_login
	back_button.disabled = first_login

	if PlayerData.user_id != -1:
		token_input.text = PlayerData.token
		birth_year_input.text = str(PlayerData.birth_year)
		doctor_token_input.text = PlayerData.doctor_token

	sync_controls()
	update_button()
	show_token_update()

func show_token_update() -> void:
	if not PlayerData.token_update_pending:
		return
	if PlayerData.updated_token == "":
		return

	status_label.text = "Identifiant mis à jour : " + PlayerData.updated_token
	PlayerData.token_update_pending = false
	PlayerData.previous_token = ""
	PlayerData.updated_token = ""
	FileManager.save_game()

func _on_token_input_text_changed(_text=""):
	token_input_generation += 1
	if offline_generated_token_value != "" and token_input.text.strip_edges() != offline_generated_token_value:
		offline_generated_token_value = ""
	if generated_patient_token_value != "" and token_input.text.strip_edges() != generated_patient_token_value:
		generated_patient_token_value = ""

	clear_patient_fields()
	clear_autofill()
	sync_controls()

	update_button()

func _on_input_changed(_text=""):
	update_button()

func _on_token_input_focus_entered() -> void:
	clear_patient_fields()
	clear_autofill()
	sync_controls()
	update_button()

func update_button():
	var token = token_input.text.strip_edges()
	var birth_year = birth_year_input.text.strip_edges()

	save_button.disabled = false

	if token != "" and not reserved_token(token) and valid_birth_year(birth_year):
		status_label.text = ""

func device_uuid() -> String:
	return OS.get_unique_id()

func reserved_token(token: String) -> bool:
	return RESERVED_PATIENT_TOKENS.has(token.strip_edges().to_lower())

func valid_birth_year(birth_year_text: String) -> bool:
	if birth_year_text == "" or not birth_year_text.is_valid_int():
		return false

	var birth_year = int(birth_year_text)
	var current_year = int(Time.get_datetime_dict_from_system()["year"])
	return birth_year >= current_year - MAX_BIRTH_YEAR_AGE and birth_year <= current_year - MIN_BIRTH_YEAR_AGE

func birth_year_range() -> String:
	var current_year = int(Time.get_datetime_dict_from_system()["year"])
	return "%s et %s" % [str(current_year - MAX_BIRTH_YEAR_AGE), str(current_year -  MIN_BIRTH_YEAR_AGE)]

func set_locked(locked: bool) -> void:
	save_button.disabled = locked
	guest_button.disabled = false
	back_button.disabled = locked or first_login
	token_input.editable = not locked
	birth_year_input.editable = not locked
	doctor_token_input.editable = not locked
	generate_button.disabled = false
	if not locked:
		sync_controls()
		update_button()

func sync_controls() -> void:
	guest_button.disabled = false
	generate_button.disabled = false
	generate_button.text = GENERATE_BUTTON_NORMAL_TEXT

func make_token() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var token = ""
	for i in range(TOKEN_LENGTH):
		token += chars[randi() % chars.length()]
	return token

func clear_generated_fields() -> void:
	birth_year_input.text = ""
	doctor_token_input.text = ""
	clear_generated_token()
	clear_prefill()
	clear_autofill()
	sync_controls()
	update_button()

func _on_generate_token_button_pressed() -> void:
	token_generation_attempts = 0
	clear_generated_fields()
	status_label.text = "Génération..."
	set_locked(true)
	try_generate_token()

func try_generate_token():
	token_generation_attempts += 1
	if token_generation_attempts > MAX_TOKEN_GENERATION_ATTEMPTS:
		is_generating_token = false
		is_request_running = false
		show_error("Impossible de générer un identifiant")
		set_locked(false)
		return

	generated_token = make_token()
	is_generating_token = true
	is_request_running = true

	var response: Dictionary = await Api.get_user(generated_token)

	if not bool(response.get("auth", true)):
		push_warning("Token generation auth unavailable, generating offline.")
		is_generating_token = false
		is_request_running = false
		generate_offline()
		return

	if int(response.get("error", OK)) != OK:
		push_warning("Token generation request failed immediately: %s" % str(response.get("error", OK)))
		is_generating_token = false
		is_request_running = false
		generate_offline()
		return

	if int(response.get("result", HTTPRequest.RESULT_SUCCESS)) != HTTPRequest.RESULT_SUCCESS:
		push_warning("Token generation lookup failed: result=%s" % str(response.get("result", 0)))
		is_generating_token = false
		is_request_running = false
		generate_offline()
		return

	if int(response.get("code", 0)) != 404 and not bool(response.get("ok", false)):
		push_warning("Token generation lookup failed: code=%s" % str(response.get("code", 0)))
		is_generating_token = false
		is_request_running = false
		generate_offline()
		return

	if Api.token_available(response, generated_token):
		is_generating_token = false
		is_request_running = false
		token_input.text = generated_token
		clear_generated_fields()
		generated_patient_token_value = generated_token
		offline_generated_token_value = ""
		status_label.text = "Identifiant généré ✔"
		set_locked(false)
	else:
		is_request_running = false
		try_generate_token()

func local_tokens() -> Dictionary:
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

func generate_offline() -> void:
	var reserved_tokens = local_tokens()

	for _i in range(MAX_TOKEN_GENERATION_ATTEMPTS):
		var candidate = make_token()
		if reserved_tokens.has(candidate):
			continue

		token_input.text = candidate
		clear_generated_fields()
		generated_patient_token_value = candidate
		offline_generated_token_value = candidate
		status_label.text = "Identifiant généré hors ligne (vérification à la prochaine connection)"
		set_locked(false)
		return

	show_error("Impossible de générer une clé patient")
	set_locked(false)

func clear_autofill() -> void:
	if last_autofill_birth_year != "" and birth_year_input.text.strip_edges() == last_autofill_birth_year:
		birth_year_input.text = ""
	if last_autofill_doctor_token != "" and doctor_token_input.text.strip_edges() == last_autofill_doctor_token:
		doctor_token_input.text = ""
	last_autofill_token = ""
	last_autofill_birth_year = ""
	last_autofill_doctor_token = ""

func clear_patient_fields() -> void:
	clear_prefill()

func clear_prefill() -> void:
	pending_prefill_token = ""
	pending_prefill_generation = 0

func clear_generated_token(include_offline := false) -> void:
	generated_patient_token_value = ""
	if include_offline:
		offline_generated_token_value = ""

func show_error(message: String) -> void:
	pending_login_data.clear()
	clear_generated_token(true)
	clear_prefill()
	clear_autofill()
	sync_controls()
	update_button()
	status_label.text = message

func apply_prefill(user_data: Dictionary, looked_up_token: String) -> void:
	var looked_up_birth_year = Api.user_birth_year(user_data)
	var looked_up_doctor_token = Api.user_doctor_token(user_data)

	if looked_up_birth_year != "":
		birth_year_input.text = looked_up_birth_year
	if looked_up_doctor_token != "":
		doctor_token_input.text = looked_up_doctor_token

	last_autofill_token = looked_up_token
	last_autofill_birth_year = looked_up_birth_year
	last_autofill_doctor_token = looked_up_doctor_token
	update_button()

func prefill_user() -> void:
	var token = token_input.text.strip_edges()
	if token == "" or reserved_token(token):
		pending_prefill_token = ""
		clear_autofill()
		return
	if token.length() < PREFILL_MIN_TOKEN_LENGTH:
		pending_prefill_token = ""
		clear_autofill()
		return
	if is_request_running or is_generating_token:
		return
	if is_prefill_lookup_in_progress or pending_prefill_token == token:
		return
	if last_autofill_token == token:
		return

	clear_autofill()
	start_prefill(token)


func start_prefill(token: String) -> void:
	pending_prefill_token = token
	pending_prefill_generation = token_input_generation
	run_prefill(token, pending_prefill_generation)

func _on_token_input_focus_exited() -> void:
	prefill_user()

func run_prefill(token: String, request_generation: int) -> void:
	if pending_prefill_token != token:
		return
	if request_generation != token_input_generation:
		return

	is_prefill_lookup_in_progress = true
	var response: Dictionary = await Api.get_user(token)
	is_prefill_lookup_in_progress = false

	if pending_prefill_token != token:
		return
	if request_generation != token_input_generation:
		return
	if token_input.text.strip_edges() != token:
		return

	pending_prefill_token = ""
	pending_prefill_generation = 0

	if not bool(response.get("auth", true)):
		push_warning("Prefill auth unavailable.")
		return

	if int(response.get("error", OK)) != OK:
		push_warning("Prefill request failed immediately: %s" % str(response.get("error", OK)))
		return

	if int(response.get("result", HTTPRequest.RESULT_SUCCESS)) != HTTPRequest.RESULT_SUCCESS:
		push_warning("Prefill lookup failed: result=%s" % str(response.get("result", 0)))
		return

	if not bool(response.get("ok", false)):
		if int(response.get("code", 0)) != 404:
			push_warning("Prefill lookup ignored: code=%s" % str(response.get("code", 0)))
		return

	var user_data := Api.user_from_response(response, token)
	if user_data.is_empty():
		push_warning("Prefill response has no matching user for token.")
		return

	apply_prefill(user_data, token)

func clear_doctor(reason: String) -> void:
	push_warning("Doctor token cleared: %s" % reason)
	doctor_token_input.text = ""
	pending_login_data.erase("doctor_token")
	if str(PlayerData.doctor_token).strip_edges() != "":
		PlayerData.doctor_token = ""
		FileManager.save_game()

func reset_doctor_lookup() -> void:
	is_request_running = false
	pending_login_data.clear()

func doctor_blocked(status_message: String, log_message: String) -> void:
	if log_message.find("login blocked") != -1:
		doctor_offline(log_message.replace("login blocked", "fallback to offline login"))
		return

	push_warning(log_message)
	status_label.text = status_message
	reset_doctor_lookup()

func doctor_offline(log_message: String) -> void:
	push_warning(log_message)
	status_label.text = "Mode hors ligne"
	is_request_running = false
	offline_login(pending_login_data)

func finish_login() -> void:
	PlayerData.print_data()
	FileManager.save_game()
	pending_login_data.clear()
	clear_generated_token(true)
	call_deferred("go_to_menu")

func can_create_user() -> bool:
	return bool(pending_login_data.get("guest_created", false))

func user_not_found() -> void:
	if can_create_user():
		send_login(pending_login_data)
		return

	is_request_running = false
	pending_login_data.clear()
	show_error("L'utilisateur n'existe pas")

func user_blocked(log_message: String) -> void:
	push_warning(log_message)
	is_request_running = false
	if not pending_login_data.is_empty():
		offline_login(pending_login_data)
		return
	pending_login_data.clear()
	show_error("Impossible de vérifier l'utilisateur")
	sync_controls()

func guest_token_exists() -> void:
	is_request_running = false
	pending_login_data.clear()
	offline_generated_token_value = ""
	show_error("Cet identifiant existe déjà, choisissez en un autre")
	sync_controls()


func guest_failed(log_message: String, status_message := "Impossible de créer l'utilisateur") -> void:
	push_error(log_message)
	is_request_running = false
	pending_login_data.clear()
	show_error(status_message)
	sync_controls()

func start_user_lookup(token: String) -> void:
	status_label.text = "Vérification utilisateur..."
	var response: Dictionary = await Api.get_user(token)

	if not bool(response.get("auth", true)):
		user_blocked("User token lookup auth unavailable")
		return

	if int(response.get("error", OK)) != OK:
		user_blocked("User token lookup request failed immediately: %s" % str(response.get("error", OK)))
		return

	if int(response.get("result", HTTPRequest.RESULT_SUCCESS)) != HTTPRequest.RESULT_SUCCESS:
		user_blocked("User token lookup failed | result=%s" % str(response.get("result", 0)))
		return

	if int(response.get("code", 0)) != 404 and not bool(response.get("ok", false)):
		user_blocked("User token lookup failed | code=%s" % str(response.get("code", 0)))
		return

	if not Api.token_found(response, token):
		user_not_found()
		return

	continue_login()

func continue_login() -> void:
	is_request_running = true

	if bool(pending_login_data.get("guest_created", false)):
		guest_token_exists()
		return

	if pending_login_data.has("doctor_token"):
		var doctor_token = str(pending_login_data.get("doctor_token", "")).strip_edges()
		status_label.text = "Vérification médecin..."
		var response: Dictionary = await Api.get_doctor(doctor_token)

		if not bool(response.get("auth", true)):
			doctor_blocked(
				"Impossible de vérifier l'identifiant du médecin",
				"Doctor token auth bootstrap/refresh failed, login blocked"
			)
			return

		if int(response.get("error", OK)) != OK:
			doctor_blocked(
				"Impossible de vérifier l'identifiant du médecin",
				"Doctor token check request failed immediately: %s, login blocked" % str(response.get("error", OK))
			)
			return

		if int(response.get("result", HTTPRequest.RESULT_SUCCESS)) != HTTPRequest.RESULT_SUCCESS:
			doctor_offline("Doctor token lookup network failure, fallback to offline login")
			return

		if int(response.get("code", 0)) == 404:
			status_label.text = "Le médecin n'existe pas"
			clear_doctor("lookup 404")
			reset_doctor_lookup()
			return

		if not bool(response.get("ok", false)):
			doctor_offline("Doctor token lookup failed with code=%s, fallback to offline login" % str(response.get("code", 0)))
			return

		if not Api.token_found(response, doctor_token):
			status_label.text = "Le médecin n'existe pas"
			clear_doctor("lookup no matching token")
			reset_doctor_lookup()
			return

		send_login(pending_login_data)
	else:
		send_login(pending_login_data)


func form_data(is_guest: bool) -> Dictionary:
	var token = token_input.text.strip_edges()
	var birth_year = birth_year_input.text.strip_edges()
	var doctor_token = doctor_token_input.text.strip_edges()

	if token == "" and birth_year == "":
		status_label.text = "Identifiant et année de naissance requis"
		return {}
	if token == "":
		status_label.text = "Identifiant requis"
		return {}

	if reserved_token(token):
		show_error("Cet identifiant est invalide")
		return {}

	if birth_year == "":
		status_label.text = "Année de naissance requise"
		return {}

	if not valid_birth_year(birth_year):
		status_label.text = "L'année de naissance doit être comprise entre " + birth_year_range()
		return {}

	var data = {
		"token": token,
		"uuid": device_uuid(),
		"birth_year": int(birth_year)
	}

	if is_guest:
		data["guest_created"] = true

	if doctor_token != "":
		data["doctor_token"] = doctor_token

	data["token_generated_offline"] = is_guest and offline_generated_token_value != "" and token == offline_generated_token_value
	return data

func start_login(data: Dictionary, status_message: String) -> void:
	pending_login_data = data.duplicate(true)
	is_request_running = true
	status_label.text = status_message
	start_user_lookup(str(data.get("token", "")).strip_edges())

func _on_save_button_pressed():
	if is_request_running:
		return

	var data = form_data(false)
	if data.is_empty():
		return

	start_login(data, "Connexion...")


func send_login(data: Dictionary) -> void:
	is_request_running = true
	status_label.text = "Connexion..."
	var response: Dictionary = await Api.create_user(data)

	if not bool(response.get("auth", true)):
		push_warning("Login auth unavailable, switching offline.")
		offline_login(data)
		return

	if int(response.get("error", OK)) != OK:
		push_warning("Login request failed immediately: %s" % str(response.get("error", OK)))
		offline_login(data)
		return

	is_request_running = false

	if int(response.get("result", HTTPRequest.RESULT_SUCCESS)) != HTTPRequest.RESULT_SUCCESS:
		push_warning("Login response failed: result=%s" % str(response.get("result", 0)))
		offline_login(data)
		return

	if Api.missing_doctor(response, data.has("doctor_token")):
		status_label.text = "Le médecin n'existe pas"
		clear_doctor("backend rejected token")
		pending_login_data.clear()
		return

	if not bool(response.get("ok", false)):
		if bool(data.get("guest_created", false)):
			guest_failed("Guest creation rejected | code=%s" % str(response.get("code", 0)))
		else:
			push_warning("Login rejected, switching offline: code=%s" % str(response.get("code", 0)))
			offline_login(data)
		return

	var body_data = Api.parse(str(response.get("body_text", "")))

	if typeof(body_data) != TYPE_DICTIONARY or not body_data.has("id"):
		if bool(data.get("guest_created", false)):
			guest_failed("Invalid guest creation response payload")
		else:
			push_error("Invalid login response payload.")
			offline_login(data)
		return

	var user_id = int(body_data["id"])

	var resolved_uuid = str(body_data.get("uuid", data.get("uuid", device_uuid())))

	var birth_year := str(data.get("birth_year", ""))

	PlayerData.set_user(
		user_id,
		resolved_uuid,
		str(data.get("token")),
		birth_year,
		str(data.get("doctor_token", ""))
	)

	PlayerData.birth_year = birth_year

	finish_login()

func offline_login(data):
	var local_id = -2
	var birth_year := str(data.get("birth_year", ""))

	PlayerData.set_user(
		local_id,
		str(data.get("uuid", device_uuid())),
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

	finish_login()

func go_to_menu():
	var interface = get_interface()
	if interface:
		interface.show_menu()

func _on_back_button_pressed():
	if first_login:
		return

	get_interface().show_menu()

func _on_guest_button_pressed() -> void:
	if is_request_running:
		return

	var data = form_data(true)
	if data.is_empty():
		return

	start_login(data, "Création du compte...")


func _on_birth_year_input_text_changed(new_text: String) -> void:
	var filtered = ""
	for c in new_text:
		if c.is_valid_int():
			filtered += c

	if filtered != new_text:
		birth_year_input.text = filtered

	update_button()

func _on_doctor_token_input_text_changed(new_text: String) -> void:
	var sanitized = new_text.strip_edges()
	if sanitized != new_text:
		doctor_token_input.text = sanitized
		return

	update_button()

func _on_logout_button_pressed() -> void:
	PlayerData.logout_user()
	Settings.set_rgpd_accepted(false)
	FileManager.save_game()

	var interface = get_interface()
	if interface:
		interface.first_login_flow = true
		interface.show_gdpr()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")
