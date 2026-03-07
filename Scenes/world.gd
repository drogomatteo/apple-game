extends Node3D

#onready sert à attrendre que la fonction ready soit effectué avant afin d'éviter les erreurs
@onready var player  = $Player
@onready var basket = $Basket
@onready var tree_apple = $TreeApple
@onready var validate_button = $ValidateButton
@onready var validation_label = $MessageLabel

var grid_size = 8 #imposée par la thèse 
var cell_size = 2 
var basket_pos : Vector2 #donner une coordonnée
var tree_apple_pos : Vector2
var phase = 0 
#0 : chercher panier
#1 : chercher arbre
#2 : retrouver panier 




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#randomize()    à mettre si on veut des nombres aléatoire à chaque fois, si pas c'est aléatoire mais le même à chaque essai
	validate_button.visible = false
	validation_label.visible = false
	tree_apple.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spawn_basket()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var pos  = player_cell()
	
	if phase == 0 and close_enough(pos, basket_pos,) :
		basket.visible = false
		phase += 1
		spawn_tree_apple()
	
	if phase == 1 and close_enough(pos, tree_apple_pos,0.2) :
		tree_apple.visible = false
		phase += 1
		validate_button.visible = true


# récupérer la position du joueur
func player_cell():
	return Vector2(
		int(player.position.x / cell_size),
		int(player.position.z / cell_size)
	)

# générer une position aléatoire
func random_cell():
	return Vector2(
		randi() % grid_size, #random entre 0 et 7 
		randi() % grid_size
	)

# ajout d'une tolérence sur la position
func close_enough(a: Vector2, b: Vector2, tolerance := 1.2) -> bool:
	return abs(a.x - b.x) <= tolerance and abs(a.y - b.y) <= tolerance

# apparition du panier 
func spawn_basket():
	basket_pos = random_cell()
	while basket_pos == player_cell():
		basket_pos = random_cell()
	#convectir le 2D en 3D
	basket.position = Vector3(
		basket_pos.x *cell_size,
		0,
		basket_pos.y *cell_size
	)
	basket.visible = true

#appartion arbre avec pomme
func spawn_tree_apple():
	tree_apple_pos = random_cell()
	while tree_apple_pos == player_cell() or tree_apple_pos == basket_pos:
		tree_apple_pos = random_cell()
		
	tree_apple.position = Vector3(
		tree_apple_pos.x *cell_size,
		0,
		tree_apple_pos.y *cell_size,
	)
	tree_apple.visible  = true

func _on_validate_button_pressed() -> void:
	var pos = player_cell()
	if close_enough(pos,basket_pos) :
		validation_label.text = "Gagné, bonne position !"
		validation_label.add_theme_color_override("font_color", Color.GREEN)
	else : 
		validation_label.text = "Perdu, mauvaise position !"
		validation_label.add_theme_color_override("font_color", Color.RED)
	validation_label.visible = true
