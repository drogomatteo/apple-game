extends Node

# -------- CONFIG --------
const SAVE_PATH := "user://rgpd.save"

# -------- STATE --------
var accepted: bool = false

# -------- LIFECYCLE --------
func _ready():
	_load()

# -------- PUBLIC API --------
func is_accepted() -> bool:
	return accepted

func set_accepted(value: bool, save_deferred := false) -> void:
	accepted = value
	if save_deferred:
		call_deferred("_save")
		return
	_save()

# -------- PERSISTENCE --------
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
