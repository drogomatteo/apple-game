extends Node3D

#Zone de texte
@onready var validate_button = $Bouton/ValidateButton
@onready var message_label = $"Zone de texte/MessageLabel"
@onready var next_level = $Bouton/NextLevel
@onready var voir_recap = $Bouton/Recap
@onready var message_alerte = $"Zone de texte/AlertMessage"
@onready var temps_restant = $"Zone de texte/TempsRestant"
@onready var textToDo = $"Zone de texte/ToDo"

#Scène
@export_group("Scènes")
@export var basket : PackedScene
@export var tree : PackedScene
@export var apple_tree : PackedScene
@export var visual : PackedScene

#Noeud
@onready var Player = $Player
var Basket : Node
var Apple_tree : Node
var Visual : Node

#Gravité
@export var spawn_height := 3.0

#Gestion des arbres
var Arbre : Array
var index_Tree : int
var max_tree : int

#Données joueur
var position_joueur : Array
var graine : int
var string_to_save : String

#Grille
var grid_size : int = 8
var cell_size : int = 2
var map : Array
var Objet : Dictionary

#Phase finale
var position_Finale : Vector3
var distance : float
var distanceAParcourir : float
var seuil1 = PI/9
var seuil2 = 2*seuil1
var Rayon1
var Rayon2

#Niveaux
var niveau : int = 1
var niveau_max : int = 20
var phase : int = 0 

#Temps
@onready var max_timer = $Temps/Timer
@onready var sampling = $Temps/Sampling
var timeout : bool

#Score
var score = 15
var Normal = 10
var Difficile = 20
var Difficulté_actuel : Array
@export var use_generated_spawn := true
var session_id : String

#Pause
@onready var BreakButton = $Bouton/BreakButton
@onready var BreakMenu = $BreakMenu

#Tuto
@onready var TutorialUI = $UI/TutorialUI
@onready var TutorialHighlight = $UI/TutorialUI/Highlight
@onready var TutorialController = $TutorialController
var pending_end_results: bool = false


#Tuto désactivé de base:
func _ready() -> void:
	string_to_save = ""
	session_id = str(int(Time.get_unix_time_from_system())) + "_" + str(PlayerData.user_id) + "_" + str(randi())
	TutorialHighlight.visible = false
	Initialisation()
	Paramètre.definir_tutorial_seen(false)
	if not Paramètre.tutorial_seen:
		TutorialController.start_tutorial()

