extends Control

@onready var token_input := $MarginContainer/fond/MarginContainer/VBoxContainer/CleBox/TokenInput
@onready var birth_year_input := $MarginContainer/fond/MarginContainer/VBoxContainer/BirthYearBox/BirthYearInput
@onready var doctor_token_input := $MarginContainer/fond/MarginContainer/VBoxContainer/DoctorTokenBox/DoctorTokenInput
@onready var save_button := $MarginContainer/fond/MarginContainer/VBoxContainer/CreerOuCo/SaveButton
@onready var guest_button := $MarginContainer/fond/MarginContainer/VBoxContainer/CreerOuCo/GuestButton
@onready var status_label := $MarginContainer/fond/MarginContainer/VBoxContainer/StatusLabel
@onready var generate_button := $MarginContainer/fond/MarginContainer/VBoxContainer/CleBox/GenerateTokenButton
@onready var back_button := $BackButton

const TOKEN_LENGTH := 8
const MAX_TOKEN_GENERATION_ATTEMPTS := 20
const PREFILL_MIN_TOKEN_LENGTH := 1
const MAX_BIRTH_YEAR_AGE := 110
const MIN_BIRTH_YEAR_AGE := 6
const RESERVED_PATIENT_TOKENS := ["guest", "invite", "invité"]

var is_request_running := false
var pending_login_data: Dictionary = {}
var first_login := false

var is_prefill_lookup_in_progress := false
var pending_prefill_token := ""
var pending_prefill_generation := 0
var token_input_generation := 0

var last_autofill_token := ""
var last_autofill_birth_year := ""
var last_autofill_doctor_token := ""

var is_generating_token := false
var generated_token := ""
var token_generation_attempts := 0
var generated_patient_token_value := ""
var offline_generated_token_value := ""


func _ready() :
	randomize()


	back_button.visible = not first_login
	back_button.disabled = first_login
	guest_button.disabled = false
	generate_button.disabled = false
	generate_button.text = "Aléatoire"

	if PlayerData.user_id != -1:
		token_input.text = PlayerData.token
		birth_year_input.text = str(PlayerData.birth_year)
		doctor_token_input.text = PlayerData.doctor_token

	update_form()


func update_form() -> void:
	var token : String = token_input.text.strip_edges()
	var birth_year : String = birth_year_input.text.strip_edges()

	save_button.disabled = is_request_running
	guest_button.disabled = is_request_running
	generate_button.disabled = is_request_running

	if token != "" and not RESERVED_PATIENT_TOKENS.has(token.strip_edges().to_lower()) and valid_year(birth_year):
		status_label.text = ""

func uuid() -> String:
	return OS.get_unique_id()


func valid_year(birth_year_text: String) -> bool:
	if birth_year_text == "" or not birth_year_text.is_valid_int():
		return false

	var birth_year := int(birth_year_text)
	var current_year := int(Time.get_datetime_dict_from_system()["year"])

	return birth_year >= current_year - MAX_BIRTH_YEAR_AGE and birth_year <= current_year - MIN_BIRTH_YEAR_AGE



func lock(locked: bool) :
	save_button.disabled = locked
	guest_button.disabled = locked
	generate_button.disabled = locked
	back_button.disabled = locked or first_login

	token_input.editable = not locked
	birth_year_input.editable = not locked
	doctor_token_input.editable = not locked

	if not locked:
		update_form()


func generating_token() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var token := ""

	for i in range(TOKEN_LENGTH):
		token += chars[randi() % chars.length()]

	return token


func clear_autofill() :
	if last_autofill_birth_year != "" and birth_year_input.text.strip_edges() == last_autofill_birth_year:
		birth_year_input.text = ""

	if last_autofill_doctor_token != "" and doctor_token_input.text.strip_edges() == last_autofill_doctor_token:
		doctor_token_input.text = ""

	last_autofill_token = ""
	last_autofill_birth_year = ""
	last_autofill_doctor_token = ""


func clear_lookup() :
	pending_prefill_token = ""
	pending_prefill_generation = 0


