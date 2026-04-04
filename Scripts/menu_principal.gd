extends Control
@onready var niveaux = preload("res://Scenes/main.tscn")
@onready var compte = preload("res://Scenes/interface.tscn")



func _on_start_button_button_down() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_packed(niveaux)


func _on_quit_button_button_down() -> void:
	get_tree().quit()


func _on_option_button_down() -> void:
	pass # Replace with function body.


func _on_compte_button_down() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_packed(compte)