func _physics_process(_delta: float) -> void:
	textToDo.set_text(toDo())
	
	if phase == 3:
		if max_timer.get_time_left() >= 1:
			temps_restant.set_text(str(int(ceil(max_timer.get_time_left())))+" secondes")
		else:
			temps_restant.set_text(str(int(ceil(max_timer.get_time_left())))+" seconde")
		var Red : float = (max_timer.get_wait_time()-max_timer.get_time_left())/max_timer.get_wait_time()
		temps_restant.label_settings.font_color = Color(Red, 0.0, 0.0, 1.0)

	if next_level.is_pressed():
		if niveau == niveau_max:
			Transition.go_to_scene("main_menu")
		else:
			Basket.queue_free()
			if Difficulté_actuel[0]:
				Visual.queue_free()
		
			for child in Arbre:
				child.queue_free()
			Apple_tree.queue_free()

			Initialisation()
			niveau += 1
			phase = 0
	
	if voir_recap.is_pressed():
		voir_recap.visible = false
		next_level.visible = false
		message_label.visible = false
		$Parcours3D.launch(position_joueur, Objet["basket0"], Rayon1, Rayon2)
	
	if (validate_button.is_pressed() or timeout) and phase == 3:
		phase += 1
		if TutorialController.tutorial_active and TutorialController.waiting_final_popup:
			pending_end_results = true
			TutorialController.show_final_message_before_score()
			return
		
		validate_button.visible = false
		Player.get_child(2).visible = false
		Player.get_child(3).visible = false
		Player.get_child(4).visible = false
		Player.get_child(5).visible = false
		next_level.visible = true
		voir_recap.visible = true
		
		$TopView.make_current()

		Basket.visible = true
		for i in range(max_tree):
			Arbre[i].visible = true
		Apple_tree.visible = true


		$TopView.make_current()

		Basket.visible = true
		for i in range(max_tree):
			Arbre[i].visible = true
		Apple_tree.visible = true


		if niveau == niveau_max:
			next_level.text = "Voici votre score : "+str(score)+"\nAppuyez sur le bouton pour quitter"

		if timeout:
			message_alerte.visible = true

		max_timer.stop()
		temps_restant.visible = false
		sampling.stop()
		position_Finale = player_cell()

		distance = sqrt((position_Finale.x-Objet["basket0"].x)**2+(position_Finale.z-Objet["basket0"].z)**2)
		distanceAParcourir = sqrt((Objet["apple_tree0"].x-Objet["basket0"].x)**2+(Objet["apple_tree0"].z-Objet["basket0"].z)**2)

		Rayon1 = distanceAParcourir*sin(seuil1)
		Rayon2 = distanceAParcourir*sin(seuil2)

		if distance <= Rayon1:
			message_label.text = "Vous avez 3 étoiles"
			score += 1
		elif distance <= Rayon2:
			message_label.text = "Vous avez 2 étoiles"
		else:
			message_label.text = "Vous avez 1 étoile"
			score = max(score - 1, 0)

		message_label.visible = true
		
		string_to_save += save_level(niveau)
		write_local_reports(false)	
		sync_reports_now()
		


	for index in range(Player.get_slide_collision_count()):
		var collision = Player.get_slide_collision(index)

		if collision.get_collider() == null:
			continue

		elif collision.get_collider().is_in_group("Basket") and phase == 0:
			phase += 1
			Basket.visible = false
			Arbre[0].visible = true
			index_Tree = 0
			Player.set_collision_mask(10)
			Player.get_child(5).visible = true
			break
		
		elif collision.get_collider() == Arbre[index_Tree] and phase == 1:
			if index_Tree == Arbre.size()-1:
				phase += 1
				Arbre[-1].visible = false
				Apple_tree.visible = true
				Player.set_collision_mask(18)
			else:
				var arbre_actuel = collision.get_collider()
				arbre_actuel.visible = false
				arbre_actuel.get_child(1).set_disabled(true)
				index_Tree += 1
				Arbre[index_Tree].visible = true
			break
		
		elif collision.get_collider().is_in_group("Apple Tree") and phase == 2:
			phase += 1
			Apple_tree.visible = false
			Player.set_collision_mask(2)
			validate_button.visible = true
			max_timer.start()
			temps_restant.visible = true
			break


func Initialisation() -> void:
	graine = randi()%10000000
	seed(graine)
	timeout = false
	position_joueur = []

	Difficulté_actuel = Gestion_Difficulté()
	Player.set_collision_mask(6)

	Player.get_child(2).set_visible(true)
	Player.get_child(3).set_visible(true)
	Player.get_child(4).set_visible(true)
	validate_button.visible = false
	next_level.visible = false
	message_label.visible = false
	message_alerte.visible = false
	temps_restant.visible = false
	voir_recap.visible = false

	Player.get_child(1).make_current()

	Player.get_child(1).make_current()

	map = []
	Arbre = []

	for i in range(grid_size):
		var temp = []
		for j in range(grid_size):
			temp.append(0)
		map.append(temp)

	if Difficulté_actuel[0]:
		Placer_Objet_sur_map("visual")

	Placer_Objet_sur_map("basket")

	max_tree = max(1, int(ceil((score-15)/5)))

	for i in range(max_tree):
		Placer_Objet_sur_map("tree", str(i))

	Placer_Objet_sur_map("apple_tree")
	Placer_Objet_sur_map("player")

	Basket = CreateNode(basket, "basket")

	for i in range(max_tree):
		Arbre.append(CreateNode(tree, "tree", str(i)))

	Apple_tree = CreateNode(apple_tree, "apple_tree")

	if Difficulté_actuel[0]:
		Visual = CreateNode(visual, "visual")

	if use_generated_spawn:
		Player.position = Vector3(Objet["player0"].x,spawn_height,Objet["player0"].z)
	
	Basket.set_visible(true)
	for child in Arbre:
		child.set_visible(false)
	Apple_tree.set_visible(false)


