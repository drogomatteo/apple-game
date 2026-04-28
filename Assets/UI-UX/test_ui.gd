extends Control

@onready var panel_to_export = $MarginContainer2/HBoxContainer/Control/Left

func export_panel_png():
	await get_tree().process_frame

	var original_size: Vector2 = panel_to_export.size
	var original_scale: Vector2 = panel_to_export.scale

	# Taille visuelle finale (ce que tu vois à l'écran)
	var export_size := Vector2(
		original_size.x * abs(original_scale.x),
		original_size.y * abs(original_scale.y)
	).ceil()

	var subviewport := SubViewport.new()
	subviewport.disable_3d = true
	subviewport.transparent_bg = true
	subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	subviewport.size = Vector2i(export_size.x, export_size.y)

	var root := Control.new()
	root.size = export_size
	root.custom_minimum_size = export_size

	var copy := panel_to_export.duplicate()

	# On remet la copie dans un contexte propre
	copy.anchor_left = 0.0
	copy.anchor_top = 0.0
	copy.anchor_right = 0.0
	copy.anchor_bottom = 0.0
	copy.offset_left = 0.0
	copy.offset_top = 0.0

	# Important : on garde le scale original
	copy.scale = original_scale

	# Très important pour que le scale parte du coin haut-gauche
	copy.pivot_offset = Vector2.ZERO
	copy.position = Vector2.ZERO
	copy.rotation = 0.0

	# On garde la taille logique d'origine
	copy.size = original_size
	copy.custom_minimum_size = original_size

	# Si le thème venait du parent
	copy.theme = theme

	root.add_child(copy)
	subviewport.add_child(root)
	add_child(subviewport)

	await RenderingServer.frame_post_draw

	var image := subviewport.get_texture().get_image()
	image.save_png("/home/eva/Projects/Projet Alzeimer Godot/apple-game/Assets/UI-UX/Images/icons/TutoLeftButton.png")

	subviewport.queue_free()

	print("PNG exporté : /home/eva/Pictures/My_Panel.png")

func _ready():
	export_panel_png()
