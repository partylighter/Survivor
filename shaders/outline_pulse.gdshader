shader_type canvas_item;

uniform vec4 aura_color : source_color = vec4(0.2, 0.7, 1.0, 1.0);
uniform float outline_px = 6.0;        // épaisseur moyenne
uniform float alpha_base = 0.85;       // opacité aura
uniform float pulse_speed = 2.0;       // vitesse pulsation
uniform float pulse_amount = 0.35;     // amplitude pulsation

uniform float wave_strength_px = 3.0;  // force déformation (px)
uniform float wave_freq = 8.0;         // fréquence spatiale
uniform float wave_speed = 2.5;        // vitesse onde

uniform float noise_scale = 6.0;       // taille du bruit
uniform float noise_speed = 0.8;       // vitesse bruit

// petit hash / noise cheap (pas besoin de texture)
float hash21(vec2 p){
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise2(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment(){
	vec4 base = texture(TEXTURE, UV);
	float a = base.a;

	// Si tu veux l'aura uniquement autour du sprite: on calcule alpha max autour
	// Conversion px -> UV (pour sprite/texture)
	vec2 texel = TEXTURE_PIXEL_SIZE;

	// Pulsation globale
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	// Bruit animé (0..1)
	float n = noise2(UV * noise_scale + vec2(TIME * noise_speed, -TIME * noise_speed));

	// Déformation “flamme” en px (onde + bruit)
	float flame = sin((UV.y * wave_freq) + TIME * wave_speed) * 0.5 + 0.5; // 0..1
	float deform_px = (flame * 0.7 + n * 0.3) * wave_strength_px;

	float radius_px = (outline_px * pulse) + deform_px;
	float radius_uv = radius_px; // on va multiplier par texel dans l’échantillonnage

	float max_a = 0.0;

	// 16 directions (assez stylé + pas trop cher)
	const int STEPS = 16;
	for (int i = 0; i < STEPS; i++){
		float ang = (6.2831853 / float(STEPS)) * float(i);
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 off = dir * texel * radius_uv;
		float sa = texture(TEXTURE, UV + off).a;
		max_a = max(max_a, sa);
	}

	// outline = ce qui est “autour” mais pas dans le sprite
	float outline = clamp(max_a - a, 0.0, 1.0);

	// Dégradé: plus proche du sprite = plus intense
	float inner = smoothstep(0.0, 1.0, outline);
	float glow = pow(inner, 0.6);

	// scintillement léger
	float flicker = 0.85 + 0.15 * sin(TIME * 18.0 + n * 6.2831);

	vec4 aura = aura_color;
	aura.a *= alpha_base * glow * flicker;

	// Composite: garde le sprite, ajoute l’aura
	COLOR = base + aura * outline;
}