func player_cell():
	return Vector3(Player.position.x, 0, Player.position.z)


func random_cell():
	return Vector3(randi()%grid_size, 0, randi()%grid_size)


func occupeAdj(x, z):
	for i in range(-1, 2):
		for j in range(-1, 2):
			if x+i >= 0 and x+i < grid_size and z+j >= 0 and z+j < grid_size:
				map[x+i][z+j] = 1


func cellNotFree(x, z):
	return map[int(x)][int(z)] == 1


func CreateNode(scene: PackedScene, string: String, indice : String = "0"):
	var new_node = scene.instantiate()
	add_child(new_node)
	new_node.position = Vector3(Objet[string+indice].x, 0, Objet[string+indice].z)
	return new_node


func Gestion_Difficulté():
	if score < Normal:
		return [true, false, false]
	elif score < Difficile:
		return [false, true, false]
	else:
		return [false, false, true]


func Placer_Objet_sur_map(mot : String, indice : String = "0"):
	var pos : Vector3
	while true:
		pos = random_cell()
		if cellNotFree(pos.x, pos.z):
			continue
		occupeAdj(pos.x, pos.z)
		Objet[mot+indice] = pos*cell_size
		break


func save_level(i):
	var level = ""
	level += "===================\n"
	level += "level"+str(i)+"\n"
	level += "===================\n"
	
	level += "Graine de génération :"+str(graine)+"\n"
	
	level += "Position du panier :"+str(Objet["basket0"])+"\n"
	level += "Position du pommier :"+str(Objet["apple_tree0"])+"\n"
	if Difficulté_actuel[0]:
		level += "Position du repère visuel :"+str(Objet["visual0"])+"\n"
	
	if Difficulté_actuel[1] or Difficulté_actuel[0]:
		level += "Position de l'arbre :"+str(Objet["tree0"])+"\n"
	else:
		level += "Position du/des arbre(s) :\n"
		for j in range(max_tree):
			level += str(Objet["tree"+str(j)])+"\n"
	
	level += "Position du joueur :\n"
	# On rajoute la position de départ
	level += "("+str(Objet["player0"].x)+","+str(Objet["player0"].z)+")\n"
	for vecteur in position_joueur:
		level += "("+str(vecteur.x)+","+str(vecteur.z)+")\n"
	#On stocke la position finale
	level += "("+str(position_Finale.x)+","+str(position_Finale.z)+")\n"
	#On stocke la distance entre le joueur et le panier
	level += "Distance entre le panier et le joueur : "+str(distance)+"m\n"
	level += "Score obtenue "+str(score)+"\n"
	return level

func continuer_fin_apres_tuto() -> void:
	if not pending_end_results:
		return

	pending_end_results = false

	validate_button.visible = false
	Player.get_child(2).visible = false
	Player.get_child(3).visible = false
	Player.get_child(4).visible = false
	Player.get_child(5).visible = false
	next_level.visible = true

	if niveau == niveau_max:
		next_level.text = "Voici votre score : " + str(score) + "\nAppuyez sur le bouton pour quitter"

	if timeout:
		message_alerte.visible = true

	max_timer.stop()
	temps_restant.visible = false
	
	position_Finale = player_cell()

	distance = sqrt((position_Finale.x - Objet["basket0"].x) ** 2 + (position_Finale.z - Objet["basket0"].z) ** 2)
	distanceAParcourir = sqrt((Objet["apple_tree0"].x - Objet["basket0"].x) ** 2 + (Objet["apple_tree0"].z - Objet["basket0"].z) ** 2)

	var seuil1 = PI / 9
	var seuil2 = 2 * seuil1

	if distance <= distanceAParcourir * sin(seuil1):
		message_label.text = "Vous avez 3 étoiles"
		score += 1
	elif distance <= distanceAParcourir * sin(seuil2):
		message_label.text = "Vous avez 2 étoiles"
	else:
		message_label.text = "Vous avez 1 étoile"
		score = max(score - 1, 0)

	message_label.visible = true
	
	string_to_save += save_level(niveau)
	write_local_reports(false)
	sync_reports_now()

	if niveau == niveau_max:
		Transition.go_to_scene("main_menu")
		


