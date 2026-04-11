extends Node

var i = 0
var player_data : Dictionary

var save_path = "user://save.dat"
var repport_path = path_report_generator(i)

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
			"nom": PlayerData.nom,
			"prenom": PlayerData.prenom,
			"email": PlayerData.email,
			"annee": PlayerData.annee,
			"id": PlayerData.id,
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
		player_data = file.get_var()
		file.close()
	
	PlayerData.nom = player_data["nom"]
	PlayerData.prenom = player_data["prenom"]
	PlayerData.email = player_data["email"]
	PlayerData.annee = player_data["annee"]
	PlayerData.id = player_data["id"]
	Paramètre.definir_mode_daltonien(player_data["options"]["daltonien"])
	Paramètre.definir_sound(player_data["options"]["sound"])
	i = player_data["nombreDeRapportLocal"]
	
	#On a récupéré les données du joueur, il faut tester d'envoyer les rapports si possible
	local_files()

func send_data(path : String):
	#C'est la fonction qui s'occuperait d'envoyer les données si c'est possible de le faire (test fait au préalable)
	#On prend le fichier, on l'envoie et puis on supprime le fichier stocké dans le gsm
	#Une fois fait, on décrémente la valeur de i
	i -= 1

func write_report(string_to_save : String):
	#Fonction qui écrit le rapport, au lieu de le faire dans le script world
	var save_file = FileAccess.open(repport_path, FileAccess.WRITE)
	save_file.store_string(string_to_save)
	save_file.close()
	#Il faut aussi à partir de ce moment là voir s'il est possible de directement envoyer le rapport dans la DB
	#Si oui tant mieux, sinon il faut incrémenter la valeur de i, pour indiquer qu'il y a un fichier à envoyer
	i += 1 #SEULEMENT si pas de fichier envoyé

func test_internet():
	#Fonction qui retournerait un booléen pour savoir si c'est possible d'envoyer à la base de données
	return

func path_report_generator(j):
	return "user://repport"+j+".txt"
