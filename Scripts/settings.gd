extends Node

const SETTINGS_PATH := "user://settings.json"

var sound: bool = true
var colour_bind: int = 0
var tutorial_seen: bool = false
var rgpd_accepted: bool = false


func _ready() :
	load_settings()
	ColourBind.update_colour_blind(colour_bind)


func save_settings() :
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save settings.")
		return

	file.store_string(JSON.stringify({
		"sound": sound,
		"colour_bind": colour_bind,
		"tutorial_seen": tutorial_seen,
		"rgpd_accepted": rgpd_accepted
	}))


func load_settings() :
	if not FileAccess.file_exists(SETTINGS_PATH):
		save_settings()
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not load settings.")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid settings file.")
		return

	sound = parsed.get("sound", true)
	colour_bind = parsed.get("colour_bind", 0)
	tutorial_seen = parsed.get("tutorial_seen", false)
	rgpd_accepted = parsed.get("rgpd_accepted", false)


func set_sound(value: bool) :
	sound = value
	save_settings()


func set_tutorial_seen(value: bool) :
	tutorial_seen = value
	save_settings()


func set_colour_bind(value: int) :
	colour_bind = value
	ColourBind.update_colour_blind(colour_bind)
	save_settings()


func get_rgpd_accepted() -> bool:
	return rgpd_accepted


func set_rgpd_accepted(value: bool) :
	rgpd_accepted = value
	save_settings()
