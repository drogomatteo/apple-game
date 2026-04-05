extends Control
@onready var niveaux = preload("res://Scenes/main.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_start_button_button_down() -> void:
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_packed(niveaux)


func _on_quit_button_button_down() -> void:
	get_tree().quit()
