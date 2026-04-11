shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform bool billboard = false;

uniform sampler2D shape_texture;

group_uniforms Colors;
uniform sampler2D noise_texture;
uniform sampler2D color_gradient;

group_uniforms Transparency;
uniform float alpha_cut_start : hint_range(0.0, 1.0, 0.05) = 0.1;
uniform float alpha_cut_end : hint_range(0.0, 1.0, 0.05) = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	if (billboard) {
		mat4 billboard_matrix = mat4(
			MAIN_CAM_INV_VIEW_MATRIX[0],
			MAIN_CAM_INV_VIEW_MATRIX[1],
			MAIN_CAM_INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);
		MODELVIEW_MATRIX = VIEW_MATRIX * billboard_matrix;
	}

	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	float shape_value = texture(shape_texture, UV).r;

	float noise_value = texture(noise_texture, world_pos.xz * 0.05).r;
	vec3 grass_color = texture(color_gradient, vec2(noise_value, 0.0)).rgb;

	float alpha = clamp(
		(shape_value - alpha_cut_start) / (alpha_cut_end - alpha_cut_start),
		0.0,
		1.0
	);

	if (alpha < 0.1) {
		discard;
	}

	ALBEDO = grass_color;
}