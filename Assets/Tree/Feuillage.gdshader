shader_type spatial;
render_mode blend_mix, depth_prepass_alpha,  diffuse_burley, specular_schlick_ggx, shadows_disabled;

// TEXTURES
uniform sampler2D ground_noise;
uniform float ground_noise_scale = 0.2;
uniform sampler2D foliage_tex : source_color;
uniform bool use_red_as_alpha = true;

// COLORS
uniform vec3 top_color : source_color = vec3(0.82, 0.76, 0.42);
uniform vec3 bottom_color : source_color = vec3(0.42, 0.34, 0.16);
uniform vec3 tint_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float color_variation_strength : hint_range(0.0, 1.0) = 0.10;
uniform float noise_brightness_min : hint_range(0.0, 2.0) = 0.92;
uniform float noise_brightness_max : hint_range(0.0, 2.0) = 1.08;

// SHAPE / CUTOUT
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.2;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.03;

// CARD SHAPE / VOLUME
uniform float quad_width = 1.0;
uniform float quad_height = 1.0;
uniform float size_variation_min : hint_range(0.1, 2.0) = 0.85;
uniform float size_variation_max : hint_range(0.1, 2.0) = 1.15;
uniform float puff_strength : hint_range(0.0, 0.3) = 0.08;
uniform float puff_upward_bias : hint_range(0.0, 1.0) = 0.15;

// BILLBOARDING
uniform bool billboard_to_camera = false;

// LIGHTING STYLE
uniform bool normals_up = false;
uniform float fake_wrap : hint_range(0.0, 1.0) = 0.20;
uniform float roughness : hint_range(0.0, 1.0) = 0.90;
uniform float specular : hint_range(0.0, 1.0) = 0.03;
uniform float translucency_strength : hint_range(0.0, 2.0) = 0.18;

// WIND
uniform bool use_wind = true;
uniform float wind_speed = 1.1;
uniform float wind_strength = 0.045;
uniform float flutter_strength = 0.015;
uniform float noise_scale = 2.0;
uniform vec2 wind_dir = vec2(1.0, 0.2);

// VARYINGS
varying float v_height;
varying float v_random;
varying vec3 v_world_pos;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453123);
}

void vertex() {
	v_random = UV2.x;
	v_height = clamp(UV.y, 0.0, 1.0);

	vec2 centered_uv = UV * 2.0 - 1.0;
	centered_uv.y *= -1.0;

	float size_variation = mix(size_variation_min, size_variation_max, v_random);
	vec2 scaled_uv = centered_uv * vec2(quad_width, quad_height) * size_variation;

	if (billboard_to_camera) {
		vec4 offset = vec4(scaled_uv, 0.0, 0.0) * VIEW_MATRIX;
		VERTEX += offset.xyz;
	} else {
		VERTEX.xy += scaled_uv;
	}

	vec3 puff_dir = normalize(vec3(
		sin(v_random * 12.3),
		puff_upward_bias,
		cos(v_random * 8.7)
	));
	VERTEX += puff_dir * puff_strength;

	if (use_wind) {
		vec3 world_pos_before_wind = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

		float gust =
			sin((world_pos_before_wind.x + world_pos_before_wind.z) * noise_scale + TIME * wind_speed) *
			cos((world_pos_before_wind.z - world_pos_before_wind.x) * (noise_scale * 0.73) + TIME * (wind_speed * 0.83));

		float height_factor = clamp(UV.y, 0.0, 1.0);
		float sway = gust * wind_strength * height_factor;

		vec3 wd = normalize(vec3(wind_dir.x, 0.0, wind_dir.y));
		VERTEX += wd * sway;

		float flutter = sin(TIME * (wind_speed * 1.7) + v_random * 21.7) * flutter_strength * height_factor;
		VERTEX.xz += vec2(flutter, -flutter * 0.5);
	}

	if (normals_up) {
		NORMAL = vec3(0.0, 1.0, 0.0);
	}

	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(foliage_tex, UV);
	float mask = use_red_as_alpha ? tex.r : tex.a;

	if (edge_softness <= 0.001) {
		ALPHA = mask;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	} else {
		float softened = smoothstep(
			alpha_scissor_threshold - edge_softness,
			alpha_scissor_threshold + edge_softness,
			mask
		);
		ALPHA = softened;
		ALPHA_SCISSOR_THRESHOLD = 0.001;
	}

	float random_tint = (hash11(v_random * 97.13) - 0.5) * 2.0;
	float h = pow(v_height, 0.8);

	vec2 p = v_world_pos.xz * ground_noise_scale;
	float noise = texture(ground_noise, p).r;

	vec3 gradient = mix(bottom_color, top_color, h);
	gradient *= mix(noise_brightness_min, noise_brightness_max, noise);

	vec3 albedo_col = gradient * tint_color;
	albedo_col *= 1.0 + random_tint * color_variation_strength;

	vec3 painted = mix(albedo_col * 0.96, albedo_col * 1.04, noise);
	ALBEDO = painted;

	ROUGHNESS = roughness;
	SPECULAR = specular;
}

void light() {
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(LIGHT);

	float ndl = max(dot(N, L), 0.0);
	float wrapped = clamp((ndl + fake_wrap) / (1.0 + fake_wrap), 0.0, 1.0);

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * ATTENUATION * wrapped;

	float backlight = pow(clamp(dot(-N, L), 0.0, 1.0), 2.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * backlight * translucency_strength * 0.2;
}
