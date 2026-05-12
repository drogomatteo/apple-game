extends Control

const MENU_SCENE := preload("res://Scenes/main_menu.tscn")
const OPTIONS_SCENE := preload("res://Scenes/option_menu.tscn")
const USER_SCENE := preload("res://Scenes/user_menu.tscn")
const GAME_SCENE := preload("res://Scenes/main.tscn")
const GDPR_SCENE := preload("res://Scenes/gdpr_menu.tscn")
const INFO_SCENE := preload("res://Scenes/info_menu.tscn")

@onready var container := $Container

var current_scene: Node = null
var first_login: bool = false


func _ready() :
	get_tree().set_meta("interface", self)

	var accepted := Settings.get_rgpd_accepted()
	var connected := PlayerData.user_id != -1

	if not accepted:
		first_login = true
		show_gdpr()
	elif not connected:
		first_login = true
		show_user()
	else:
		show_menu()


func show_scene(scene: Node) :
	if scene == null:
		push_error("Could not show scene: scene is null.")
		return

	if current_scene != null:
		current_scene.queue_free()

	current_scene = scene
	container.add_child(current_scene)


func show_menu() :
	first_login = false
	show_scene(MENU_SCENE.instantiate())


func show_options() :
	show_scene(OPTIONS_SCENE.instantiate())


func show_user() :
	var scene := USER_SCENE.instantiate()
	scene.first_login = first_login
	show_scene(scene)


func show_game() :
	show_scene(GAME_SCENE.instantiate())


func show_gdpr(opened_from_menu: bool = false) :
	var scene := GDPR_SCENE.instantiate()
	scene.force_show = true
	scene.first_login = first_login
	scene.opened_from_menu = opened_from_menu
	show_scene(scene)


func show_info() :
	show_scene(INFO_SCENE.instantiate())
