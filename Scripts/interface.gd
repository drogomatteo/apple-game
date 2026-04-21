extends Control

const LOG_TAG := "[Interface]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

@onready var container = $Container

var menu_scene = preload("res://Scenes/main_menu.tscn")
var options_scene = preload("res://Scenes/option_menu.tscn")
var user_scene = preload("res://Scenes/user_menu.tscn")
var game_scene = preload("res://Scenes/main.tscn")
var rgpd_scene = preload("res://Scenes/gdpr_menu.tscn")

var current_scene = null
var first_login_flow := false

func _ready():
	get_tree().set_meta("interface", self)
	
	var accepted = SaveRgpd.is_accepted()
	var connected = PlayerData.user_id != -1
	_log("Boot flow | accepted=%s connected=%s" % [str(accepted), str(connected)])

	if not accepted:
		first_login_flow = true
		show_gdpr()
		return

	if not connected:
		first_login_flow = true
		show_user()
		return

	show_menu()


func clear():
	if current_scene:
		current_scene.queue_free()
		current_scene = null


func show_menu():
	first_login_flow =false
	_log("Transition -> main_menu")
	clear()
	await get_tree().process_frame
	current_scene = menu_scene.instantiate()
	container.add_child(current_scene)


func show_options():
	_log("Transition -> option_menu")
	clear()
	current_scene = options_scene.instantiate()
	container.add_child(current_scene)


func show_user():
	_log("Transition -> user_menu | first_login=%s" % str(first_login_flow))
	clear()
	current_scene = user_scene.instantiate()
	current_scene.first_login = first_login_flow
	container.add_child(current_scene)


func show_game():
	_log("Transition -> game")
	clear()
	current_scene = game_scene.instantiate()
	container.add_child(current_scene)
	

func show_gdpr(opened_from_menu: bool = false):
	_log("Transition -> gdpr_menu | from_menu=%s" % str(opened_from_menu))
	clear()
	current_scene = rgpd_scene.instantiate()
	current_scene.force_show = true
	current_scene.first_login_flow = first_login_flow
	current_scene.opened_from_menu = opened_from_menu
	container.add_child(current_scene)
