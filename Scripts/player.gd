extends CharacterBody3D


const SPEED = 2

var sensivity = 1
@onready var camera = $Camera3D

# à changer pour mobile
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Peut-être inclure ça dans le script du main.
#func _process(delta: float) -> void:
#	if Input.is_action_just_pressed("escape"):
#		get_tree().quit()


# à changer pour mobile
func _input(event):

	if event.is_action_pressed("toggle_mouse"):

		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		return

	var direction := Vector3.ZERO
	
	if Input.is_action_pressed("Go_forward"):
		direction.z -= 1

	if Input.is_action_pressed("Camera_Left"):
		rotate_y(delta*sensivity)
	
	if Input.is_action_pressed("Camera_Right"):
		rotate_y(-delta*sensivity)

	velocity = (transform.basis * Vector3(0,0,direction.z)).normalized() * SPEED

	move_and_slide()
