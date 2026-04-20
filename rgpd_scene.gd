extends Control

const LOG_TAG := "[GDPR]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

@onready var checkbox = $CenterContainer/VBoxContainer/CheckBox
@onready var continue_button = $CenterContainer/VBoxContainer/ContinueButton

var force_show := false 
var first_login_flow := false
var opened_from_menu := false
var is_applying_refusal := false


func _ready():
	var accepted = SaveRgpd.is_accepted()

	if accepted and not force_show:
		_log("Consent already accepted, skipping screen")
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
		_log("Continue blocked: checkbox not checked")
		continue_button.disabled = true
		return

	SaveRgpd.set_accepted(true)
	_log("Consent accepted")

	_go_next_screen()


func _on_refuse_button_pressed():
	if first_login_flow:
		_log("Refuse during first login: stay on GDPR")
		checkbox.button_pressed = false
		continue_button.disabled = true
		return

	_apply_refusal_flow()


func _apply_refusal_flow() -> void:
	if is_applying_refusal:
		return
	is_applying_refusal = true

	SaveRgpd.set_accepted(false)
	_log("Consent refused/removed, forcing logout")

	continue_button.disabled = true

	if checkbox.button_pressed:
		checkbox.button_pressed = false
	PlayerData.logout_user()
	GestionFichier.save_data()

	var interface = get_tree().get_meta("interface")
	if interface:
		interface.first_login_flow = true
		_log("Redirect after refusal -> GDPR (first login flow)")
		interface.call_deferred("show_gdpr")
	else:
		_log("Fallback transition -> Interface scene")
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	call_deferred("queue_free")


func _go_next_screen():
	var interface = get_tree().get_meta("interface")

	if interface:
		if opened_from_menu:
			_log("Redirect -> main_menu")
			interface.call_deferred("show_menu")
		else:
			_log("Redirect -> user_menu")
			interface.call_deferred("show_user")
	else:
		_log("Fallback transition -> Interface scene")
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	call_deferred("queue_free")
