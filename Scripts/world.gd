extends Node3D

#Zone de texte
@onready var validate_button = $ValidateButton
@onready var message_label = $MessageLabel
@onready var next_level = $NextLevel
@onready var message_alerte = $AlertMessage
@onready var temps_restant = $TempsRestant

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

#Gestion des arbres (dans le cas difficile)
var Arbre : Array
var index_Tree : int
var max_tree : int

# Donnée pour retracer la position du joueur
var Fs : float = 0.2
var sampling : float = 0
var position_joueur : Array

#Grille 16mX16m, coupé en 8 carré de longueur 2m
var grid_size : int = 8
var cell_size : int = 2
var map : Array
var Objet : Dictionary

#Données pour la dernière phase
var position_Finale : Vector3
var distance : float

#Pour compter les niveaux du joueur (1-5 : tuto, 6-20 : test)
var niveau : int = 1
var niveau_max : int = 20
var phase : int = 0 
#0 : find basket
#1 : find tree
#2 : find tree with apple
#3 : refind basket 
#4 : feedback

#Gestion du temps
@onready var max_timer = $Timer
var timeout : bool

#Score et difficulté
#0 <= Facile <= 10 < Normal <= 20 < Difficile 
var score = 15
var Normal = 10
var Difficile = 20
var Difficulté_actuel : Array
@export var use_generated_spawn := true

func _ready() -> void:
	Initialisation()

# Il faut séparer la position du joueur et le retraçage du joueur (avec f = 5 Hz)
func _physics_process(_delta: float) -> void:
	if phase == 3:
		if max_timer.get_time_left() >= 1:
			temps_restant.set_text(str(int(ceil(max_timer.get_time_left())))+" secondes")
		else:
			temps_restant.set_text(str(int(ceil(max_timer.get_time_left())))+" seconde")

	if next_level.is_pressed():
		# On retire noeuds rajoutés
		Basket.free()
		if Difficulté_actuel[0]:
			Visual.free()
		
		for child in Arbre:
			child.free()
		Apple_tree.free()
		#Puis après on les rajoutes
		Initialisation()
		phase = 0
	
	if (validate_button.is_pressed() and phase == 3) or timeout:
		phase = phase + 1
		validate_button.set_visible(false)
		Player.get_child(2).set_visible(false)
		Player.get_child(3).set_visible(false)
		Player.get_child(4).set_visible(false)
		next_level.set_visible(true)
		if timeout:
			message_alerte.set_visible(true)
		max_timer.stop()
		temps_restant.set_visible(false)
		
		
		position_Finale = player_cell()
		
		distance = sqrt((position_Finale.x-Objet["basket0"].x)**2+(position_Finale.z-Objet["basket0"].z)**2)
		
		if distance <= 3:
			message_label.set_text("Vous avez 3 étoiles")
			score = score + 1
		elif 3 < distance and distance <= 7:
			message_label.set_text("Vous avez 2 étoiles")
		else:
			message_label.set_text("Vous avez 1 étoile")
			score = max(score - 1, 0) #On ne veut pas un score négatif
		message_label.set_visible(true)

	#Gestion des collisions avec le joueur
	for index in range(Player.get_slide_collision_count()):
		
		var collision = Player.get_slide_collision(index)
		
		if collision.get_collider() == null:
			continue
		
		elif collision.get_collider().is_in_group("Basket") and phase == 0:
			phase = phase + 1
			Basket.set_visible(false)
			Arbre[0].set_visible(true)
			index_Tree = 0
			Player.set_collision_mask(10)
			break
		
		
		elif collision.get_collider() == Arbre[index_Tree] and phase == 1:
			if index_Tree == Arbre.size()-1:
				phase = phase + 1
				Arbre[-1].set_visible(false)
				Apple_tree.set_visible(true)
				Player.set_collision_mask(18)
			else:
				var Arbre_actuel = collision.get_collider()
				Arbre_actuel.set_visible(false)
				Arbre_actuel.get_child(1).set_disabled(true)
				index_Tree = index_Tree + 1
				Arbre[index_Tree].set_visible(true)
			break
		
		elif collision.get_collider().is_in_group("Apple Tree") and phase == 2:
			phase = phase + 1
			Apple_tree.set_visible(false)
			Player.set_collision_mask(2)
			validate_button.set_visible(true)
			max_timer.start()
			temps_restant.set_visible(true)
			break

