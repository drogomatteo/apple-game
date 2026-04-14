extends Control

@onready var http = $HTTPRequest
@onready var token_input = $VBoxContainer/TokenInput
@onready var save_button = $CenterContainer/VBoxContainer/SaveButton
@onready var guest_button = $CenterContainer/VBoxContainer/GuestButton
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var back_button = $BackButton

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/"
var is_request_running = false
var is_guest_mode = false


func _ready():
	print("[INIT] User menu loaded")

	if PlayerData.user_id != -1:
		token_input.text = PlayerData.token

	update_button()


func _on_input_changed(_text=""):
	update_button()


func update_button():
	var token = token_input.text.strip_edges()

	save_button.disabled = (token == "")

	if token != "":
		status_label.text = ""


func get_device_uuid() -> String:
	var uuid = OS.get_unique_id()
	print("[UUID] Device UUID:", uuid)
	return uuid


func _on_save_button_pressed():
	if is_request_running:
		return

	is_guest_mode = false

	var token = token_input.text.strip_edges()

	print("[LOGIN] Token entered:", token)

	if token == "":
		status_label.text = "Token requis"
		return

	if token.to_lower() == "guest":
		print("[LOGIN] Guest token detected → switching to guest mode")
		_on_guest_button_pressed()
		return

	var uuid = get_device_uuid()

	var data = {
		"token": token,
		"uuid": uuid
	}

	print("[LOGIN] Sending data:", data)

	is_request_running = true
	status_label.text = "Connexion..."

	var err = http.request(
		BASE_URL + "user/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

	if err != OK:
		print("[ERROR] HTTP request failed")
		_offline_login(data)


func _on_guest_button_pressed():
	if is_request_running:
		return

	is_guest_mode = true

	print("[LOGIN] Guest mode activated")

	var data = {
		"token": "guest"
	}

	is_request_running = true
	status_label.text = "Mode invité..."

	var err = http.request(
		BASE_URL + "user/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

	if err != OK:
		print("[ERROR] Guest request failed")
		_offline_login(data)


func _on_http_request_request_completed(result, response_code, headers, body):
	is_request_running = false

	print("[HTTP] Response code:", response_code)

	if response_code != 200 and response_code != 201:
		print("[ERROR] Bad response → offline mode")
		_offline_login({"token": token_input.text.strip_edges()})
		return

	var text = body.get_string_from_utf8()
	print("[HTTP] Response body:", text)

	var response = JSON.parse_string(text)

	if typeof(response) != TYPE_DICTIONARY:
		print("[ERROR] Invalid JSON")
		_offline_login({"token": token_input.text.strip_edges()})
		return

	if not response.has("id"):
		print("[ERROR] No ID in response")
		_offline_login({"token": token_input.text.strip_edges()})
		return

	var user_id = response["id"]

	print("[SUCCESS] Connected → user_id:", user_id)

	if is_guest_mode:
		PlayerData.set_guest(1) 
		status_label.text = "Mode invité ✔"
	else:
		PlayerData.set_user(
			user_id,
			"", 
			token_input.text.strip_edges()
		)
		status_label.text = "Connecté ✔"

	PlayerData.print_data()
	GestionFichier.save_data()

	call_deferred("_go_to_menu")


func _offline_login(data):
	print("[OFFLINE] Using offline mode")

	var local_id = 1 if is_guest_mode else randi() % 1000000

	if is_guest_mode:
		PlayerData.set_guest(local_id)
	else:
		PlayerData.set_user(local_id, "", data["token"])

	SyncManager.add_action({
		"type": "login",
		"data": data
	})

	status_label.text = "Mode hors ligne"

	PlayerData.print_data()
	GestionFichier.save_data()

	call_deferred("_go_to_menu")


func _go_to_menu():
	print("[NAV] Going to menu")

	var interface = get_tree().get_meta("interface")
	if interface:
		interface.show_menu()


func _on_back_button_pressed():
	print("[NAV] Back button pressed")
	get_tree().get_meta("interface").show_menu()
