extends Control

@onready var sound_button := $CenterContainer/VBoxContainer/HBoxContainer/Sound
@onready var colour_blind_button := $CenterContainer/VBoxContainer/Daltonien


func _ready() -> void:
	sound_button.button_pressed = Settings.sound
	colour_blind_button.select(Settings.colour_bind)


func _on_back_button_pressed() :
	FileManager.save_game()
	get_parent().get_parent().show_menu()


func _on_sound_toggled(value: bool) :
	Settings.set_sound(value)


func _on_daltonien_item_selected(index: int) :
	Settings.set_colour_bind(index)