func toDo():
	if phase == 0:
		return "Trouvez le panier"
	elif phase == 1:
		return "Trouvez un arbre"
	elif phase == 2:
		return "Trouvez le pommier"
	elif phase == 3:
		return "Déposez le panier"
	return ""

func animation_end():
	voir_recap.visible = true
	next_level.visible = true
	message_label.visible = true

func _on_timer_timeout() -> void:
	timeout = true


func _on_sampling_timeout() -> void:
	position_joueur.append(player_cell())


func _on_break_button_pressed() -> void:
	if not get_tree().paused:
		BreakButton.visible = false
		BreakMenu.open()
	
	
#fonction pour le niveau interrompu
func save_interrupted_level() -> String:
	var level = ""
	level += "===================\n"
	level += "level" + str(niveau) + " interrompu\n"
	level += "===================\n"

	level += "Graine de génération :" + str(graine) + "\n"
	level += "Phase actuelle :" + str(phase) + "\n"
	level += "Score actuel :" + str(score) + "\n"
	level += "Position actuelle du joueur : (" + str(player_cell().x) + "," + str(player_cell().z) + ")\n"

	level += "Trajet partiel du joueur :\n"
	for vecteur in position_joueur:
		level += "(" + str(vecteur.x) + "," + str(vecteur.z) + ")\n"

	return level	
	
#fonction pour mettre les rapports en attente d’envoi	
func queue_reports_for_sync() -> void:
	SyncManager.add_action({
		"type": "file",
		"path": "user://rapport_complet.dat",
		"url": GameManager.BASE_URL + "rapport_complet/",
		"session_id": session_id
	})

	if not PlayerData.is_guest:
		SyncManager.add_action({
			"type": "file",
			"path": "user://rapport_medecin.dat",
			"url": GameManager.BASE_URL + "rapport_medecin/"
		})


#fonction pour écrire les rapports localement
func write_local_reports(interrompue: bool = false) -> void:
	var contenu = string_to_save

	if interrompue:
		contenu += save_interrupted_level()

	var file = FileAccess.open("user://rapport_complet.dat", FileAccess.WRITE)
	if file:
		file.store_string(contenu)
		file.close()

	if not PlayerData.is_guest:
		var file2 = FileAccess.open("user://rapport_medecin.dat", FileAccess.WRITE)
		if file2:
			var medecin_content = ""
			medecin_content += "Score: " + str(score) + "\n"
			medecin_content += "Niveau atteint: " + str(niveau) + "\n"
			medecin_content += "Statut: " + ("interrompue" if interrompue else "terminee") + "\n"
			file2.store_string(medecin_content)
			file2.close()
			
			
# si le joueur ferme la fenêtre en plein jeu
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		write_local_reports(true)
		queue_reports_for_sync()

		# tentative immédiate, sans garantie
		GameManager.send_rapport_complet(session_id)
		if not PlayerData.is_guest:
			GameManager.send_rapport_medecin(session_id)

		GestionFichier.save_data()
		get_tree().quit()


# fonction unique d’envoi qui met à jour à la fin de chaque niveau, elle est appelée à la fin de chaque niveau et on tente d'envoyer dans la DB
func sync_reports_now() -> void:
	GameManager.send_rapport_complet(session_id)

	if not PlayerData.is_guest:
		GameManager.send_rapport_medecin(session_id)
