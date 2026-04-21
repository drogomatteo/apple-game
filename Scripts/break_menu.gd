extends Control

@onready var resume_button = $ResumeButton
@onready var back_button = $BackButton

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.process_mode = Node.PROCESS_MODE_ALWAYS

func open():
	get_tree().paused = true
	visible = true


func close():
	get_tree().paused = false
	visible = false


func _on_resume_button_pressed() -> void:
	close()
	var break_button = get_tree().get_first_node_in_group("break_button")
	if break_button:
		break_button.visible = true


func _on_back_button_pressed() -> void:
	get_tree().paused = false
	Transition.go_to_scene("main_menu")
