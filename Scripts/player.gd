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
var temp_sens : float = 0
var horizontal_velocity : Vector3
var direction_rot : int

var avance : bool
var tourner_gauche : bool
var tourner_droite : bool


func _physics_process(delta: float) -> void:
	var direction = Vector3.ZERO
	avance = Forward.is_pressed()
	tourner_gauche = Left.is_pressed()
	tourner_droite = Right.is_pressed()
	
	if avance:
		direction.z -= 1
	else:
		direction.z += 1
	
	if tourner_droite:
		direction_rot = -1
	elif tourner_gauche:
		direction_rot = 1
	
	#Déplacement du joueur
	if temp_vel < SPEED and avance:
		horizontal_velocity = (transform.basis * Vector3(0,0,direction.z)).normalized() * acceleration * delta
		velocity.x += horizontal_velocity.x
		velocity.z += horizontal_velocity.z
		temp_vel = min(temp_vel + sqrt(horizontal_velocity.dot(horizontal_velocity)), SPEED)

	elif temp_vel > 0 and not avance:
		horizontal_velocity = (transform.basis * Vector3(0,0,direction.z)).normalized() * deceleration * delta
		velocity.x += horizontal_velocity.x
		velocity.z += horizontal_velocity.z
		temp_vel = max(temp_vel - sqrt(horizontal_velocity.dot(horizontal_velocity)), 0.0)
	
	elif temp_vel == 0.0 and not avance:
		velocity.x = 0
		velocity.z = 0
	
	elif temp_vel == SPEED and avance:
		velocity = (transform.basis * Vector3(0,0,direction.z)).normalized() * SPEED
	
	
	#Rotation caméra
	
	if temp_sens < sensivity and (tourner_droite or tourner_gauche):
		temp_sens = min(temp_sens + delta*acceleration, sensivity)
		
		rotate_y(direction_rot*temp_sens*delta)
	elif temp_sens > 0 and not(tourner_droite or tourner_gauche):
		temp_sens = max(temp_sens - delta*deceleration, 0.0)
		
		rotate_y(direction_rot*temp_sens*delta)
	elif temp_sens == sensivity and (tourner_droite or tourner_gauche):
		rotate_y(direction_rot*delta*sensivity)

	#Gestion gravité 
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	move_and_slide()
