shader_type canvas_item;
render_mode unshaded;

uniform float vitesse = 0.12;
uniform float echelle = 2.4;
uniform float contraste = 1.45;

uniform int pixels_x = 320;
uniform int pixels_y = 180;
uniform float sym_mix = 1.0;

uniform float skull_scale = 0.92;
uniform float skull_soft = 0.08;
uniform float skull_fill = 1.0;
uniform float skull_glow = 0.22;

uniform vec4 c_froid  : source_color = vec4(0.23, 0.17, 0.10, 1.0);
uniform vec4 c_chaud  : source_color = vec4(0.96, 0.55, 0.12, 1.0);
uniform vec4 c_rouge  : source_color = vec4(0.78, 0.12, 0.06, 1.0);
uniform vec4 c_jaune  : source_color = vec4(1.00, 0.92, 0.25, 1.0);
uniform vec4 c_vert   : source_color = vec4(0.42, 0.66, 0.22, 1.0);

float hash21(vec2 p){
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

float fbm(vec2 p){
	float v = 0.0;
	float a = 0.5;
	for(int k=0;k<5;k++){
		v += a * noise(p);
		p = p * 2.02 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

vec4 heatmap(float x){
	float t0 = smoothstep(0.00, 0.35, x);
	vec4 col = mix(c_froid, c_chaud, t0);

	float t1 = smoothstep(0.35, 0.62, x);
	col = mix(col, c_rouge, t1);

	float t2 = smoothstep(0.62, 0.82, x);
	col = mix(col, c_jaune, t2);

	float t3 = smoothstep(0.82, 0.98, x);
	col = mix(col, c_vert, t3);

	return col;
}

void fragment(){
	vec2 uv = UV;
	vec2 q = vec2(float(max(pixels_x, 1)), float(max(pixels_y, 1)));
	uv = (floor(uv * q) + 0.5) / q;

	vec2 uv_m = uv;
	uv_m.x = abs(uv_m.x - 0.5) + 0.5;
	uv = mix(uv, uv_m, clamp(sym_mix, 0.0, 1.0));

	float t = TIME * vitesse;

	vec2 p = (uv - 0.5) * echelle;

	vec2 flow = vec2(fbm(p + t*0.2), fbm(p + vec2(5.2,1.7) - t*0.18));
	float n = fbm(p + flow*1.4 + vec2(t*0.35, -t*0.22));
	n = pow(clamp(n, 0.0, 1.0), 1.0 / max(contraste, 0.001));

	float centre = 1.0 - smoothstep(0.08, 0.70, length((uv - 0.5) * vec2(1.2, 0.8)));

	float x = n * 0.55 + centre * 0.30;

	x = clamp(x, 0.0, 1.0);
	COLOR = heatmap(x);
}
