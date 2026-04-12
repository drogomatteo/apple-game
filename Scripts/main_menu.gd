extends Control

func _ready():
	print("MAIN MENU READY")
	
func _on_start_button_pressed():
	if PlayerData.user_id == -1:
		get_tree().get_meta("interface").show_user()
	else:
		Transition.go_to_scene("main")


func _on_option_button_pressed():
	var interface = get_tree().get_meta("interface")
	interface.show_options()

func _on_user_button_pressed():
	var interface = get_tree().get_meta("interface")
	interface.show_user()


func _on_quit_button_pressed():
	GestionFichier.save_data()
	get_tree().quit()
