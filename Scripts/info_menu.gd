extends Control

func get_interface() -> Node:
	if get_tree().has_meta("interface"):
		return get_tree().get_meta("interface")

	return null

func go_next_screen():
	var interface = get_interface()

	if interface:
		interface.show_menu()
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Interface.tscn")

	queue_free()

func _on_texture_button_pressed() -> void:
	go_next_screen()
