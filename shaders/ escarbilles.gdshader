shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float densite = 1.0;          // 0..2
uniform float taille_px = 2.0;        // taille moyenne des braises (en pixels)
uniform float vitesse = 0.35;         // vitesse montée
uniform float turbulence = 1.2;       // dérive horizontale
uniform float scintillement = 1.4;    // flicker
uniform float duree = 2.6;            // durée de vie moyenne (s)

uniform vec2 vent = vec2(0.20, 1.0);  // x = drift, y = montée (garde y > 0)
uniform float gravite = 0.0;          // >0 = retombe un peu (optionnel)

uniform vec4 col_chaud : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 col_froid : source_color = vec4(1.0, 0.12, 0.02, 1.0);

uniform int pixels_x = 0;             // 0 = pas de pixelisation, sinon ex: 320
uniform int pixels_y = 0;             // ex: 180

// --------- helpers ----------
float hash12(vec2 p){
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

vec2 quant_uv(vec2 uv){
	if (pixels_x <= 0 || pixels_y <= 0) return uv;
	vec2 q = vec2(float(max(pixels_x, 1)), float(max(pixels_y, 1)));
	return (floor(uv * q) + 0.5) / q;
}

float sdCircle(vec2 p, float r){
	return length(p) - r;
}

// --------- core ----------
void fragment(){
	vec2 uv = quant_uv(UV);
	vec2 px = TEXTURE_PIXEL_SIZE;                  // taille d’un pixel en UV
	float t = TIME;

	// Grille de cellules: une braise potentielle par cellule
	// (plus petit = plus de braises)
	float cell = mix(24.0, 10.0, clamp(densite, 0.0, 2.0));
	vec2 g = uv * cell;
	vec2 id = floor(g);
	vec2 f  = fract(g);

	// seed par cellule
	float r0 = hash12(id + 1.3);
	float r1 = hash12(id + 7.7);
	float r2 = hash12(id + 9.1);

	// spawn gate (densité)
	float spawn = step(1.0 - clamp(densite, 0.0, 2.0) * 0.55, r0);

	// temps local (chaque cellule a son offset + sa période)
	float life = max(0.25, duree * mix(0.75, 1.35, r1));
	float phase = fract((t * vitesse + r2 * 13.0) / life);

	// position de départ dans la cellule
	vec2 p0 = vec2(r1, r2);

	// mouvement : montée + drift + turbulence
	float up = phase; // 0..1
	float wob = (noise(id * 0.17 + vec2(t * 0.8, t * 0.35)) - 0.5);
	float drift = (p0.x - 0.5) * 0.35 + wob * turbulence * 0.20;

	vec2 pos = p0;
	pos.y = p0.y - up * vent.y;                  // monte (y diminue en UV)
	pos.x = p0.x + up * (vent.x + drift);

	// petit "bounce" optionnel (gravite)
	pos.y += gravite * up * (1.0 - up) * 0.25;

	// wrap pour rester dans la cellule (sinon ça pop)
	pos = fract(pos);

	// distance dans la cellule
	vec2 d = (f - pos);

	// taille en UV (taille_px * pixel_size)
	float r_uv = max(0.5, taille_px) * max(px.x, px.y);

	// forme: disque doux + core plus chaud
	float dist = sdCircle(d, r_uv * cell);
	float blob = 1.0 - smoothstep(0.0, 1.0, dist * 6.0);

	// fade in/out sur la vie
	float fade = smoothstep(0.00, 0.15, phase) * (1.0 - smoothstep(0.70, 1.00, phase));

	// scintillement
	float flick = 0.75 + 0.25 * sin((t * 12.0 * scintillement) + r2 * 50.0 + uv.y * 20.0);
	flick *= 0.85 + 0.15 * noise(uv * 20.0 + vec2(t * 3.0, -t * 2.0));

	// couleur (centre plus chaud, bord plus rouge)
	float hot = smoothstep(0.25, 0.95, blob);
	vec3 c = mix(col_froid.rgb, col_chaud.rgb, hot);

	float a = spawn * blob * fade * flick;

	COLOR = vec4(c * a, a);
}
