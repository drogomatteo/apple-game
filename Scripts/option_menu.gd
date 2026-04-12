extends Control

@onready var sound_button = $CenterContainer/VBoxContainer/Sound
@onready var daltonien_button = $CenterContainer/VBoxContainer/Daltonien


func _ready():
	sound_button.button_pressed = Paramètre.sound
	daltonien_button.select(Paramètre.daltonien)


func _on_back_button_pressed():
	GestionFichier.save_data()
	get_parent().get_parent().show_menu()



func _on_sound_toggled(toggled_on: bool):
	Paramètre.sound = toggled_on


func _on_daltonien_item_selected(index: int):
	Paramètre.definir_mode_daltonien(index)
