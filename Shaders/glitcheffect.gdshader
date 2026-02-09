shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex : source_color;

uniform float glitch_amount = 0.55; // 0..1
uniform float glitch_speed  = 1.6;

uniform float band_count    = 36.0; // nb de bandes
uniform float rgb_split_px  = 2.0;  // split RGB en pixels
uniform float max_shift     = 0.06; // amplitude shift X

uniform float jitter_px     = 1.5;  // micro-jitter global en pixels
uniform float freeze_chance = 0.12; // chance de "frame hold"
uniform float blockiness    = 0.55; // 0=bandes, 1=blocs

uniform float scan_strength = 0.05; // scanlines
uniform float noise_strength= 0.02; // bruit additif

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

void fragment(){
	vec2 uv = UV;

	float amt = clamp(glitch_amount, 0.0, 1.0);
	float t = TIME * glitch_speed;

	// --- frame hold (freeze) ---
	float hold_id = floor(t * 10.0);
	float hold_r  = hash12(vec2(91.7, hold_id));
	float hold_on = step(1.0 - freeze_chance * amt, hold_r);
	float t_hold  = mix(t, floor(t * 10.0) / 10.0, hold_on);

	// --- micro jitter global (pixel) ---
	vec2 px = TEXTURE_PIXEL_SIZE;
	float jx = (hash12(vec2(7.1, floor(t_hold * 24.0))) - 0.5) * 2.0;
	float jy = (hash12(vec2(8.3, floor(t_hold * 24.0))) - 0.5) * 2.0;
	vec2 jitter = vec2(jx, jy) * px * jitter_px * amt;

	// --- bandes + blocs ---
	float bands = max(band_count, 1.0);
	float band = floor(uv.y * bands);

	// blocs (option)
	vec2 grid = vec2(12.0, bands);
	vec2 cell = floor(uv * grid);
	float block_r = hash12(cell + vec2(floor(t_hold * 8.0), 13.2));

	float rnd_band = hash12(vec2(band, floor(t_hold * 8.0)));
	float rnd = mix(rnd_band, block_r, clamp(blockiness, 0.0, 1.0));

	// gate "digital": rare, net, contrôlé par amt
	float gate = smoothstep(0.72, 0.95, rnd) * amt;

	// shift X par bande/bloc
	float shift = (rnd - 0.5) * 2.0 * max_shift * gate;
	shift += (noise(vec2(band * 0.13, t_hold * 6.0)) - 0.5) * 0.02 * gate;

	vec2 guv = uv + jitter;
	guv.x = fract(guv.x + shift);

	// RGB split (en pixels)
	vec2 off = vec2(rgb_split_px, 0.0) * px * gate;

	float r = texture(tex, guv + off).r;
	float g = texture(tex, guv).g;
	float b = texture(tex, guv - off).b;
	float a = texture(tex, guv).a;

	vec3 col = vec3(r, g, b);

	// scanlines + bruit (subtils)
	float scan = sin((uv.y * 900.0) + t_hold * 20.0) * scan_strength * gate;
	col += scan;

	float n = (noise(uv * vec2(520.0, 310.0) + vec2(t_hold * 3.0, -t_hold * 2.0)) - 0.5) * 2.0;
	col += n * noise_strength * amt * (0.35 + 0.65 * gate);

	COLOR = vec4(col, a);
}
