shader_type canvas_item;

// Mode daltonien : 0=Normal, 1=Protanopia, 2=Deuteranopia, 3=Tritanopia
uniform int mode : hint_range(0, 3) = 0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 c = texture(SCREEN_TEXTURE, SCREEN_UV);
    vec3 col = c.rgb;
    vec3 target_col = col;

    if (mode == 1) { // Protanopia (Rouge)
        target_col.r = 0.567 * col.r + 0.433 * col.g;
        target_col.g = 0.558 * col.r + 0.442 * col.g;
        target_col.b = 0.242 * col.g + 0.758 * col.b;
    } else if (mode == 2) { // Deuteranopia (Vert)
        target_col.r = 0.625 * col.r + 0.375 * col.g;
        target_col.g = 0.7 * col.r + 0.3 * col.g;
        target_col.b = 0.3 * col.g + 0.7 * col.b;
    } else if (mode == 3) { // Tritanopia (Bleu)
        target_col.r = 0.95 * col.r + 0.05 * col.g;
        target_col.g = 0.433 * col.g + 0.567 * col.b;
        target_col.b = 0.475 * col.g + 0.525 * col.b;
    }

    // Mélange optionnel (0.0 = original, 1.0 = corrigé)
    COLOR = vec4(mix(col, target_col, 1.0), c.a);
}
