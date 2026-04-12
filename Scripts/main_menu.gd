extends Control

@onready var start_button = $MarginContainer/VBoxContainer/CenterContainer/VBoxContainer/StartButton


func _ready():
	start_button.disabled = true
	await sync_before_play()
	start_button.disabled = false
	start_button.pressed.connect(_on_start_pressed)


func sync_before_play():
	SyncManager.force_sync()

	while not SyncManager.sync_done:
		await get_tree().process_frame


func _on_start_pressed():

	print("----- USER DEBUG -----")
	print("ID:", PlayerData.user_id)
	print("Pseudo:", PlayerData.pseudo)
	print("Guest:", PlayerData.is_guest)
	print("----------------------")

	if PlayerData.user_id == -1:
		get_tree().get_meta("interface").show_user()
		return
	
	Transition.go_to_scene("game")


func _on_option_button_pressed():
	get_tree().get_meta("interface").show_options()


func _on_user_button_pressed():
	get_tree().get_meta("interface").show_user()


func _on_quit_button_pressed():
	GestionFichier.save_data()
	get_tree().quit()
