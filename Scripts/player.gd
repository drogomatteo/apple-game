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
@onready var left_button = $CanvasLayer/MarginContainer/HBoxContainer/Control/Left
@onready var forward_button = $CanvasLayer/MarginContainer/HBoxContainer2/Control2/Forward
@onready var right_button = $CanvasLayer/MarginContainer/HBoxContainer/Control3/Right
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
var left_default_scale: Vector2 = Vector2.ONE
var right_default_scale: Vector2 = Vector2.ONE
var forward_default_scale: Vector2 = Vector2.ONE

var left_tween: Tween
var right_tween: Tween
var forward_tween: Tween


func _ready() -> void:
	left_default_scale = left_button.scale
	right_default_scale = right_button.scale
	forward_default_scale = forward_button.scale


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


func _start_pulse(button: TouchScreenButton, base_scale: Vector2, tween_name: String) -> void:
	_stop_pulse_by_name(tween_name)

	button.scale = base_scale

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(button, "scale", base_scale * 1.10, 0.45)
	tween.tween_property(button, "scale", base_scale, 0.45)

	match tween_name:
		"left":
			left_tween = tween
		"right":
			right_tween = tween
		"forward":
			forward_tween = tween


func _stop_pulse_by_name(tween_name: String) -> void:
	match tween_name:
		"left":
			if left_tween:
				left_tween.kill()
				left_tween = null
		"right":
			if right_tween:
				right_tween.kill()
				right_tween = null
		"forward":
			if forward_tween:
				forward_tween.kill()
				forward_tween = null


func highlight_rotation_buttons(active: bool) -> void:
	if active:
		_start_pulse(left_button, left_default_scale, "left")
		_start_pulse(right_button, right_default_scale, "right")
	else:
		clear_tutorial_highlights()


func highlight_forward_button(active: bool) -> void:
	if active:
		_start_pulse(forward_button, forward_default_scale, "forward")
	else:
		clear_tutorial_highlights()


func clear_tutorial_highlights() -> void:
	_stop_pulse_by_name("left")
	_stop_pulse_by_name("right")
	_stop_pulse_by_name("forward")

	left_button.scale = left_default_scale
	right_button.scale = right_default_scale
	forward_button.scale = forward_default_scale
