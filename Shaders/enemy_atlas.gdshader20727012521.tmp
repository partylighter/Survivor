shader_type canvas_item;
uniform ivec2 grid = ivec2(8, 8);

varying vec4 inst_custom;

void vertex() {
	inst_custom = INSTANCE_CUSTOM; // dispo en vertex
}

void fragment() {
	vec4 cd = inst_custom; // x=frame_norm, y=flash

	int n   = max(grid.x * grid.y, 1);
	int idx = int(floor(cd.x * float(n - 1)));
	int fx  = idx % grid.x;
	int fy  = idx / grid.x;

	vec2 cell = vec2(1.0 / float(grid.x), 1.0 / float(grid.y));
	vec2 uv   = fract(UV * vec2(float(grid.x), float(grid.y)));
	vec2 base = vec2(float(fx), float(fy)) * cell;

	vec4 texel = texture(TEXTURE, base + uv * cell);
	texel.rgb  = mix(texel.rgb, vec3(1.0), clamp(cd.y, 0.0, 1.0));
	COLOR = texel;
}
