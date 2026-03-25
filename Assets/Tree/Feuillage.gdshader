shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

// =====================
// TEXTURES
// =====================
uniform sampler2D ground_noise;
uniform float ground_noise_scale = 0.2;
uniform sampler2D foliage_tex : source_color;
uniform bool use_red_as_alpha = true; // true si ta texture stocke l'alpha dans R, sinon false pour A

// =====================
// COLORS
// =====================
uniform vec3 top_color : source_color = vec3(0.24, 0.52, 0.28);
uniform vec3 bottom_color : source_color = vec3(0.10, 0.24, 0.12);
uniform vec3 tint_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float color_variation_strength : hint_range(0.0, 1.0) = 0.18;

// =====================
// SHAPE / CUTOUT
// =====================
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.2;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.0;

// =====================
// BILLBOARDING
// =====================
uniform bool billboard_to_camera = true;
uniform float quad_width = 1.0;
uniform float quad_height = 1.0;
uniform float random_yaw_strength : hint_range(0.0, 6.28318) = 3.14159; // lit UV2.x
uniform float camera_facing_strength : hint_range(0.0, 1.0) = 1.0;

// =====================
// LIGHTING STYLE
// =====================
uniform bool normals_up = true;
uniform float fake_wrap : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.95;
uniform float specular : hint_range(0.0, 1.0) = 0.08;
uniform float translucency_strength : hint_range(0.0, 2.0) = 0.35;

// =====================
// WIND
// =====================
uniform bool use_wind = true;
uniform float wind_speed = 1.2;
uniform float wind_strength = 0.06;
uniform float flutter_strength = 0.02;
uniform float noise_scale = 2.3;
uniform vec2 wind_dir = vec2(1.0, 0.2);

// =====================
// VARYINGS
// =====================
varying float v_height;
varying float v_random;
varying vec3 v_world_pos;
varying vec3 v_world_normal;

mat2 rot2(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(
        vec2(c, -s),
        vec2(s,  c)
    );
}

float hash11(float p) {
    return fract(sin(p * 127.1) * 43758.5453123);
}


void vertex() {
    v_random = UV2.x;
    v_height = clamp(UV.y, 0.0, 1.0);

    // UV centré en [-1, 1]
    vec2 centered_uv = UV * 2.0 - 1.0;
    centered_uv.y *= -1.0; // IMPORTANT : garde le haut/bas correct

    // variation de taille
    float size_variation = mix(0.8, 1.2, v_random);

    // taille du quad
    vec2 scaled_uv = centered_uv * vec2(quad_width, quad_height) * size_variation;

    // BILLBOARD correct (clé)
    vec4 offset = vec4(scaled_uv, 0.0, 0.0) * VIEW_MATRIX;

    // léger "gonflement" pour éviter le look trop plat
    offset.xyz += normalize(vec3(
        sin(v_random * 12.3),
        0.0,
        cos(v_random * 8.7)
    )) * 0.04;

    // vent (le haut bouge plus que le bas)
    if (use_wind) {
        vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

        float gust =
            sin((world_pos.x + world_pos.z) * noise_scale + TIME * wind_speed) *
            cos((world_pos.z - world_pos.x) * (noise_scale * 0.73) + TIME * (wind_speed * 0.83));

        float height_factor = clamp(UV.y, 0.0, 1.0);
        float sway = gust * wind_strength * height_factor;

        vec3 wd = normalize(vec3(wind_dir.x, 0.0, wind_dir.y));
        offset.xyz += wd * sway;
    }

    // application
    VERTEX += offset.xyz;

    // normales vers le haut (style doux)
    if (normals_up) {
        NORMAL = vec3(0.0, 1.0, 0.0);
    }

    // (optionnel) world pos pour debug
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

    // 👉 position sol (important)
    vec2 p = v_world_pos.xz * ground_noise_scale;

    // 👉 bruit cohérent avec herbe
    float noise = texture(ground_noise, p).r;

    vec3 gradient = mix(bottom_color, top_color, h);
    gradient *= mix(0.9, 1.1, noise);

    vec3 albedo_col = gradient * tint_color;
    albedo_col *= 1.0 + random_tint * color_variation_strength;

    vec3 painted = mix(albedo_col * 0.9, albedo_col * 1.1, noise);
    ALBEDO = painted * tex.rgb;

    ROUGHNESS = roughness;
    SPECULAR = specular;
}


void light() {
    vec3 N = normalize(NORMAL);
    vec3 L = normalize(LIGHT);

    float ndl = dot(N, L);
    ndl = ndl * 0.5 + 0.5;
    ndl = smoothstep(0.2, 0.8, ndl);

    float wrapped = clamp((ndl + fake_wrap) / (1.0 + fake_wrap), 0.0, 1.0);

    // éclairage principal doux
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * ATTENUATION * wrapped;

    // légère translucidité façon feuillage
    float backlight = pow(clamp(dot(-N, L), 0.0, 1.0), 2.0);
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * backlight * translucency_strength * 0.35;
}