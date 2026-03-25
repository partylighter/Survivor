shader_type canvas_item;

uniform float bob_amp = 3.0;
uniform float bob_freq = 2.0;
uniform float breath_amp = 0.04;
uniform float breath_freq = 1.2;

instance uniform float seed = 0.0;

void vertex() {
	float t1 = (TIME * TAU * bob_freq) + seed;
	float t2 = (TIME * TAU * breath_freq) + (seed * 0.37);

	VERTEX.y += sin(t1) * bob_amp;

	float b = 1.0 + sin(t2) * breath_amp;
	VERTEX *= b;
}