func clear_generated_token(offline := false) :
	generated_patient_token_value = ""

	if offline:
		offline_generated_token_value = ""


func clear_doctor(reason: String) :
	push_warning("Doctor token cleared: %s" % reason)

	doctor_token_input.text = ""
	pending_login_data.erase("doctor_token")

	if str(PlayerData.doctor_token).strip_edges() != "":
		PlayerData.doctor_token = ""
		FileManager.save_game()

func clear_generated() -> void:
	birth_year_input.text = ""
	doctor_token_input.text = ""

	clear_generated_token()
	clear_lookup()
	clear_autofill()
	update_form()


func offline_token() :
	var reserved_keys := local_tokens()

	for _i in range(MAX_TOKEN_GENERATION_ATTEMPTS):
		var candidate := generating_token()

		if reserved_keys.has(candidate):
			continue

		token_input.text = candidate
		clear_generated()

		generated_patient_token_value = candidate
		offline_generated_token_value = candidate

		status_label.text = "Identifiant généré hors ligne (vérification à la prochaine connexion)"
		lock(false)
		return

	show_error("Impossible de générer une clé patient")
	lock(false)

func generate_token() -> void:
	token_generation_attempts += 1

	if token_generation_attempts > MAX_TOKEN_GENERATION_ATTEMPTS:
		is_generating_token = false
		is_request_running = false
		show_error("Impossible de générer un identifiant")
		lock(false)
		return

	generated_token = generating_token()
	is_generating_token = true
	is_request_running = true

	var response: Dictionary = await Api.get_user(generated_token)

	if not Api.is_request_successful(response, "Token generation", true):
		is_generating_token = false
		is_request_running = false
		offline_token()
		return

	if Api.token_is_available(response, generated_token):
		is_generating_token = false
		is_request_running = false

		token_input.text = generated_token
		clear_generated()

		generated_patient_token_value = generated_token
		offline_generated_token_value = ""

		status_label.text = "Identifiant généré ✔"
		lock(false)
	else:
		is_request_running = false
		generate_token()


func local_tokens() -> Dictionary:
	var reserved_keys := {}

	var current_player_token := str(PlayerData.token).strip_edges()

	if current_player_token != "":
		reserved_keys[current_player_token] = true

	for action in SyncManager.queue:
		if typeof(action) != TYPE_DICTIONARY:
			continue

		if action.get("type", "") != "login":
			continue

		var data = action.get("data", {})

		if typeof(data) != TYPE_DICTIONARY:
			continue

		var queued_token := str(data.get("token", "")).strip_edges()

		if queued_token != "":
			reserved_keys[queued_token] = true

	return reserved_keys


func show_error(message: String) :
	pending_login_data.clear()
	clear_generated_token(true)
	clear_lookup()
	clear_autofill()
	update_form()
	status_label.text = message


func prefill() :
	var token : String = token_input.text.strip_edges()

	if token == "" or RESERVED_PATIENT_TOKENS.has(token.to_lower()):
		clear_lookup()
		clear_autofill()
		return

	if token.length() < PREFILL_MIN_TOKEN_LENGTH:
		clear_lookup()
		clear_autofill()
		return

	if is_request_running or is_generating_token:
		return

	if is_prefill_lookup_in_progress or pending_prefill_token == token:
		return

	if last_autofill_token == token:
		return

	clear_autofill()

	pending_prefill_token = token
	pending_prefill_generation = token_input_generation

	var request_generation := pending_prefill_generation

	is_prefill_lookup_in_progress = true
	var response: Dictionary = await Api.get_user(token)
	is_prefill_lookup_in_progress = false

	if pending_prefill_token != token:
		return

	if request_generation != token_input_generation:
		return

	if token_input.text.strip_edges() != token:
		return

	clear_lookup()

	if not Api.is_request_successful(response, "Prefill lookup", true):
		return

	if Api.is_not_found(response):
		return

	var user_data := Api.find_by_token(response, token)

	if user_data.is_empty():
		push_warning("Prefill response has no matching user for token.")
		return

	var looked_up_birth_year := Api.get_birth_year(user_data)
	var looked_up_doctor_token := str(user_data.get("doctor_token", "")).strip_edges()

	if looked_up_birth_year != "":
		birth_year_input.text = looked_up_birth_year

	if looked_up_doctor_token != "":
		doctor_token_input.text = looked_up_doctor_token

	last_autofill_token = token
	last_autofill_birth_year = looked_up_birth_year
	last_autofill_doctor_token = looked_up_doctor_token

	update_form()

