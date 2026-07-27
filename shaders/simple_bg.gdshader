shader_type canvas_item;

uniform sampler2D texture_noise;
uniform float intensite = .2;

void fragment() {
	float valeur_noise = texture(texture_noise, UV).r-.2;
	vec4 couleur = texture(TEXTURE,UV);
	COLOR = vec4(vec3(valeur_noise*.3), .3);
	
	vec2 uv_noise = UV + vec2(TIME*.1,.0);
	
}
