shader_type canvas_item;

// La texture de l'écran pour le flou
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// La puissance du flou
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
// La couleur d'assombrissement (Noir à 50% d'opacité par défaut)
uniform vec4 mix_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
    // 1. On récupère la couleur floutée de l'arrière-plan
    vec4 blurred_color = textureLod(screen_texture, SCREEN_UV, blur_amount);
    
    // 2. On mélange la couleur floutée avec notre couleur d'assombrissement
    // La fonction "mix" utilise l'opacité (alpha / mix_color.a) de notre couleur pour doser l'effet
    COLOR = mix(blurred_color, mix_color, mix_color.a);
}