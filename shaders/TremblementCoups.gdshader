shader_type canvas_item;

uniform float amplitude_tremblement = 0.0; // force visuelle en pixels
uniform float vitesse_tremblement = 120.0; // vitesse du shake

void vertex() {
    float dx = (sin(TIME * vitesse_tremblement) + sin(TIME * vitesse_tremblement * 0.73)) * 0.5;
    float dy = (cos(TIME * vitesse_tremblement * 1.21) + sin(TIME * vitesse_tremblement * 1.9)) * 0.5;
    VERTEX += vec2(dx, dy) * amplitude_tremblement;
}
