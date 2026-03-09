extends Node3D

#onready wait the function_ready() is completed
@onready var player  = $Player
@onready var validate_button = $ValidateButton
@onready var validation_label = $MessageLabel

var grid_size = 8
var cell_size = 2 
var start_pos : Vector2
var basket_pos : Vector2
var tree_pos : Array
var tree_apple_pos : Vector2
var phase = 0 
#0 : find basket
#1 : find tree
#2 : find tree with apple
#3 : refind basket 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	validate_button.visible = false
	validation_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spawn_basket()

# Called every frame. 'delta' is the elapsed time since the previous frame.
# Il faut séparer la position du joueur et le retraçage du joueur (avec f = 5 Hz)
func _process(delta: float) -> void:
	var pos  = player_cell()

	if phase == 0:
		basket.visible = false
		phase += 1
		spawn_tree_apple()

	if phase == 1:
		tree_apple.visible = false
		phase += 1
		validate_button.visible = true


# retrieve la position du joueur
func player_cell():
	return Vector2(
		int(player.position.x / cell_size),
		int(player.position.z / cell_size)
	)

# generate random position
func random_cell():
	return Vector2(
		randi() % grid_size, #random between 0 et 7 
		randi() % grid_size
	)


# basket appearance 
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

# appearance of tree with apple
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
