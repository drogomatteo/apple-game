extends CharacterBody3D

const SPEED = 2
const sensivity = PI/2

@onready var Left = $Left
@onready var Right = $Right
@onready var Forward = $Forward
const GRAVITY = 9.8

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)



func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	
	if Forward.is_pressed():
		direction.z -= 1

	if Left.is_pressed():
		rotate_y(delta * sensivity)
	
	if Right.is_pressed():
		rotate_y(-delta * sensivity)

	# 👉 mouvement horizontal uniquement
	var horizontal_velocity = (transform.basis * Vector3(0,0,direction.z)).normalized() * SPEED
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	# 👉 gravité (très important)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	move_and_slide()
