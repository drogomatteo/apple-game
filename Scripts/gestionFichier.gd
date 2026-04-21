extends Node

const LOG_TAG := "[Save]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

var i = 0
var player_data : Dictionary

var save_path = "user://save.dat"

func _ready() -> void:
	load_game()

func save_data():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		player_data = {
			"uuid": PlayerData.uuid,
			"token": PlayerData.token,
			"age": PlayerData.age,
			"medecin_key": PlayerData.medecin_key,
			"user_id": PlayerData.user_id,
			"is_guest": PlayerData.is_guest,
			"access_token": PlayerData.access_token,
			"refresh_token": PlayerData.refresh_token,
			"access_token_expires_at": PlayerData.access_token_expires_at,
			"nombreDeRapportLocal": i
		}

		file.store_var(player_data)
		file.close()
		_log("Save written")
	else:
		_log("ERROR: failed to open save file for writing")


func load_game():
	if not FileAccess.file_exists(save_path):
		_log("No local save file found")
		return
	

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:

		player_data = file.get_var()
		file.close()

		if player_data == null:
			_log("ERROR: save payload is null")
			return

		PlayerData.user_id = player_data.get("user_id", -1)
		PlayerData.uuid = player_data.get("uuid", "")
		PlayerData.token = player_data.get("token", "")
		PlayerData.age = player_data.get("age", "")
		PlayerData.medecin_key = player_data.get("medecin_key", "")
		PlayerData.is_guest = player_data.get("is_guest", true)
		PlayerData.access_token = player_data.get("access_token", "")
		PlayerData.refresh_token = player_data.get("refresh_token", "")
		PlayerData.access_token_expires_at = int(player_data.get("access_token_expires_at", 0))
		_log("Local save restored | user_id=%s" % str(PlayerData.user_id))
	else:
		_log("ERROR: failed to open save file for reading")
