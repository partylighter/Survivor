shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex : source_color;

uniform float glitch_amount = 0.55;
uniform float glitch_speed  = 1.6;
uniform float band_count    = 28.0;
uniform float rgb_split_px  = 2.0;

uniform float burn_amount   = 0.0;      // 0..1
uniform float burn_width    = 0.08;
uniform float burn_noise_scale = 8.0;
uniform float burn_flicker  = 1.8;
uniform float alpha_cutoff  = 0.02;

uniform vec4 burn_color_inner : source_color = vec4(1.0, 0.95, 0.25, 1.0);
uniform vec4 burn_color_outer : source_color = vec4(1.0, 0.25, 0.05, 1.0);

// pixelise uniquement la brûlure (bord + masque)
uniform int burn_pixels_x = 160;
uniform int burn_pixels_y = 90;

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
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 quant_uv(vec2 uv, vec2 q){
	return (floor(uv * q) + 0.5) / q;
}

void fragment(){
	vec2 uv = UV;
	float t = TIME * glitch_speed;

	// ---------- GLITCH ----------
	float band = floor(uv.y * max(band_count, 1.0));
	float rnd  = hash12(vec2(band, floor(t * 8.0)));
	float gate = step(0.65, rnd) * glitch_amount;

	float shift = (rnd - 0.5) * 0.06 * gate;
	shift += (noise(vec2(band * 0.13, t * 6.0)) - 0.5) * 0.02 * gate;

	vec2 guv = uv;
	guv.x = fract(guv.x + shift);

	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 off = vec2(rgb_split_px, 0.0) * px * gate;

	float r = texture(tex, guv + off).r;
	float g = texture(tex, guv).g;
	float b = texture(tex, guv - off).b;

	vec4 col = vec4(r, g, b, texture(tex, guv).a);

	float scan = sin((uv.y * 900.0) + t * 20.0) * 0.04 * gate;
	col.rgb += scan;

	// ---------- BURN PIXELISÉ ----------
	vec2 bq = vec2(float(max(burn_pixels_x, 1)), float(max(burn_pixels_y, 1)));
	vec2 buv = quant_uv(uv, bq);

	float n = noise(buv * burn_noise_scale + vec2(0.0, t * 0.35));
	n = mix(n, noise(buv * (burn_noise_scale * 2.2) + vec2(12.7, -t * 0.22)), 0.45);

	float thr = burn_amount;

	// masque "visible/brûlé" en pixels
	float mask = smoothstep(thr, thr + 0.02, n);

	// bord incandescent pixelisé
	float edge = 1.0 - smoothstep(thr, thr + burn_width, n);

	// flicker (reste pixelisé car basé sur buv)
	edge *= (0.65 + 0.35 * sin(t * burn_flicker * 6.2831 + buv.y * 30.0));

	vec3 glow = mix(burn_color_outer.rgb, burn_color_inner.rgb, edge);

	col.rgb = mix(glow, col.rgb, mask);
	col.a *= mask;

	if (col.a < alpha_cutoff) col.a = 0.0;

	COLOR = col;
}
