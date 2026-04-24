extends Control

@onready var checkbox = $MarginContainer/CenterContainer/MarginContainer/VBoxContainer/CheckBox
@onready var continue_button = $MarginContainer/CenterContainer/MarginContainer/VBoxContainer/HBoxContainer/ContinueButton

var force_show := false 
var first_login_flow := false
var opened_from_menu := false
var is_applying_refusal := false

func _get_interface():
	if get_tree().has_meta("interface"):
		return get_tree().get_meta("interface")
	return null


func _ready():
	var accepted = SaveRgpd.is_accepted()

	if accepted and not force_show:
		call_deferred("_go_next_screen")
		return

	checkbox.button_pressed = accepted
	continue_button.disabled = not accepted


func _on_check_box_toggled(pressed: bool):
	continue_button.disabled = not pressed
	if is_applying_refusal:
		return
	if not first_login_flow and not pressed:
		_apply_refusal_flow()


func _on_continue_button_pressed():
	if not checkbox.button_pressed:
		continue_button.disabled = true
		return

	SaveRgpd.set_accepted(true, true)

	_go_next_screen()


func _on_refuse_button_pressed():
	if first_login_flow:
		checkbox.button_pressed = false
		continue_button.disabled = true
		return

	_apply_refusal_flow()


func _apply_refusal_flow() -> void:
	if is_applying_refusal:
		return
	is_applying_refusal = true

	SaveRgpd.set_accepted(false, true)

	continue_button.disabled = true

	if checkbox.button_pressed:
		checkbox.button_pressed = false
	PlayerData.logout_user()
	GestionFichier.save_data()

	var interface = _get_interface()
	if interface:
		interface.first_login_flow = true
		interface.show_gdpr()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	queue_free()


func _go_next_screen():
	var interface = _get_interface()

	if interface:
		if opened_from_menu:
			interface.show_menu()
		else:
			interface.show_user()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	queue_free()
