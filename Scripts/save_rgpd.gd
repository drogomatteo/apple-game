extends Node

const SAVE_PATH := "user://rgpd.save"

var accepted: bool = false


func _ready():
	_load()


func is_accepted() -> bool:
	return accepted


func set_accepted(value: bool) -> void:
	accepted = value
	_save()

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		return
	f.store_var({"accepted": accepted})
	f.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		accepted = false
		return

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		accepted = false
		return

	var data = f.get_var()
	f.close()
	if typeof(data) == TYPE_DICTIONARY and data.has("accepted"):
		accepted = bool(data["accepted"])
		return
	accepted = false
