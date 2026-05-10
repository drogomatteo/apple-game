extends Control

@onready var resume_button := $VBoxContainer/ResumeButton
@onready var back_button := $VBoxContainer/BackButton
@onready var menu_container := get_parent()

func _ready() :
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.process_mode = Node.PROCESS_MODE_ALWAYS

	if menu_container:
		menu_container.visible = false


func open() :
	get_tree().paused = true
	visible = true

	if menu_container:
		menu_container.visible = true


func close() :
	get_tree().paused = false
	visible = false

	if menu_container:
		menu_container.visible = false

func _on_resume_button_pressed() :
	close()

	var break_button := get_tree().get_first_node_in_group("break_button")
	if break_button:
		break_button.visible = true

func _on_back_button_pressed():
	close()
	Transition.go_to_scene("main_menu")
