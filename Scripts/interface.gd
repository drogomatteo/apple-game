extends Control

@onready var container = $Container

var menu_scene = preload("res://Scenes/main_menu.tscn")
var options_scene = preload("res://Scenes/option_menu.tscn")
var user_scene = preload("res://Scenes/user_menu.tscn")
var game_scene = preload("res://Scenes/main.tscn")
var rgpd_scene = preload("res://Scenes/gdpr_menu.tscn")

var current_scene = null


func _ready():
	print("[UI] Ready → setting interface meta")
	get_tree().set_meta("interface", self)
	show_menu()


func clear():
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	else:
		print("[UI] Nothing to clear")


func show_menu():
	print("[UI] Main Menu")
	clear()
	await get_tree().process_frame
	current_scene = menu_scene.instantiate()
	container.add_child(current_scene)


func show_options():
	print("[UI] Option Menu")
	clear()
	current_scene = options_scene.instantiate()
	container.add_child(current_scene)


func show_user():
	print("[UI] User Menu")
	clear()
	current_scene = user_scene.instantiate()
	container.add_child(current_scene)


func show_game():
	print("[UI] Apple Game")
	clear()
	current_scene = game_scene.instantiate()
	container.add_child(current_scene)
	

func show_gdpr():
	print("[UI] GDPR Menu")
	clear()
	current_scene = rgpd_scene.instantiate()
	current_scene.force_show = true
	container.add_child(current_scene)
