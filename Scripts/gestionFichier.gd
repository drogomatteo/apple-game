extends Node

var i = 0
var player_data : Dictionary

var save_path = "user://save.dat"

func _ready() -> void:
	print("[SAVE] Node ready → loading game")
	load_game()

func save_data():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		player_data = {
			"uuid": PlayerData.uuid,
			"token": PlayerData.token,
			"age": PlayerData.age,
			"user_id": PlayerData.user_id,
			"is_guest": PlayerData.is_guest,
			"nombreDeRapportLocal": i
		}

		file.store_var(player_data)
		file.close()

		print("[SAVE] Data successfully written and file closed")
	else:
		print("[ERROR] Failed to open file for writing:", save_path)


func load_game():
	if not FileAccess.file_exists(save_path):
		print("[LOAD] No save file found at:", save_path)
		return
	

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:

		player_data = file.get_var()
		file.close()

		if player_data == null:
			print("[LOAD] Data is null → abort")
			return

		PlayerData.user_id = player_data.get("user_id", -1)
		PlayerData.uuid = player_data.get("uuid", "")
		PlayerData.token = player_data.get("token", "")
		PlayerData.age = player_data.get("age", "")
		PlayerData.is_guest = player_data.get("is_guest", true)

		print("[LOAD] PlayerData restored:")
		print("   user_id:", PlayerData.user_id)
		print("   uuid:", PlayerData.uuid)
		print("   token:", PlayerData.token)
		print("   age:", PlayerData.age)
		print("   is_guest:", PlayerData.is_guest)
	else:
		print("[ERROR] Failed to open file for reading:", save_path)
