extends Node

var save_path = "user://save.dat"

var player_data : Dictionary = {}

func save_data():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		player_data = {
			"pseudo": PlayerData.pseudo,
			"token": PlayerData.token,
			"user_id": PlayerData.user_id,
			"is_guest": PlayerData.is_guest,
			"options": {
				"sound": Paramètre.sound,
				"daltonien": Paramètre.daltonien
			}
		}
		file.store_var(player_data)
		file.close()

func load_game():
	if not FileAccess.file_exists(save_path):
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()

		if data == null or typeof(data) != TYPE_DICTIONARY:
			return

		player_data = data

	PlayerData.pseudo = player_data.get("pseudo", "")
	PlayerData.token = player_data.get("token", "")
	PlayerData.user_id = player_data.get("user_id", -1)
	PlayerData.is_guest = player_data.get("is_guest", true)

	if "options" in player_data:
		Paramètre.definir_mode_daltonien(player_data["options"].get("daltonien", 0))
		Paramètre.definir_sound(player_data["options"].get("sound", true))
