shader_type spatial;
render_mode diffuse_burley;

// Scanned sand (Poly Haven coast_sand_01, CC0) projected from above, with moving caustics.
#include "res://shaders/caustics.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tile = 0.28;
uniform vec3 tint : source_color = vec3(1.08, 1.0, 0.9);
uniform float cloudiness = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * tile;
	vec3 col = texture(albedo_tex, uv).rgb * tint;
	// Toward the back the substrate is darker and richer, like aquasoil under plants.
	float back = smoothstep(1.2, -2.4, wpos.z);
	col = mix(col, col * vec3(0.55, 0.5, 0.4), back * 0.7);
	col = mix(col, col * vec3(0.8, 0.85, 0.65), cloudiness * 0.6);
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = texture(rough_tex, uv).r;
	AO = texture(ao_tex, uv).r;
	AO_LIGHT_AFFECT = 0.4;
	EMISSION = vec3(1.0, 0.88, 0.62) * caustics(wpos, TIME) * 0.45 * (1.0 - back * 0.6) * (1.0 - cloudiness * 0.7);
}
