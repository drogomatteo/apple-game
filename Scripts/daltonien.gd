extends CanvasLayer


func _mettre_a_jour_daltonien(nouveau_mode : int):
	var mon_materiel = $ColorRect.material as ShaderMaterial
	mon_materiel.set_shader_parameter("mode", nouveau_mode)
	print("[DALT] Mode daltonien mis à jour")