func finish() -> void:
	PlayerData.print_data()
	FileManager.save_game()

	pending_login_data.clear()
	clear_generated_token(true)

	call_deferred("go_menu")


func offline_login(data: Dictionary) :
	var birth_year := str(data.get("birth_year", ""))

	PlayerData.set_user(
		-2,
		str(data.get("uuid", uuid())),
		str(data.get("token", "")),
		birth_year,
		str(data.get("doctor_token", ""))
	)

	PlayerData.birth_year = birth_year

	SyncManager.add_action({
		"type": "login",
		"data": data
	})

	status_label.text = "Mode hors ligne"

	finish()


func go_menu() :
	var interface = get_tree().get_meta("interface")

	if interface:
		interface.show_menu()


func get_data(is_guest: bool) -> Dictionary:
	var token: String = token_input.text.strip_edges()
	var birth_year: String = birth_year_input.text.strip_edges()
	var doctor_token: String = doctor_token_input.text.strip_edges()

	if token == "" and birth_year == "":
		status_label.text = "Identifiant et année de naissance requis"
		return {}

	if token == "":
		status_label.text = "Identifiant requis"
		return {}

	if RESERVED_PATIENT_TOKENS.has(token.strip_edges().to_lower()):
		show_error("Cet identifiant est invalide")
		return {}

	if birth_year == "":
		status_label.text = "Année de naissance requise"
		return {}

	if not valid_year(birth_year):
		var current_year := int(Time.get_datetime_dict_from_system()["year"])
		status_label.text = "L'année de naissance doit être comprise entre " + str(current_year - MAX_BIRTH_YEAR_AGE) +" et "+ str(current_year-MIN_BIRTH_YEAR_AGE)
		return {}

	var data := {
		"token": token,
		"uuid": uuid(),
		"birth_year": int(birth_year)
	}

	if is_guest:
		data["guest_created"] = true

	if doctor_token != "":
		data["doctor_token"] = doctor_token

	data["token_generated_offline"] = is_guest and offline_generated_token_value != "" and token == offline_generated_token_value

	return data

func send_login(data: Dictionary) :
	is_request_running = true
	status_label.text = "Connexion..."

	var response: Dictionary = await Api.create_user(data)

	is_request_running = false

	if not Api.is_request_successful(response, "Login", true):
		offline_login(data)
		return

	if Api.is_not_found(response) and str(data.get("doctor_token", "")).strip_edges() != "":
		status_label.text = "Le médecin n'existe pas"
		clear_doctor("backend rejected token")
		pending_login_data.clear()
		return

	if not bool(response.get("ok", false)):
		if bool(data.get("guest_created", false)):
			push_error("Guest creation rejected | code=%s" % str(response.get("code", 0)))
			is_request_running = false
			pending_login_data.clear()
			show_error("Impossible de créer l'utilisateur")
		else:
			push_warning("Login rejected, switching offline: code=%s" % str(response.get("code", 0)))
			offline_login(data)
		return

	var body_data = Api.parse_response(response)

	if typeof(body_data) != TYPE_DICTIONARY or not body_data.has("id"):
		if bool(data.get("guest_created", false)):
			push_error("Invalid guest creation response payload")
			is_request_running = false
			pending_login_data.clear()
			show_error("Impossible de créer l'utilisateur")
		else:
			push_error("Invalid login response payload.")
			offline_login(data)
		return

	var user_id := int(body_data["id"])
	var resolved_uuid := str(body_data.get("uuid", data.get("uuid", uuid())))
	var birth_year := str(data.get("birth_year", ""))

	PlayerData.set_user(
		user_id,
		resolved_uuid,
		str(data.get("token")),
		birth_year,
		str(data.get("doctor_token", ""))
	)

	PlayerData.birth_year = birth_year

	finish()


