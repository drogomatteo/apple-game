extends CanvasLayer

func update_colour_blind(mode: int) :
	var material := $ColorRect.material as ShaderMaterial
	material.set_shader_parameter("mode", mode)
