extends CanvasLayer

@export var switch_duration : float = 1.0

# On définit nos couleurs. Vous pouvez ajuster les codes hexadécimaux
# pour avoir le rouge et le vert parfaits pour votre jeu !
var apple_colors : Array[Color] = [
	Color("a01414"), # Rouge pomme
	Color("14a014")  # Vert pomme
]

func _ready() -> void:
	$ColorRect.visible = false
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ColorRect.material.set_shader_parameter("progress", 0.0)

func go_to_scene(scene : String):
	# --- NOUVEAUTÉ : Choix aléatoire de la couleur ---
	var random_color = apple_colors.pick_random()
	# On envoie la couleur choisie au shader
	$ColorRect.material.set_shader_parameter("transition_color", random_color)
	# -------------------------------------------------

	$ColorRect.visible = true
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# PHASE 1 : La pomme grandit
	tween.tween_property($ColorRect.material, "shader_parameter/progress", 1.0, switch_duration / 2.0)
	await tween.finished
	
	# CHANGEMENT DE SCÈNE
	get_tree().change_scene_to_file("res://Scenes/%s.tscn" % scene)
	
	# PHASE 2 : La pomme rétrécit
	tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property($ColorRect.material, "shader_parameter/progress", 0.0, switch_duration / 2.0)
	
	await tween.finished
	
	# Nettoyage
	$ColorRect.visible = false
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ColorRect.material.set_shader_parameter("progress", 0.0)
