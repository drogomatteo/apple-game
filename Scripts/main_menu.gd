extends Control

@onready var start_button = $MarginContainer/VBoxContainer/CenterContainer/VBoxContainer/StartButton
const INITIAL_SYNC_TIMEOUT_SECONDS := 3.0


func _ready():
	print("[UI][MainMenu] ready")

	start_button.disabled = true
	print("[UI][MainMenu] start_button disabled → starting sync")

	await sync_before_play()

	start_button.disabled = false
	print("[UI][MainMenu] start_button enabled → ready to play")

func sync_before_play():

	var sync_start = Time.get_ticks_msec()
	SyncManager.force_sync()

	var deadline := Time.get_ticks_msec() + int(INITIAL_SYNC_TIMEOUT_SECONDS * 1000.0)

	while not SyncManager.sync_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	var elapsed = Time.get_ticks_msec() - sync_start
	
	if not SyncManager.sync_done:
		print("[UI][MainMenu] WARNING: Sync timeout! Time elapsed:", elapsed, "ms")
		push_warning("Initial sync timed out. Continuing in background.")
	else:
		print("[UI][MainMenu] Sync successful! Time:", elapsed, "ms")

func _on_start_pressed():
	print("----- USER DEBUG -----")
	PlayerData.print_data()

	if PlayerData.user_id == -1:
		print("[UI][MainMenu] No user → redirect to user menu")
		get_tree().get_meta("interface").show_user()
		return

	var transition = get_tree().get_first_node_in_group("transition")

	if transition:
		transition.go_to_scene("game")
	else:
		print("[UI][MainMenu] No transition → direct show_game()")
		get_tree().get_meta("interface").show_game()

func _on_start_button_pressed():
	_on_start_pressed()

func _on_option_button_pressed():
	get_tree().get_meta("interface").show_options()

func _on_user_button_pressed():
	get_tree().get_meta("interface").show_user()

func _on_quit_button_pressed():
	print("[UI][MainMenu] Quit button pressed → saving data and exiting")
	GestionFichier.save_data()
	get_tree().quit()

func _on_gdpr_button_pressed() -> void:
	get_tree().get_meta("interface").show_gdpr(true)
