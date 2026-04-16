extends Control

@onready var checkbox = $CenterContainer/VBoxContainer/CheckBox
@onready var continue_button = $CenterContainer/VBoxContainer/ContinueButton

var force_show := false 


func _ready():
	print("[RGPD] Scene loaded")

	var accepted = SaveRgpd.is_accepted()


	if accepted and not force_show:
		print("[RGPD] Already accepted → skip")
		call_deferred("_go_to_menu()")
		return

	checkbox.button_pressed = accepted
	continue_button.disabled = not accepted


func _on_check_box_toggled(pressed: bool):
	continue_button.disabled = not pressed


func _on_continue_button_pressed():
	print("[RGPD] Accepted")

	SaveRgpd.set_accepted(true)
	_go_to_menu()


func _on_refuse_button_pressed():
	print("[RGPD] Refused")

	SaveRgpd.set_accepted(false)

	checkbox.button_pressed = false
	continue_button.disabled = true

	PlayerData.logout_user()
	GestionFichier.save_data()


func _go_to_menu():
	print("[NAV] Back to menu")
	if get_parent() and get_parent().get_parent():
		get_parent().get_parent().call_deferred("show_menu")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	call_deferred("queue_free") 

	
