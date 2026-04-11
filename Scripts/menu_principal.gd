extends Node

var cheminJeu =  "main"
var cheminCompte = "interface"

func _ready() -> void:
	get_tree().paused = false
	GestionFichier.load_game()

func _on_start_button_button_down() -> void:
	Transition.go_to_scene(cheminJeu)


func _on_quit_button_button_down() -> void:
	GestionFichier.save_data()
	get_tree().quit()


func _on_option_button_down() -> void:
	$"Couche 1/MenuPrincipal/VBoxContainer".set_visible(false)
	$"Couche 1/MenuPrincipal/HBoxContainer".set_visible(false)
	
	$"Couche 2".set_visible(true)
	$"Couche 2/Options/VBoxContainer/Daltonien".select(Paramètre.daltonien)
	$"Couche 2/Options/VBoxContainer/Sound".set_pressed(Paramètre.sound)


func _on_compte_button_down() -> void:
	Transition.go_to_scene(cheminCompte)


func _on_back_button_button_down() -> void:
	$"Couche 1/MenuPrincipal/VBoxContainer".set_visible(true)
	$"Couche 1/MenuPrincipal/HBoxContainer".set_visible(true)
	
	$"Couche 2".set_visible(false)


func _on_sound_toggled(toggled_on: bool) -> void:
	Paramètre.sound = toggled_on

func _on_daltonien_item_selected(index: int) -> void:
	Paramètre.definir_mode_daltonien(index)
