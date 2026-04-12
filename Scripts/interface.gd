extends Control

@onready var container = $Container

var menu_scene = preload("res://Scenes/main_menu.tscn")
var options_scene = preload("res://Scenes/option_menu.tscn")
var user_scene = preload("res://Scenes/user_menu.tscn")

var current_scene = null


func _ready():
	get_tree().set_meta("interface", self)
	GestionFichier.load_game()
	show_menu()


func clear():
	for child in container.get_children():
		child.queue_free()


func show_menu():
	clear()
	await get_tree().process_frame
	current_scene = menu_scene.instantiate()
	container.add_child(current_scene)


func show_options():
	clear()
	await get_tree().process_frame
	current_scene = options_scene.instantiate()
	container.add_child(current_scene)


func show_user():
	clear()
	await get_tree().process_frame
	current_scene = user_scene.instantiate()
	container.add_child(current_scene)
