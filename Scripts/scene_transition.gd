extends CanvasLayer

@export var switch_duration : float = 1.0


var apple_colors : Array[Color] = [
	Color("a01414"),
	Color("14a014")
]


func _ready():
	$ColorRect.visible = false
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ColorRect.material.set_shader_parameter("progress", 0.0)


func to_snake_case(text : String) -> String:
	var result = ""
	for i in range(text.length()):
		var c = text[i]
		if c >= "A" and c <= "Z":
			if i > 0:
				result += "_"
			result += c.to_lower()
		else:
			result += c
	return result


func go_to_scene(scene : String):

	var scene_name = to_snake_case(scene)

	var random_color = apple_colors.pick_random()
	$ColorRect.material.set_shader_parameter("transition_color", random_color)

	$ColorRect.visible = true
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween = get_tree().create_tween()
	tween.tween_property($ColorRect.material, "shader_parameter/progress", 1.0, switch_duration / 2.0)
	await tween.finished


	if scene_name == "game":
		get_tree().change_scene_to_file("res://Scenes/main.tscn")
	elif scene_name == "interface":
		get_tree().change_scene_to_file("res://Scenes/Interface.tscn")
	else:
		var interface = get_tree().get_meta("interface")
		if interface:
			interface.call("show_" + scene_name)
		else:
			print("Interface introuvable")

	# PHASE 2
	tween = get_tree().create_tween()
	tween.tween_property($ColorRect.material, "shader_parameter/progress", 0.0, switch_duration / 2.0)
	await tween.finished

	$ColorRect.visible = false
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ColorRect.material.set_shader_parameter("progress", 0.0)
