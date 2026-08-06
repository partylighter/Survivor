shader_type canvas_item;

uniform float vitesse = 2.5;

uniform float amplitude_x = 6.0;
uniform float amplitude_y = 4.0;

uniform float agitation_x = 2.0;
uniform float agitation_y = 1.5;

uniform float rotation_max = 0.08;

void vertex() {
	float t = TIME * vitesse;

	float deplacement_x =
		sin(t * 0.9) * amplitude_x
		+ sin(t * 2.7 + 1.4) * agitation_x
		+ cos(t * 4.1) * agitation_x * 0.35;

	float deplacement_y =
		cos(t * 1.15) * amplitude_y
		+ sin(t * 3.3 + 0.8) * agitation_y
		+ cos(t * 5.6) * agitation_y * 0.25;

	float angle =
		sin(t * 1.7) * rotation_max
		+ sin(t * 4.3) * rotation_max * 0.25;

	float c = cos(angle);
	float s = sin(angle);

	vec2 centre = vec2(0.0);
	vec2 position = VERTEX - centre;

	position = vec2(
		position.x * c - position.y * s,
		position.x * s + position.y * c
	);

	VERTEX = position + centre + vec2(deplacement_x, deplacement_y);
}