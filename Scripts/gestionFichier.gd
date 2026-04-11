extends Node

var save_path = "user://save.dat"

var player_data : Dictionary

func save_data():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		player_data = {
			"nom": PlayerData.nom,
			"prenom": PlayerData.prenom,
			"email": PlayerData.email,
			"annee": PlayerData.annee,
			"id": PlayerData.id,
			"options": {
				"sound" = Paramètre.sound,
				"daltonien" = Paramètre.daltonien
			}
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
	
	PlayerData.nom = player_data["nom"]
	PlayerData.prenom = player_data["prenom"]
	PlayerData.email = player_data["email"]
	PlayerData.annee = player_data["annee"]
	PlayerData.id = player_data["id"]
	Paramètre.definir_mode_daltonien(player_data["options"]["daltonien"])
	Paramètre.definir_sound(player_data["options"]["sound"])
	