func login(data: Dictionary, status_message: String) -> void:
	pending_login_data = data.duplicate(true)
	is_request_running = true
	status_label.text = status_message

	var token := str(data.get("token", "")).strip_edges()

	status_label.text = "Vérification utilisateur..."

	var user_response: Dictionary = await Api.get_user(token)

	if not Api.is_request_successful(user_response, "User token lookup", true):
		push_warning("User token lookup failed")
		is_request_running = false

		if not pending_login_data.is_empty():
			offline_login(pending_login_data)
			return

		pending_login_data.clear()
		show_error("Impossible de vérifier l'utilisateur")
		return

	if not Api.token_exists(user_response, token):
		if bool(data.get("guest_created", false)):
			send_login(data)
			return

		is_request_running = false
		pending_login_data.clear()
		show_error("L'utilisateur n'existe pas")
		return

	if bool(data.get("guest_created", false)):
		is_request_running = false
		pending_login_data.clear()
		offline_generated_token_value = ""
		show_error("Cet identifiant existe déjà, choisissez-en un autre")
		return

	if not data.has("doctor_token"):
		send_login(data)
		return

	var doctor_token := str(data.get("doctor_token", "")).strip_edges()

	status_label.text = "Vérification médecin..."

	var doctor_response: Dictionary = await Api.get_doctor(doctor_token)

	if not Api.is_request_successful(doctor_response, "Doctor token lookup", true):
		
		push_warning("Doctor token lookup failed, fallback to offline login")
		status_label.text = "Mode hors ligne"
		is_request_running = false

		return

	if Api.is_not_found(doctor_response):
		status_label.text = "Le médecin n'existe pas"
		clear_doctor("lookup 404")
		is_request_running = false
		pending_login_data.clear()
		return

	if not Api.token_exists(doctor_response, doctor_token):
		status_label.text = "Le médecin n'existe pas"
		clear_doctor("lookup no matching token")
		is_request_running = false
		pending_login_data.clear()
		return

	send_login(data)


func _on_save_button_pressed() :
	if is_request_running:
		return

	var data := get_data(false)

	if data.is_empty():
		return

	login(data, "Connexion...")

func _on_back_button_pressed() :
	if first_login:
		return

	var interface = get_tree().get_meta("interface")

	if interface:
		interface.show_menu()


func _on_guest_button_pressed() :
	if is_request_running:
		return

	var data := get_data(true)

	if data.is_empty():
		return

	login(data, "Création du compte...")


func _on_birth_year_input_text_changed(new_text: String) :
	var filtered := ""

	for c in new_text:
		if c.is_valid_int():
			filtered += c

	if filtered != new_text:
		birth_year_input.text = filtered

	update_form()


func _on_doctor_token_input_text_changed(new_text: String) :
	var sanitized := new_text.strip_edges()

	if sanitized != new_text:
		doctor_token_input.text = sanitized
		return

	update_form()


func _on_logout_button_pressed() :
	PlayerData.logout_user()
	Settings.set_rgpd_accepted(false)
	FileManager.save_game()

	var interface = get_tree().get_meta("interface")

	if interface:
		interface.first_login = true
		interface.show_gdpr()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")


func _on_token_input_focus_exited() :
	prefill()


func _on_generate_token_button_pressed() :
	token_generation_attempts = 0
	clear_generated()
	status_label.text = "Génération..."
	lock(true)
	generate_token()


func _on_token_input_text_changed(_text := "") :
	token_input_generation += 1

	var token: String = token_input.text.strip_edges()

	if offline_generated_token_value != "" and token != offline_generated_token_value:
		offline_generated_token_value = ""

	if generated_patient_token_value != "" and token != generated_patient_token_value:
		generated_patient_token_value = ""

	clear_lookup()
	clear_autofill()
	update_form()


func _on_token_input_focus_entered() :
	clear_lookup()
	clear_autofill()
	update_form()
