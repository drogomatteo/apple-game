extends Node3D

@export var rotation_amount: float = 0.1
@export var lerp_speed: float = 5.0
@export var max_rotation: float = 0.5 

@onready var Left = $"../CanvasLayer/MarginContainer/HBoxContainer/Control/Left"
@onready var Right = $"../CanvasLayer/MarginContainer/HBoxContainer/Control3/Right"

var direction = 0.0

func _process(delta):
	if Left.is_pressed():
		direction = 1.0
	elif Right.is_pressed():
		direction = -1.0
	else:
		direction = 0.0
		
	var target_z_rotation = clamp(direction * rotation_amount, -max_rotation, max_rotation)
		
	rotation.y = lerp_angle(rotation.y, -target_z_rotation, lerp_speed * delta)
		
	direction = lerp(direction, 0.0, 0.1)
