extends Control

@onready var pseudo_input = $CenterContainer/VBoxContainer/PseudoInput
@onready var token_input = $CenterContainer/VBoxContainer/TokenInput
@onready var save_button = $CenterContainer/VBoxContainer/SaveButton
@onready var guest_button = $CenterContainer/VBoxContainer/GuestButton
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel


func _ready():

	if PlayerData.user_id != -1:
		pseudo_input.text = PlayerData.pseudo
		token_input.text = PlayerData.token

	update_button()


func _on_input_changed(_t=""):
	update_button()


func update_button():
	var pseudo = pseudo_input.text.strip_edges()
	var token = token_input.text.strip_edges()

	save_button.disabled = (pseudo == "" or token == "")


func _on_save_pressed():
	PlayerData.set_user(0, pseudo_input.text, token_input.text)
	GestionFichier.save_data()
	get_tree().get_meta("interface").show_menu()


func _on_guest_pressed():
	PlayerData.set_guest(0)
	GestionFichier.save_data()
	get_tree().get_meta("interface").show_menu()


func _on_back_button_pressed():
	print("BACK CLICK")
	get_tree().get_meta("interface").show_menu()
