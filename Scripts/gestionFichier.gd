extends Node

var i = 0
var player_data : Dictionary

var save_path = "user://save.dat"
var repport_path = path_report_generator(i)

func _ready() -> void:
	load_game()

func local_files() -> void:
	if i != 0 :
		#Si i !=0, cela veut dire que le joueur possède actuellement i fichiers à envoyer
		#La logique serait de tester si le joueur peut envoyer les données à la base de données (avec la fonction test_internet)
		#Pour les fichiers allant de i-1 jusque 0
		#Ce test sera effectué lors du lancement du jeu. Si c'est correct, alors une autre fontion est appelé pour envoyé les données du rapport
		#et on peut effacer le fichier sur le gsm
		while i > 0:
			send_data(path_report_generator(i-1))
		

func save_data():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		player_data = {
			"pseudo": PlayerData.pseudo,
			"token": PlayerData.token,
			"user_id": PlayerData.user_id,
			"is_guest": PlayerData.is_guest,
			"options": {
				"sound" = Paramètre.sound,
				"daltonien" = Paramètre.daltonien
			},
			"nombreDeRapportLocal": i
		}
		file.store_var(player_data)
		file.close()


func load_game():
	if not FileAccess.file_exists(save_path):
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		player_data = file.get_var()   # 🔥 IMPORTANT
		file.close()

		if player_data == null:
			return

		PlayerData.user_id = player_data.get("user_id", -1)
		PlayerData.pseudo = player_data.get("pseudo", "")
		PlayerData.token = player_data.get("token", "")
		PlayerData.is_guest = player_data.get("is_guest", true)

		if "options" in player_data:
			Paramètre.definir_mode_daltonien(player_data["options"].get("daltonien", 0))
			Paramètre.definir_sound(player_data["options"].get("sound", true))