func Initialisation() -> void:
	#Choix de la graîne de génération
	seed(randi()%10000000) # Limite à 10^7 mondes (pour l'instant une constante car on test)
	#On doit pouvoir le nombre de monde différents possibles
	timeout = false
	
	#On vide la liste (dans le cas où on recommence une partie)
	position_joueur = []
	
	#On récupère la difficulté
	Difficulté_actuel = Gestion_Difficulté()
	
	#Réinitialisation de la couche mask
	Player.set_collision_mask(6)
	
	# Initialisation de l'affichage
	Player.get_child(2).set_visible(true)
	Player.get_child(3).set_visible(true)
	Player.get_child(4).set_visible(true)
	validate_button.set_visible(false)
	next_level.set_visible(false)
	message_label.set_visible(false)
	message_alerte.set_visible(false)
	temps_restant.set_visible(false)
	

	
	map = []
	Arbre = []
	
	#Algorithme de remplissage type Démineur
	#Initialisation, remplissage de la map (0: libre, 1: occupé)
	for i in range(grid_size):
		var temp = []
		for j in range(grid_size):
			temp.append(0)
		map.append(temp)
	#Ajout des objets sur la carte (la position est stocké dans le dico)
	#Logique de l'algo: on teste les positions jusqu'à trouver une position correcte
	if Difficulté_actuel[0]:
		Placer_Objet_sur_map("visual")
	
	Placer_Objet_sur_map("basket")
	
	# On rajoute 1 arbre pour chaque palier de 5 au dessus de 21 (avec un minimum de 1 arbres)
	max_tree = max(1, int(ceil((score-20)/5)))
	
	for i in range(max_tree):
		Placer_Objet_sur_map("tree", str(i))
	
	Placer_Objet_sur_map("apple_tree")
	
	Placer_Objet_sur_map("player")
	
	# Placer les objets sur la carte (avec leur position) SAUF le joueur
	Basket = CreateNode(basket, "basket")
	for i in range(max_tree):
		Arbre.append(CreateNode(tree, "tree", str(i)))
	Apple_tree = CreateNode(apple_tree, "apple_tree")
	
	if Difficulté_actuel[0]:
		Visual = CreateNode(visual, "visual")
	# Déplacer le joueur sur la carte
	

	if use_generated_spawn:
		Player.set_position(Vector3(Objet["player0"].x,spawn_height,Objet["player0"].z))
		print("Spawn joueur :", Objet["player0"])


	#Modification de la visibilité
	Basket.set_visible(true)
	for child in Arbre:
		child.set_visible(false)
	Apple_tree.set_visible(false)


# retrieve la position du joueur
func player_cell():
	return Convertisseur2D_3D(Player.get_position().x, Player.get_position().z)

# generate random position
func random_cell():
	return Convertisseur2D_3D(randi()%(grid_size), randi()%(grid_size))

#Transformation vecteur 2D en vecteur 3D
func Convertisseur2D_3D(x,z):
	return Vector3(x, 0, z)

#Occupé les cases adjacentes (pour pas trop de proximité)
func occupeAdj(x, z):
	var ix = int(x)
	var iz = int(z)
	for i in range(-1, 2):
		for j in range(-1, 2):
			# Vérification si on est bien dans la map
			if ix + i >= 0 and ix + i <= grid_size - 1 and iz + j >= 0 and iz + j <= grid_size - 1:
				map[ix + i][iz + j] = 1

# Test si la case n'est pas libre
func cellNotFree(x, z):
	return map[int(x)][int(z)] == 1

#instancier un noeurd et l'ajouter comme enfant (et le return)
func CreateNode(scene: PackedScene, string: String, indice : String = "0"):
	var new_node = scene.instantiate()
	add_child(new_node)
	new_node.set_position(Vector3(Objet[string+indice].x, 0, Objet[string+indice].z))
	return new_node

func Gestion_Difficulté():
	#Principe du bitmask : on met True à l'indice qui nous intéresse
	#0 : Facile
	#1 : Normal
	#2 : Difficile
	if score < Normal:
		return [true, false, false]
	elif score >= Normal and score < Difficile:
		return [false, true, false]
	elif score >= Difficile:
		return [false, false, true]

func Placer_Objet_sur_map(mot : String, indice : String = "0"):
	var pos : Vector3
	var maxiter = 100000
	var iter = 0
	while iter < maxiter:
		pos = random_cell()
		if cellNotFree(pos.x, pos.z):
			iter = iter + 1
			continue
		occupeAdj(pos.x, pos.z)
		Objet[mot+indice] = pos*cell_size
		break

func _on_timer_timeout() -> void:
	timeout = true


func _on_sampling_timeout() -> void:
	position_joueur.append(player_cell())
