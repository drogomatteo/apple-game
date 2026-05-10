extends CharacterBody3D

# Déplacement du joueur
const SPEED := 2.0
const ACCELERATION := 4.0
const DECELERATION := 5.0
const SENSITIVITY := PI / 3.0
const GRAVITY := 9.8

# Tutoriel
var controls_locked: bool = false
var allow_forward: bool = true
var allow_left: bool = true
var allow_right: bool = true

# Balancement de tête
@export_category("Balancement de tête")
@export var bob_freq: float = 4.5
@export var bob_amp: float = 0.025
@export var t_bob: float = 0.0

# Bruits de pas
@export_category("Bruit Pas")
@export var bruit_pas: AudioStreamRandomizer

# Nœuds
@onready var bouton_gauche = $CanvasLayer/MarginContainer/HBoxContainer/Control/Left
@onready var bouton_avancer = $CanvasLayer/MarginContainer/HBoxContainer2/Control2/Forward
@onready var bouton_droite = $CanvasLayer/MarginContainer/HBoxContainer/Control3/Right
@onready var camera = $Camera3D
@onready var footstep_player = $AudioStreamPlayer2D

# Variables internes
var temp_vel: float = 0.0
var temp_sens: float = 0.0
var horizontal_velocity: Vector3 = Vector3.ZERO
var direction_rot: int = 0

var avance: bool = false
var tourner_gauche: bool = false
var tourner_droite: bool = false

# Animation tuto
var taille_base_gauche: Vector2 = Vector2.ONE
var taille_base_droite: Vector2 = Vector2.ONE
var taille_base_avancer: Vector2 = Vector2.ONE

var animation_gauche: Tween
var animation_droite: Tween
var animation_avancer: Tween


func _ready() -> void:
	taille_base_gauche = bouton_gauche.scale
	taille_base_droite = bouton_droite.scale
	taille_base_avancer = bouton_avancer.scale


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO

	avance = Input.is_action_pressed("Avancer") and allow_forward and not controls_locked
	tourner_gauche = Input.is_action_pressed("Gauche") and allow_left and not controls_locked
	tourner_droite = Input.is_action_pressed("Droite") and allow_right and not controls_locked

	if avance:
		direction.z -= 1.0

		if not footstep_player.is_playing() and Settings.sound:
			footstep_player.stream = bruit_pas
			footstep_player.play()
	else:
		direction.z += 1.0

	if tourner_droite:
		direction_rot = -1
	elif tourner_gauche:
		direction_rot = 1
	else:
		direction_rot = 0

	# Déplacement
	if temp_vel < SPEED and avance:
		horizontal_velocity = (transform.basis * Vector3(0, 0, direction.z)).normalized() * ACCELERATION * delta * 2
		velocity.x += horizontal_velocity.x
		velocity.z += horizontal_velocity.z
		temp_vel = min(temp_vel + sqrt(horizontal_velocity.dot(horizontal_velocity)), SPEED)

	elif temp_vel > 0.0 and not avance:
		horizontal_velocity = (transform.basis * Vector3(0, 0, direction.z)).normalized() * DECELERATION * delta * 3
		velocity.x += horizontal_velocity.x
		velocity.z += horizontal_velocity.z
		temp_vel = max(temp_vel - sqrt(horizontal_velocity.dot(horizontal_velocity)), 0.0)

	elif temp_vel == 0.0 and not avance:
		velocity.x = 0.0
		velocity.z = 0.0

	elif temp_vel == SPEED and avance:
		velocity.x = (transform.basis * Vector3(0, 0, direction.z)).normalized().x * SPEED
		velocity.z = (transform.basis * Vector3(0, 0, direction.z)).normalized().z * SPEED

	# Rotation
	if temp_sens < SENSITIVITY and (tourner_droite or tourner_gauche):
		temp_sens = min(temp_sens + delta * ACCELERATION, SENSITIVITY)
		rotate_y(direction_rot * temp_sens * delta)

	elif temp_sens > 0.0 and not (tourner_droite or tourner_gauche):
		temp_sens = max(temp_sens - delta * DECELERATION * 1.5, 0.0)
		rotate_y(direction_rot * temp_sens * delta)

	elif temp_sens == SENSITIVITY and (tourner_droite or tourner_gauche):
		rotate_y(direction_rot * delta * SENSITIVITY)

	# Gravité
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_handle_head_bob(delta)


func _handle_head_bob(delta: float) -> void:
	t_bob += delta * velocity.length() * float(is_on_floor())

	var pos := Vector3.ZERO
	pos.y = sin(t_bob * bob_freq) * bob_amp + 0.45
	pos.x = cos(t_bob * bob_freq / 2.0) * bob_amp

	camera.transform.origin = pos


func lancer_pulsation(bouton: TouchScreenButton, taille_base: Vector2, nom_animation: String) -> void:
	arreter_pulsation(nom_animation)

	bouton.scale = taille_base

	var animation := create_tween()
	animation.set_loops()
	animation.tween_property(bouton, "scale", taille_base * 1.10, 0.45)
	animation.tween_property(bouton, "scale", taille_base, 0.45)

	match nom_animation:
		"gauche":
			animation_gauche = animation
		"droite":
			animation_droite = animation
		"avancer":
			animation_avancer = animation


func arreter_pulsation(nom_animation: String) -> void:
	match nom_animation:
		"gauche":
			if animation_gauche:
				animation_gauche.kill()
				animation_gauche = null
		"droite":
			if animation_droite:
				animation_droite.kill()
				animation_droite = null
		"avancer":
			if animation_avancer:
				animation_avancer.kill()
				animation_avancer = null


func mettre_en_avant_boutons_rotation(actif: bool) -> void:
	if actif:
		lancer_pulsation(bouton_gauche, taille_base_gauche, "gauche")
		lancer_pulsation(bouton_droite, taille_base_droite, "droite")
	else:
		enlever_effets_tutoriel()


func mettre_en_avant_bouton_avancer(actif: bool) -> void:
	if actif:
		lancer_pulsation(bouton_avancer, taille_base_avancer, "avancer")
	else:
		enlever_effets_tutoriel()


func enlever_effets_tutoriel() -> void:
	arreter_pulsation("gauche")
	arreter_pulsation("droite")
	arreter_pulsation("avancer")

	bouton_gauche.scale = taille_base_gauche
	bouton_droite.scale = taille_base_droite
	bouton_avancer.scale = taille_base_avancer
