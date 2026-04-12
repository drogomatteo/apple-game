extends Control

@onready var container = $Container

var menu_scene = preload("res://Scenes/main_menu.tscn")
var options_scene = preload("res://Scenes/option_menu.tscn")
var user_scene = preload("res://Scenes/user_menu.tscn")
var game_scene = preload("res://Scenes/main.tscn")

var current_scene = null


func _ready():
	get_tree().set_meta("interface", self)
	show_menu()


func clear():
	if current_scene:
		current_scene.queue_free()
		current_scene = null


func show_menu():
	clear()
	await get_tree().process_frame
	current_scene = menu_scene.instantiate()
	container.add_child(current_scene)


func show_options():
	clear()
	current_scene = options_scene.instantiate()
	container.add_child(current_scene)


func show_user():
	clear()
	current_scene = user_scene.instantiate()
	container.add_child(current_scene)


func show_game():
	clear()
	current_scene = game_scene.instantiate()
	container.add_child(current_scene)
