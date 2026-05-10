extends Control

const INITIAL_SYNC_TIMEOUT_SECONDS := 3.0

@onready var start_button := $MarginContainer/VBoxContainer/CenterContainer/VBoxContainer/StartButton


func _ready() :
	start_button.disabled = true
	await sync()
	start_button.disabled = false


func get_interface() -> Node:
	return get_tree().get_meta("interface")


func sync() :
	SyncManager.force_sync()

	var deadline := Time.get_ticks_msec() + int(INITIAL_SYNC_TIMEOUT_SECONDS * 1000.0)

	while not SyncManager.sync_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	if not SyncManager.sync_done:
		push_warning("Initial sync timed out. Continuing in background.")


func start_game() -> void:
	if PlayerData.user_id == -1:
		get_interface().show_user()
		return

	var transition := get_tree().get_first_node_in_group("transition")
	if transition != null:
		transition.go_to_scene("game")
		return

	get_interface().show_game()


func _on_start_button_pressed() :
	start_game()


func _on_option_button_pressed() :
	get_interface().show_options()


func _on_user_button_pressed() :
	get_interface().show_user()


func _on_quit_button_pressed() :
	FileManager.save_game()
	get_tree().quit()


func _on_gdpr_button_pressed() :
	get_interface().show_gdpr(true)


func _on_info_button_pressed() :
	get_interface().show_info()
