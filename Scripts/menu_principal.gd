extends Node

@onready var niveaux = preload("res://Scenes/main.tscn")
@onready var compte = preload("res://Scenes/interface.tscn")

func _on_start_button_button_down() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_packed(niveaux)


func _on_quit_button_button_down() -> void:
	get_tree().quit()


func _on_option_button_down() -> void:
	$"Couche 1/MenuPrincipal/VBoxContainer".set_visible(false)
	$"Couche 1/MenuPrincipal/HBoxContainer".set_visible(false)
	
	$"Couche 2".set_visible(true)
	$"Couche 2/Options/VBoxContainer/Daltonien".select(Paramètre.daltonien)


func _on_compte_button_down() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_packed(compte)


func _on_back_button_button_down() -> void:
	$"Couche 1/MenuPrincipal/VBoxContainer".set_visible(true)
	$"Couche 1/MenuPrincipal/HBoxContainer".set_visible(true)
	
	$"Couche 2".set_visible(false)


func _on_sound_toggled(toggled_on: bool) -> void:
	Paramètre.sound = toggled_on

func _on_daltonien_item_selected(index: int) -> void:
	Paramètre.definir_mode_daltonien(index)
