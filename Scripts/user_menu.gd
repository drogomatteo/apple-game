extends Control

@onready var http = $HTTPRequest
@onready var pseudo_input = $VBoxContainer/PseudoInput
@onready var token_input = $VBoxContainer2/TokenInput
@onready var save_button = $CenterContainer/VBoxContainer/SaveButton
@onready var guest_button = $CenterContainer/VBoxContainer/GuestButton
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var back_button = $BackButton

var BASE_URL = "http://100.111.28.32:8000/api/"
var is_request_running = false
var is_guest_mode = false


func _ready():
	if PlayerData.user_id != -1:
		pseudo_input.text = PlayerData.pseudo
		token_input.text = PlayerData.token

	update_button()


func _on_input_changed(_text=""):
	update_button()


func update_button():
	var pseudo = pseudo_input.text.strip_edges()
	var token = token_input.text.strip_edges()

	if token != "" and pseudo.to_lower() == "guest":
		save_button.disabled = true
		status_label.text = "Pseudo invalide avec une clé patient"
		return

	save_button.disabled = (pseudo == "" or token == "")

	if pseudo != "" and token != "":
		status_label.text = ""


func _on_save_button_pressed():
	if is_request_running:
		return

	is_guest_mode = false

	var pseudo = pseudo_input.text.strip_edges()
	var token = token_input.text.strip_edges()

	if token != "" and pseudo.to_lower() == "guest":
		status_label.text = "Pseudo invalide avec une clé patient"
		return

	if pseudo == "" or token == "":
		status_label.text = "Pseudo et clé médecin obligatoires"
		return

	var data = {
		"pseudo": pseudo,
		"token": token
	}

	var body = JSON.stringify(data)

	is_request_running = true
	status_label.text = "Connexion..."

	http.request(
		BASE_URL + "user/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)


func _on_guest_button_pressed():
	if is_request_running:
		return

	is_guest_mode = true

	is_request_running = true
	status_label.text = "Mode invité..."

	http.request(
		BASE_URL + "user/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		"{}"
	)


func _on_http_request_request_completed(result, response_code, headers, body):
	is_request_running = false

	var text = body.get_string_from_utf8()
	print("CODE:", response_code)
	print("RAW:", text)

	var response = JSON.parse_string(text)

	if response_code != 200 and response_code != 201:
		status_label.text = "Erreur serveur"
		return

	if typeof(response) != TYPE_DICTIONARY:
		status_label.text = "Réponse invalide"
		return

	var user_data = response

	if "user" in response:
		user_data = response["user"]

	if not user_data.has("id"):
		status_label.text = "ID manquant"
		return

	var user_id = user_data["id"]
	var pseudo_backend = user_data.get("pseudo", "Guest")

	if is_guest_mode:
		PlayerData.set_guest(user_id)
		status_label.text = "Mode invité ✔"
	else:
		PlayerData.set_user(
			user_id,
			pseudo_backend,
			token_input.text.strip_edges()
		)

		if pseudo_backend != pseudo_input.text:
			pseudo_input.text = pseudo_backend

	PlayerData.print_data()

	GestionFichier.save_data()

	call_deferred("_go_to_menu")


func _go_to_menu():
	var interface = get_tree().get_meta("interface")
	if interface:
		interface.show_menu()


func _on_back_button_pressed():
	get_tree().get_meta("interface").show_menu()
