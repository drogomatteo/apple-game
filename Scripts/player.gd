extends CharacterBody3D

const SPEED = 2
const sensivity = PI/2

@onready var Left = $Left
@onready var Right = $Right
@onready var Forward = $Forward

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	
	if Forward.is_pressed():
		direction.z -= 1

	if Left.is_pressed():
		rotate_y(delta*sensivity)
	
	if Right.is_pressed():
		rotate_y(-delta*sensivity)

	velocity = (transform.basis * Vector3(0,0,direction.z)).normalized() * SPEED

	move_and_slide()
