extends Control

@onready var checkbox = $CenterContainer/VBoxContainer/CheckBox
@onready var continue_button = $CenterContainer/VBoxContainer/ContinueButton

var force_show := false 


func _ready():
	print("[UI][RGPD] Scene loaded")

	var accepted = SaveRgpd.is_accepted()
	print("[UI][RGPD] Accepted state from save:", accepted)

	if accepted and not force_show:
		print("[UI][RGPD] Already accepted → skip to menu")
		call_deferred("_go_to_menu")
		return

	checkbox.button_pressed = accepted
	continue_button.disabled = not accepted


func _on_check_box_toggled(pressed: bool):
	continue_button.disabled = not pressed


func _on_continue_button_pressed():
	SaveRgpd.set_accepted(true)
	print("[UI][RGPD] Saved accepted = true")

	_go_to_menu()


func _on_refuse_button_pressed():
	SaveRgpd.set_accepted(false)
	print("[UI][RGPD] Saved accepted = false")

	checkbox.button_pressed = false
	continue_button.disabled = true

	print("[UI][RGPD] Logging out user")
	PlayerData.logout_user()
	GestionFichier.save_data()


func _go_to_menu():
	if get_parent() and get_parent().get_parent():
		get_parent().get_parent().call_deferred("show_menu")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	call_deferred("queue_free")
