extends Control

const LOG_TAG := "[MainMenu]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

@onready var start_button = $MarginContainer/VBoxContainer/CenterContainer/VBoxContainer/StartButton
const INITIAL_SYNC_TIMEOUT_SECONDS := 3.0


func _ready():
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)

	start_button.disabled = true

	await sync_before_play()

	start_button.disabled = false

func sync_before_play():
	_log("Initial sync started")
	var sync_start = Time.get_ticks_msec()
	SyncManager.force_sync()

	var deadline := Time.get_ticks_msec() + int(INITIAL_SYNC_TIMEOUT_SECONDS * 1000.0)

	while not SyncManager.sync_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	var elapsed = Time.get_ticks_msec() - sync_start
	
	if not SyncManager.sync_done:
		push_warning("Initial sync timed out. Continuing in background.")
		_log("Initial sync timeout | elapsed_ms=%s" % str(elapsed))
	else:
		_log("Initial sync done | elapsed_ms=%s" % str(elapsed))

func _on_start_pressed():
	PlayerData.print_data()

	if PlayerData.user_id == -1:
		_log("Start blocked: no user, redirect to user menu")
		get_tree().get_meta("interface").show_user()
		return

	var transition = get_tree().get_first_node_in_group("transition")

	if transition:
		transition.go_to_scene("game")
	else:
		get_tree().get_meta("interface").show_game()

func _on_start_button_pressed():
	_on_start_pressed()


func _on_option_button_pressed():
	get_tree().get_meta("interface").show_options()

func _on_user_button_pressed():
	get_tree().get_meta("interface").show_user()

func _on_quit_button_pressed():
	GestionFichier.save_data()
	get_tree().quit()

func _on_gdpr_button_pressed() -> void:
	get_tree().get_meta("interface").show_gdpr(true)
