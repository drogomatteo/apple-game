extends Control

const LOG_TAG := "[Interface]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

# -------- NODES --------
@onready var container = $Container

# -------- SCENES --------
var menu_scene = preload("res://Scenes/main_menu.tscn")
var options_scene = preload("res://Scenes/option_menu.tscn")
var user_scene = preload("res://Scenes/user_menu.tscn")
var game_scene = preload("res://Scenes/main.tscn")
var rgpd_scene = preload("res://Scenes/gdpr_menu.tscn")
var info_menu = preload("res://Scenes/info_menu.tscn")

# -------- STATE --------
var current_scene = null
var first_login_flow := false
var cached_main_menu_scene = null
var cached_option_menu_scene = null
var cached_user_menu_scene = null
var cached_gdpr_menu_scene = null

# -------- SCENE HELPERS --------
func _instantiate_scene(scene_resource: PackedScene):
	return scene_resource.instantiate()

func _cache_scene_if_needed(scene_resource: PackedScene, cached_scene):
	if cached_scene != null:
		return cached_scene
	return _instantiate_scene(scene_resource)

func _prewarm_ui_scenes() -> void:
	cached_main_menu_scene = _cache_scene_if_needed(menu_scene, cached_main_menu_scene)
	cached_option_menu_scene = _cache_scene_if_needed(options_scene, cached_option_menu_scene)
	cached_user_menu_scene = _cache_scene_if_needed(user_scene, cached_user_menu_scene)
	cached_gdpr_menu_scene = _cache_scene_if_needed(rgpd_scene, cached_gdpr_menu_scene)

func _take_cached_scene(scene_resource: PackedScene, cache_name: String):
	var cached_scene = get(cache_name)
	if cached_scene != null:
		set(cache_name, null)
		return cached_scene
	return _instantiate_scene(scene_resource)

func _show_scene(scene, clear_existing := true):
	if clear_existing:
		_clear_current_scene()
	current_scene = scene
	container.add_child(current_scene)
	return current_scene

# -------- LIFECYCLE --------
func _ready():
	get_tree().set_meta("interface", self)
	_prewarm_ui_scenes()
	
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

func _clear_current_scene():
	if current_scene:
		current_scene.queue_free()
		current_scene = null

# -------- NAVIGATION --------
func show_menu():
	first_login_flow = false
	_log("Transition -> main_menu")
	if current_scene:
		_clear_current_scene()
	await get_tree().process_frame
	_show_scene(_take_cached_scene(menu_scene, "cached_main_menu_scene"), false)
	call_deferred("_prewarm_ui_scenes")


func show_options():
	_log("Transition -> option_menu")
	_show_scene(_take_cached_scene(options_scene, "cached_option_menu_scene"))
	call_deferred("_prewarm_ui_scenes")


func show_user():
	_log("Transition -> user_menu | first_login=%s" % str(first_login_flow))
	var scene = _take_cached_scene(user_scene, "cached_user_menu_scene")
	scene.first_login = first_login_flow
	_show_scene(scene)
	call_deferred("_prewarm_ui_scenes")


func show_game():
	_log("Transition -> game")
	_show_scene(_instantiate_scene(game_scene))
	

func show_gdpr(opened_from_menu: bool = false):
	_log("Transition -> gdpr_menu | from_menu=%s" % str(opened_from_menu))
	var scene = _take_cached_scene(rgpd_scene, "cached_gdpr_menu_scene")
	scene.force_show = true
	scene.first_login_flow = first_login_flow
	scene.opened_from_menu = opened_from_menu
	_show_scene(scene)
	call_deferred("_prewarm_ui_scenes")

func show_info():
	_log("Transition -> Info")
	_show_scene(_instantiate_scene(info_menu))
