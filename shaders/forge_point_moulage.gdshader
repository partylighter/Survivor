shader_type canvas_item;
render_mode unshaded;

uniform vec4 couleur_point : source_color = vec4(0.35, 0.35, 0.38, 1.0);
uniform vec4 couleur_contour : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float progression : hint_range(0.0, 1.0) = 0.0;
uniform float point_actif : hint_range(0.0, 1.0) = 0.0;
uniform float avertissement : hint_range(0.0, 1.0) = 0.0;
uniform float secousse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 position = UV - vec2(0.5);
	float distance_centre = length(position);
	float douceur = max(fwidth(distance_centre) * 1.5, 0.002);
	float disque = 1.0 - smoothstep(0.29 - douceur, 0.29 + douceur, distance_centre);
	float contour_exterieur = 1.0 - smoothstep(0.36 - douceur, 0.36 + douceur, distance_centre);
	float contour_interieur = 1.0 - smoothstep(0.32 - douceur, 0.32 + douceur, distance_centre);
	float contour = max(contour_exterieur - contour_interieur, 0.0);
	float anneau_exterieur = 1.0 - smoothstep(0.48 - douceur, 0.48 + douceur, distance_centre);
	float anneau_interieur = 1.0 - smoothstep(0.42 - douceur, 0.42 + douceur, distance_centre);
	float anneau = max(anneau_exterieur - anneau_interieur, 0.0);
	float angle = atan(position.y, position.x) + 1.57079632679;
	if (angle < 0.0) {
		angle += 6.28318530718;
	}
	float portion = angle / 6.28318530718;
	float arc_progression = anneau * step(portion, progression) * point_actif;
	float pulsation = 0.55 + 0.45 * sin(TIME * 12.0);
	float halo = anneau * max(avertissement * pulsation, secousse);
	vec4 couleur = couleur_point * disque;
	couleur = mix(couleur, couleur_contour, contour);
	couleur = mix(couleur, couleur_contour, max(arc_progression, halo));
	couleur.a = max(max(disque, contour), max(arc_progression, halo));
	COLOR = couleur;
}
