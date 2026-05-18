extends Node

const BUTTON_SOUND := preload("res://Assets/Sound/Buttons.mp3")

var audio_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	audio_player = AudioStreamPlayer.new()
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_player.stream = BUTTON_SOUND
	add_child(audio_player)

	get_tree().node_added.connect(_on_node_added)
	_connect_buttons(get_tree().root)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)


func _connect_buttons(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)

	for child in node.get_children():
		_connect_buttons(child)


func _connect_button(button: BaseButton) -> void:
	if _should_ignore_button(button):
		return

	var callback := Callable(self, "_play_button_sound").bind(button)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _play_button_sound(button: BaseButton) -> void:
	if not is_instance_valid(button) or _should_ignore_button(button):
		return

	if not Settings.sound:
		return

	audio_player.stop()
	audio_player.play()


func _should_ignore_button(button: BaseButton) -> bool:
	var current: Node = button
	while current:
		if current.name == "TutorialUI":
			return true
		current = current.get_parent()

	return false
