extends Control

@onready var checkbox := $MarginContainer/CenterContainer/MarginContainer/VBoxContainer/CheckBox
@onready var continue_button := $MarginContainer/CenterContainer/MarginContainer/VBoxContainer/HBoxContainer/ContinueButton

var force_show: bool = false
var first_login: bool = false
var opened_from_menu: bool = false
var is_refusing: bool = false


func _ready() -> void:
	var accepted := Settings.get_rgpd_accepted()

	if accepted and not force_show:
		go_next_screen()
		return

	checkbox.button_pressed = accepted
	continue_button.disabled = not accepted


func get_interface() -> Node:
	if get_tree().has_meta("interface"):
		return get_tree().get_meta("interface")

	return null

func refuse_gdpr() -> void:
	if is_refusing:
		return

	is_refusing = true

	Settings.set_rgpd_accepted(false)
	FileManager.save_game()

	checkbox.button_pressed = false
	continue_button.disabled = true

	var interface := get_interface()

	if interface != null:
		interface.first_login_flow = true
		interface.show_gdpr()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	queue_free()


func go_next_screen() -> void:
	var interface := get_interface()

	if interface != null:
		if opened_from_menu:
			interface.show_menu()
		else:
			interface.show_user()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	queue_free()

func _on_check_box_toggled(pressed: bool) -> void:
	continue_button.disabled = not pressed

	if is_refusing:
		return

	if not first_login and not pressed:
		refuse_gdpr()


func _on_continue_button_pressed() -> void:
	if not checkbox.button_pressed:
		continue_button.disabled = true
		return

	Settings.set_rgpd_accepted(true)
	go_next_screen()


func _on_refuse_button_pressed() -> void:
	if first_login:
		checkbox.button_pressed = false
		continue_button.disabled = true
		return

	refuse_gdpr()
