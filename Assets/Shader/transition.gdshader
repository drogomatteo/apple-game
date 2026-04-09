shader_type canvas_item;

uniform sampler2D mask_texture;
// Progression globale de l'effet de 0.0 (invisible) à 1.0 (recouvre l'écran)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    // On centre les coordonnées UV (de -1.0 à 1.0)
    vec2 centered_uv = UV * 2.0 - 1.0; 
    
    // On définit l'échelle. À progress = 1.0, l'échelle est de 10 (la pomme est géante).
    // À progress = 0.0, l'échelle est minuscule (0.001).
    float current_scale = max(progress * 4.0, 0.001); 
    
    // On applique l'échelle
    vec2 scaled_uv = (centered_uv / current_scale) * 0.5 + 0.5;
    
    // Par défaut, l'écran est transparent
    COLOR = vec4(0.0);
    
    // Si on se trouve à l'intérieur de l'image de la pomme
    if (scaled_uv.x >= 0.0 && scaled_uv.x <= 1.0 && scaled_uv.y >= 0.0 && scaled_uv.y <= 1.0) {
        vec4 mask = texture(mask_texture, scaled_uv);
        
        COLOR = transition_color;
        // On utilise la transparence de l'image PNG pour découper la forme
        COLOR.a = mask.a; 
    }
    
    // SÉCURITÉ : Si la transition est à son maximum, on force l'écran en noir total.
    // Cela évite de voir les coins de l'écran si la pomme ronde ne les couvre pas tout à fait.
    if (progress >= 0.99) {
        COLOR = transition_color;
    }
}