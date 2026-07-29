shader_type canvas_item;

uniform float ratio_parfait : hint_range(0.05, 1.0) = 0.35;
uniform float ratio_correct : hint_range(0.05, 1.0) = 0.7;
uniform float progression_duree : hint_range(0.0, 1.0) = 0.0;
uniform float progression_rythme : hint_range(0.0, 1.0) = 0.0;
uniform float point_actif : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 position = (UV - vec2(0.5)) * 2.0;
	float distance_centre = length(position);
	float antialias = fwidth(distance_centre) * 1.5;
	float disque_exterieur = 1.0 - smoothstep(1.0 - antialias, 1.0 + antialias, distance_centre);
	float disque_correct = 1.0 - smoothstep(ratio_correct - antialias, ratio_correct + antialias, distance_centre);
	float disque_parfait = 1.0 - smoothstep(ratio_parfait - antialias, ratio_parfait + antialias, distance_centre);
	float rayon_rythme = mix(1.2, ratio_parfait, progression_rythme);
	float anneau_rythme = 1.0 - smoothstep(0.018, 0.045, abs(distance_centre - rayon_rythme));
	vec4 couleur = vec4(0.08, 0.08, 0.08, 0.72) * disque_exterieur;
	couleur = mix(couleur, vec4(0.52, 0.52, 0.52, 0.82), disque_correct);
	couleur = mix(couleur, vec4(0.92, 0.92, 0.92, 0.95), disque_parfait);
	couleur = mix(couleur, vec4(1.0), anneau_rythme * point_actif);
	couleur.a *= 1.0 - smoothstep(0.82, 1.0, progression_duree);
	COLOR = couleur;
}
