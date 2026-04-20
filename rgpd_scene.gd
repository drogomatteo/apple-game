extends Control

@onready var checkbox = $CenterContainer/VBoxContainer/CheckBox
@onready var continue_button = $CenterContainer/VBoxContainer/ContinueButton

var force_show := false 
var first_login_flow := false
var opened_from_menu := false
var is_applying_refusal := false


func _ready():
	print("[UI][RGPD] Scene loaded")
	print("[UI][RGPD] first_login_flow:", first_login_flow, "opened_from_menu:", opened_from_menu)

	var accepted = SaveRgpd.is_accepted()
	print("[UI][RGPD] Accepted state from save:", accepted)

	if accepted and not force_show:
		print("[UI][RGPD] Already accepted → skip to menu")
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
		print("[UI][RGPD] Continue blocked: checkbox not checked")
		continue_button.disabled = true
		return

	SaveRgpd.set_accepted(true)
	print("[UI][RGPD] Saved accepted = true")

	_go_next_screen()


func _on_refuse_button_pressed():
	if first_login_flow:
		print("[UI][RGPD] First login: refusal keeps user on GDPR")
		checkbox.button_pressed = false
		continue_button.disabled = true
		return

	_apply_refusal_flow()


func _apply_refusal_flow() -> void:
	if is_applying_refusal:
		return
	is_applying_refusal = true

	SaveRgpd.set_accepted(false)
	print("[UI][RGPD] Saved accepted = false")

	continue_button.disabled = true

	if checkbox.button_pressed:
		checkbox.button_pressed = false

	print("[UI][RGPD] Consent refused/removed: logout user")
	PlayerData.logout_user()
	GestionFichier.save_data()

	var interface = get_tree().get_meta("interface")
	if interface:
		interface.first_login_flow = true
		print("[RGPD] Redirect after refusal → GDPR (first login flow)")
		interface.call_deferred("show_gdpr")
	else:
		print("[RGPD] Fallback after refusal → reload Interface")
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	call_deferred("queue_free")


func _go_next_screen():
	var interface = get_tree().get_meta("interface")

	if interface:
		if opened_from_menu:
			print("[RGPD] Redirect → MainMenu")
			interface.call_deferred("show_menu")
		else:
			print("[RGPD] Redirect → UserMenu")
			interface.call_deferred("show_user")
	else:
		print("[RGPD] Fallback → reload Interface")
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	call_deferred("queue_free")
