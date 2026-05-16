shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float intensite : hint_range(0.0, 1.0) = 0.0;
uniform float progression_onde : hint_range(0.0, 1.0) = 0.0;
uniform vec2 direction_dash = vec2(1.0, 0.0);
uniform float distorsion_px : hint_range(0.0, 300.0) = 170.0;
uniform float epaisseur_onde : hint_range(0.01, 0.5) = 0.16;
uniform float aberration_px : hint_range(0.0, 40.0) = 8.0;
uniform float vignette_intensite : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_opacite : hint_range(0.0, 1.0) = 1.0;
uniform float vignette_depart : hint_range(0.0, 1.0) = 0.48;
uniform float vignette_fin : hint_range(0.0, 1.5) = 1.05;
uniform vec4 vignette_couleur : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 direction_normale = normalize(direction_dash);
	vec2 depuis_centre = SCREEN_UV - vec2(0.5, 0.5);
	float distance_ecran = length(depuis_centre) / 0.70710678;
	vec2 direction_radiale = distance_ecran > 0.0001 ? normalize(depuis_centre) : direction_normale;

	float alignement = dot(normalize(depuis_centre + direction_normale * 0.001), direction_normale);
	float masque_direction = 0.7 + smoothstep(-0.65, 1.0, alignement) * 0.3;

	float rayon_onde = progression_onde * 1.18;
	float onde = 1.0 - smoothstep(0.0, epaisseur_onde, abs(distance_ecran - rayon_onde));
	float trainee = smoothstep(rayon_onde - 0.22, rayon_onde, distance_ecran)
		* (1.0 - smoothstep(rayon_onde, rayon_onde + 0.45, distance_ecran));
	float force = clamp(intensite, 0.0, 1.0) * masque_direction;

	vec2 decalage_radial = direction_radiale * SCREEN_PIXEL_SIZE * distorsion_px * onde * force;
	vec2 decalage_dash = direction_normale * SCREEN_PIXEL_SIZE * distorsion_px * trainee * force * 0.45;
	vec2 decalage = decalage_radial + decalage_dash;

	vec2 uv = SCREEN_UV - decalage;
	float masque_aberration_bords = smoothstep(0.25, 1.0, distance_ecran);
	vec2 aberration = direction_normale * SCREEN_PIXEL_SIZE * aberration_px * (onde + trainee * 0.35) * force * masque_aberration_bords;

	float rouge = texture(screen_tex, uv + aberration).r;
	float vert = texture(screen_tex, uv).g;
	float bleu = texture(screen_tex, uv - aberration).b;
	vec3 couleur = vec3(rouge, vert, bleu);

	vec2 taille_ecran = 1.0 / SCREEN_PIXEL_SIZE;
	float ratio = taille_ecran.x / max(taille_ecran.y, 1.0);
	vec2 centre_corrige = vec2(depuis_centre.x * ratio, depuis_centre.y);
	float distance_vignette = length(centre_corrige) / length(vec2(0.5 * ratio, 0.5));
	float vignette = smoothstep(vignette_depart, vignette_fin, distance_vignette);
	vignette *= vignette_intensite * vignette_opacite * vignette_couleur.a * clamp(intensite, 0.0, 1.0);

	couleur = mix(couleur, vignette_couleur.rgb, vignette);
	COLOR = vec4(couleur, 1.0);
}
