extends Node

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
			"user_id": PlayerData.user_id,
			"is_guest": PlayerData.is_guest,
			"nombreDeRapportLocal": i
		}
		file.store_var(player_data)
		file.close()


func load_game():
	if not FileAccess.file_exists(save_path):
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		player_data = file.get_var()
		file.close()

		if player_data == null:
			return

		PlayerData.user_id = player_data.get("user_id", -1)
		PlayerData.uuid = player_data.get("uuid", "")
		PlayerData.token = player_data.get("token", "")
		PlayerData.is_guest = player_data.get("is_guest", true)
