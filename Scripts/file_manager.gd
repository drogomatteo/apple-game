extends Node

const SAVE_PATH := "user://save.dat"

var local_report_count: int = 0
var player_data: Dictionary = {}

func _ready() :
	load_game()


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing.")
		return

	player_data = {
		"uuid": PlayerData.uuid,
		"token": PlayerData.token,
		"birth_year": PlayerData.birth_year,
		"doctor_token": PlayerData.doctor_token,
		"user_id": PlayerData.user_id,
		"token_update_pending": PlayerData.token_update_pending,
		"previous_token": PlayerData.previous_token,
		"updated_token": PlayerData.updated_token,
		"access_token": PlayerData.access_token,
		"refresh_token": PlayerData.refresh_token,
		"access_token_expires_at": PlayerData.access_token_expires_at,
		"local_report_count": local_report_count
	}

	file.store_var(player_data)


func load_game() :
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open save file for reading.")
		return

	var loaded_data: Variant = file.get_var()
	if typeof(loaded_data) != TYPE_DICTIONARY:
		push_error("Invalid save file.")
		return

	player_data = loaded_data

	PlayerData.user_id = player_data.get("user_id", -1)
	PlayerData.uuid = player_data.get("uuid", "")
	PlayerData.token = player_data.get("token", "")
	PlayerData.birth_year = player_data.get("birth_year", "")
	PlayerData.doctor_token = player_data.get("doctor_token", "")
	PlayerData.token_update_pending = player_data.get("token_update_pending", false)
	PlayerData.previous_token = player_data.get("previous_token", "")
	PlayerData.updated_token = player_data.get("updated_token", "")
	PlayerData.access_token = player_data.get("access_token", "")
	PlayerData.refresh_token = player_data.get("refresh_token", "")
	PlayerData.access_token_expires_at = player_data.get("access_token_expires_at", 0)
	local_report_count = player_data.get("local_report_count", 0)
