extends Control

@onready var http = $HTTPRequest
@onready var token_input = $CenterContainer/HBoxContainer/VBoxContainer/TokenInput
@onready var age_input = $CenterContainer/HBoxContainer/VBoxContainer/AgeInput
@onready var save_button = $CenterContainer/HBoxContainer/VBoxContainer/SaveButton
@onready var guest_button = $CenterContainer/HBoxContainer/VBoxContainer2/GuestButton
@onready var status_label = $CenterContainer/HBoxContainer/VBoxContainer/StatusLabel
@onready var generate_button = $CenterContainer/HBoxContainer/VBoxContainer2/GenerateTokenButton
@onready var back_button = $BackButton

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"
const REQUEST_TIMEOUT_SECONDS := 5.0
const TOKEN_LENGTH := 16
const MAX_TOKEN_GENERATION_ATTEMPTS := 20

var is_request_running = false
var is_guest_mode = false
var pending_login_data : Dictionary = {}
var first_login := false

# -------- TOKEN GENERATION STATE --------
var is_generating_token = false
var generated_token = ""
var token_generation_attempts := 0

func _ready():
	randomize()
	http.timeout = REQUEST_TIMEOUT_SECONDS
	
	print("[USER MENU] first_login:", first_login)

	if first_login:
		back_button.visible = false
		back_button.disabled = true
	else:
		back_button.visible = true
		back_button.disabled = false

	if PlayerData.user_id != -1:
		token_input.text = PlayerData.token
		age_input.text = str(PlayerData.age)

	update_button()

func _on_input_changed(_text=""):
	var token = token_input.text.strip_edges().to_lower()

	if token == "guest":
		is_guest_mode = true
		age_input.text = ""
		age_input.editable = false
	else:
		if is_guest_mode:
			age_input.text = ""
		is_guest_mode = false
		age_input.editable = true

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
	generate_button.disabled = locked
func generate_token() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var token = ""
	for i in range(TOKEN_LENGTH):
		token += chars[randi() % chars.length()]
	return token

func _on_generate_token_button_pressed() -> void:
	if is_request_running:
		return
	token_generation_attempts = 0
	status_label.text = "Génération..."
	set_ui_locked(true)
	_try_generate_token()

func _try_generate_token():
	token_generation_attempts += 1
	if token_generation_attempts > MAX_TOKEN_GENERATION_ATTEMPTS:
		is_generating_token = false
		is_request_running = false
		status_label.text = "Impossible de générer un token unique"
		set_ui_locked(false)
		return

	generated_token = generate_token()
	is_generating_token = true
	is_request_running = true

	var url = BASE_URL + "user/?token=" + generated_token

	var err = http.request(url, [], HTTPClient.METHOD_GET)

	if err != OK:
		status_label.text = "Erreur réseau"
		is_generating_token = false
		is_request_running = false
		set_ui_locked(false) 

func _is_token_available(response_code: int, body_text: String) -> bool:
	if response_code == 404:
		return true

	if response_code < 200 or response_code >= 300:
		return false

	var response = JSON.parse_string(body_text)

	if typeof(response) == TYPE_ARRAY:
		return response.size() == 0

	if typeof(response) == TYPE_DICTIONARY:
		if response.has("count"):
			return int(response["count"]) == 0
		if response.has("results") and typeof(response["results"]) == TYPE_ARRAY:
			return response["results"].size() == 0
		return false

	return false
# -------- LOGIN --------
func _on_save_button_pressed():
	if is_request_running:
		return

	var token = token_input.text.strip_edges()
	var age = age_input.text.strip_edges()
 
	if token == "" or age == "":
		status_label.text = "Champs requis"
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

	pending_login_data = data.duplicate(true)

	is_request_running = true
	status_label.text = "Connexion..."

	var err = http.request(
		BASE_URL + "user/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

	if err != OK:
		_offline_login(data)

# -------- GUEST --------
func _on_guest_button_pressed():
	if is_request_running:
		return

	is_guest_mode = true

	token_input.text = "guest"
	age_input.text = ""
	age_input.editable = false

	var data = {
		"token": "guest",
		"age": ""
	}

	pending_login_data = data.duplicate(true)

	is_request_running = true
	status_label.text = "Mode invité..."

	var err = http.request(
		BASE_URL + "user/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

	if err != OK:
		_offline_login(data)

# -------- HTTP RESPONSE --------
func _on_http_request_request_completed(result, response_code, headers, body):
	is_request_running = false

	if is_generating_token:
		is_generating_token = false

		if result != HTTPRequest.RESULT_SUCCESS:
			status_label.text = "Erreur réseau"
			set_ui_locked(false)   # ← déverrouille en cas d'échec réseau
			return

		var body_text = body.get_string_from_utf8()
		if _is_token_available(response_code, body_text):
			token_input.text = generated_token
			status_label.text = "Token généré ✔"
			set_ui_locked(false)   # ← déverrouille après succès
		else:
			# Token déjà pris → réessaye (reste verrouillé)
			_try_generate_token()

		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_offline_login(pending_login_data)
		return

	if response_code != 200 and response_code != 201:
		_offline_login(pending_login_data)
		return

	var response = JSON.parse_string(body.get_string_from_utf8())

	if typeof(response) != TYPE_DICTIONARY or not response.has("id"):
		_offline_login(pending_login_data)
		return

	var user_id = int(response["id"])

	if is_guest_mode:
		PlayerData.set_guest(user_id)
		PlayerData.token = "guest"
		PlayerData.uuid = "none"
		PlayerData.age = ""
	else:
		var resolved_uuid = str(response.get("uuid", pending_login_data.get("uuid", get_device_uuid())))

		var age = pending_login_data.get("age", "")
		if str(age).is_valid_int():
			age = int(age)

		PlayerData.set_user(
			user_id,
			resolved_uuid,
			str(pending_login_data.get("token")),
			age
		)

		PlayerData.age = age

	PlayerData.print_data()
	GestionFichier.save_data()
	pending_login_data.clear()

	call_deferred("_go_to_menu")

# -------- OFFLINE --------
func _offline_login(data):
	var local_id = 1 if is_guest_mode else randi() % 1000000

	if is_guest_mode:
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
			age
		)

		PlayerData.age = age

	SyncManager.add_action({
		"type": "login",
		"data": data
	})

	status_label.text = "Mode hors ligne"

	PlayerData.print_data()
	GestionFichier.save_data()
	pending_login_data.clear()

	call_deferred("_go_to_menu")

# -------- NAV --------
func _go_to_menu():
	var interface = get_tree().get_meta("interface")

	print("[USER MENU] Navigation after login | first_login:", first_login)

	if interface:
		if first_login:
			interface.show_menu()
		else:
			interface.show_menu()

func _on_back_button_pressed():
	if first_login:
		print("[USER MENU] Back disabled (first login)")
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
