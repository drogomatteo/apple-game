extends CharacterBody3D

const SPEED = 2
const acceleration = 8
const deceleration = 10
const sensivity = PI/2
const GRAVITY = 9.8

@onready var Left = $Left
@onready var Right = $Right
@onready var Forward = $Forward

var temp_vel : float = 0
var horizontal_velocity : Vector3

func _physics_process(delta: float) -> void:
	var direction = Vector3.ZERO
	
	if Forward.is_pressed():
		direction.z -= 1

	if Left.is_pressed():
		rotate_y(delta * sensivity)
	
	if Right.is_pressed():
		rotate_y(-delta * sensivity)


	if temp_vel < SPEED and direction != Vector3.ZERO:
		horizontal_velocity = (transform.basis * Vector3(0,0,direction.z)).normalized() * acceleration * delta
		velocity.x += horizontal_velocity.x
		velocity.z += horizontal_velocity.z
		temp_vel = min(temp_vel + sqrt(horizontal_velocity.dot(horizontal_velocity)), SPEED)

	elif temp_vel > 0 and direction == Vector3.ZERO:
		horizontal_velocity = (transform.basis * Vector3(0,0,1)).normalized() * deceleration * delta
		velocity.x += horizontal_velocity.x
		velocity.z += horizontal_velocity.z
		temp_vel = max(temp_vel - sqrt(horizontal_velocity.dot(horizontal_velocity)), 0.0)
	
	elif temp_vel == 0.0 and direction == Vector3.ZERO:
		velocity.x = 0
		velocity.z = 0
	
	elif temp_vel == SPEED and direction != Vector3.ZERO:
		velocity = (transform.basis * Vector3(0,0,direction.z)).normalized() * SPEED
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	move_and_slide()
