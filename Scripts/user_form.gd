extends Control

@onready var http = $HTTPRequest
@onready var pseudo_input = $VBoxContainer/PseudoInput
@onready var token_input = $VBoxContainer/TokenInput
@onready var play_button = $VBoxContainer/PlayButton
@onready var guest_button = $VBoxContainer/GuestButton
@onready var status_label = $VBoxContainer/StatusLabel

var BASE_URL = "http://193.190.211.21:8000/"
var is_request_running = false

func _ready():
	http.request_completed.connect(_on_request_completed)
	play_button.disabled = true
	status_label.text = ""

func _on_input_changed(_text):
	var pseudo = pseudo_input.text.strip_edges()
	var token = token_input.text.strip_edges()
	if pseudo == "" or token == "":
		play_button.disabled = true
		status_label.text = "Pseudo et token obligatoires"
	else:
		play_button.disabled = false
		status_label.text = ""

func _on_play_button_pressed():
	if is_request_running:
		return
	var pseudo = pseudo_input.text.strip_edges()
	var token = token_input.text.strip_edges()
	if pseudo == "" or token == "":
		status_label.text = "Pseudo et token obligatoires"
		return
	var data = {
		"pseudo": pseudo,
		"token": token
	}
	var json = JSON.stringify(data)
	var body = json.to_utf8_buffer()
	is_request_running = true
	status_label.text = "Création du compte..."
	http.request(
		BASE_URL + "user/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

func _on_guest_button_pressed():
	if is_request_running:
		return
	is_request_running = true
	status_label.text = "Mode guest..."
	http.request(
		BASE_URL + "user/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		"{}".to_utf8_buffer()
	)

func _on_request_completed(result, response_code, headers, body):
	is_request_running = false
	if response_code != 200 and response_code != 201:
		status_label.text = "Erreur serveur (" + str(response_code) + ")"
		print(body.get_string_from_utf8())
		return
	var response = JSON.parse_string(body.get_string_from_utf8())
	if response == null or not ("id" in response):
		status_label.text = "Réponse invalide"
		return
	var user_id = response["id"]
	if pseudo_input.text.strip_edges() != "" and token_input.text.strip_edges() != "":
		PlayerData.set_user(
			user_id,
			pseudo_input.text.strip_edges(),
			token_input.text.strip_edges()
		)
	else:
		PlayerData.set_guest(user_id)
	PlayerData.print_data()
	status_label.text = "Compte créé !"
	await get_tree().create_timer(0.5).timeout
	Transition.go_to_scene("main")
