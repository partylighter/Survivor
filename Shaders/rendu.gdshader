shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float pixel_size : hint_range(1.0, 64.0) = 3.0;
uniform int color_levels : hint_range(2, 64) = 16;
uniform bool use_dither = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;

float bayer4_from_index(int idx) {
	// idx 0..15 -> valeur 0..15
	// [ 0,  8,  2, 10,
	//  12,  4, 14,  6,
	//   3, 11,  1,  9,
	//  15,  7, 13,  5 ]
	switch (idx) {
		case 0:  return 0.0;
		case 1:  return 8.0;
		case 2:  return 2.0;
		case 3:  return 10.0;
		case 4:  return 12.0;
		case 5:  return 4.0;
		case 6:  return 14.0;
		case 7:  return 6.0;
		case 8:  return 3.0;
		case 9:  return 11.0;
		case 10: return 1.0;
		case 11: return 9.0;
		case 12: return 15.0;
		case 13: return 7.0;
		case 14: return 13.0;
		default: return 5.0; // 15
	}
}

float bayer4(vec2 pixel_xy) {
	// pixel_xy = coordonnées en pixels écran
	ivec2 p = ivec2(floor(pixel_xy));
	int x = p.x & 3; // mod 4
	int y = p.y & 3;
	int idx = x + (y << 2); // x + y*4
	return bayer4_from_index(idx) / 16.0; // [0..1)
}

vec3 quantize(vec3 c, float levels) {
	float L = max(levels, 2.0);
	return floor(c * (L - 1.0) + 0.5) / (L - 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// snap UV sur une grille de taille pixel_size (en pixels écran)
	vec2 grid = pixel_size / SCREEN_PIXEL_SIZE;
	vec2 uv_snapped = (floor(uv * grid) + 0.5) / grid;

	vec4 col = texture(screen_tex, uv_snapped);

	if (color_levels >= 2) {
		if (use_dither && dither_strength > 0.0) {
			vec2 pix = uv / SCREEN_PIXEL_SIZE;      // UV -> pixels écran
			float t = bayer4(pix) - 0.5;            // [-0.5..+0.5)
			col.rgb += t * (dither_strength / float(color_levels));
		}
		col.rgb = quantize(col.rgb, float(color_levels));
	}

	COLOR = col;
}
