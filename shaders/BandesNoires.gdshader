shader_type canvas_item;
render_mode unshaded;

uniform float bande_haut_px = 80.0;
uniform float bande_bas_px = 80.0;
uniform float bande_gauche_px = 0.0;
uniform float bande_droite_px = 0.0;
uniform vec4 couleur_bandes : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 taille = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pos_px = UV * taille;

	bool haut = pos_px.y <= bande_haut_px;
	bool bas = pos_px.y >= taille.y - bande_bas_px;
	bool gauche = pos_px.x <= bande_gauche_px;
	bool droite = pos_px.x >= taille.x - bande_droite_px;

	if (haut || bas || gauche || droite) {
		COLOR = couleur_bandes;
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}