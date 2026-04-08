shader_type canvas_item;

// On récupère la texture de l'écran avec la capacité de générer des mipmaps (nécessaire pour le flou)
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Paramètre ajustable depuis l'inspecteur
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;

void fragment() {
    // textureLod permet de lire une version "réduite" (mipmap) de l'écran, ce qui crée l'effet de flou
    vec4 color = textureLod(screen_texture, SCREEN_UV, blur_amount);
    COLOR = color;
}