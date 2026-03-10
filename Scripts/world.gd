extends Node3D

var validate_button : Node
var message_label : Node

#Scène
var player : PackedScene
var basket : PackedScene
var tree : PackedScene
var apple_tree : PackedScene
var visual : PackedScene
#Noeud
var Player : Node
var Basket : Node
var Arbre : Node
var Apple_tree : Node
var Visual : Node

# Donnée pour retracer la position du joueur
var Fs : float = 0.2
var total : float = 0
var position_joueur : Array

#Grille 16mX16m, coupé en 8 carré de longueur 2m
var grid_size : int = 8
var cell_size : int = 2
var map : Array
var Objet : Dictionary

#Pour compter les niveaux du joueur (1-5 : tuto, 6-25 : test)
var niveau : int = 1
var niveau_max : int = 25
var phase : int = 0 
#0 : find basket
#1 : find tree
#2 : find tree with apple
#3 : refind basket 

func _ready() -> void:
	#Choix de la graîne de génération
	seed(randi() % 10^7) # Limite à 10^7 mondes
	
	# Chargement des scènes existantes dans le main ou non
	validate_button = $ValidateButton
	message_label = $MessageLabel
	
	player = load("res://Scenes/player.tscn")
	basket = load("res://Scenes/basket.tscn")
	tree = load("res://Scenes/tree.tscn")
	apple_tree = load("res://Scenes/apple_tree.tscn")
	
	# Pour le repère visuel, on fait un choix aléatoire entre les 6 repères visuels possibles (pour l'instant, implémentation un peu brut)
	var possibilite = ["res://Scenes/rock_1.tscn","res://Scenes/rock_2.tscn","res://Scenes/rock_3.tscn","res://Scenes/rock_4.tscn","res://Scenes/rock_5.tscn","res://Scenes/tavern.tscn"]
	visual = load(possibilite[randi()%possibilite.size()])
	
	validate_button.visible = false
	message_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) #à changer avec mobile
	
	#Algorithme de remplissage type Démineur
	#Initialisation, remplissage de la map (0: libre, 1: occupé)
	for i in range(grid_size):
		var temp = []
		for j in range(grid_size):
			temp.append(0)
		map.append(temp)
	var pos : Vector3
	#Ajout des objets sur la carte (la position est stocké dans le dico)
	#Logique de l'algo: on teste les positions jusqu'à trouver une position correcte
	var maxIter = 10^6
	var iter = 0
	
	while maxIter >= iter:
		#Ajout du repère visuel
		pos = random_cell()
		if cellNotFree(pos.x, pos.z):
			iter = iter + 1
			continue
		occupeAdj(pos.x, pos.z)
		Objet["visual"] = pos*cell_size
		break
		
	while maxIter >= iter:
		#Ajout du panier
		pos = random_cell()
		if cellNotFree(pos.x, pos.z):
			iter = iter + 1
			continue
		occupeAdj(pos.x, pos.z)
		Objet["basket"] = pos*cell_size
		break
		
	while maxIter >= iter:
		#Ajout de l'arbre
		pos = random_cell()
		if cellNotFree(pos.x, pos.z):
			iter = iter + 1
			continue
		occupeAdj(pos.x, pos.z)
		Objet["tree"] = pos*cell_size
		break
		
	while maxIter >= iter:
		#Ajout du pommier
		pos = random_cell()
		if cellNotFree(pos.x, pos.z):
			iter = iter + 1
			continue
		occupeAdj(pos.x, pos.z)
		Objet["apple_tree"] = pos*cell_size
		break
		
	while maxIter >= iter:
		#Ajout du joueur
		pos = random_cell()
		if cellNotFree(pos.x, pos.z):
			iter = iter + 1
			continue
		occupeAdj(pos.x, pos.z)
		Objet["player"] = pos*cell_size
		break
	
	# Placer les objets sur la carte (avec leur position)
	CreateNode(Player, player, "player")
	CreateNode(Basket, basket, "basket")
	CreateNode(Arbre, tree, "tree")
	CreateNode(Apple_tree, apple_tree, "apple_tree")
	CreateNode(Visual, visual, "visual")
	

# Il faut séparer la position du joueur et le retraçage du joueur (avec f = 5 Hz)
#func _physics_process(delta: float) -> void:
#	
#	#incrémentation du temps écoulé pour retracer la position du joueur
#	total = total + delta
#	if total >= Fs:
#		position_joueur.append(player_cell())
#	
#	
#	if Input.is_action_pressed("escape"):
#		print(position_joueur)


# retrieve la position du joueur
#func player_cell():
#	return Convertisseur2D_3D(Player.get_position().x, Player.get_position().z)

# generate random position
func random_cell():
	return Convertisseur2D_3D(randi()%(grid_size), randi()%(grid_size))

#Transformation vecteur 2D en vecteur 3D
func Convertisseur2D_3D(x,z):
	return Vector3(x, 0, z)

#Occupé les cases adjacentes (pour pas trop de proximité)
func occupeAdj(x,z):
	for i in range(-1,2):
		for j in range(-1,2):
			#Vérification si on est bien dans la map
			if x+i >= 0 and x+i <= grid_size-1 and z+j >= 0 and z+j <= grid_size-1:
				map[x+i][z+j] = 1

func cellNotFree(x,z):
	return map[x][z] == 1

func CreateNode(node: Node, scene: PackedScene, string: String):
	node = scene.instantiate()
	add_child(node)
	node.set_position(Vector3(Objet[string].x, 0, Objet[string].z))
