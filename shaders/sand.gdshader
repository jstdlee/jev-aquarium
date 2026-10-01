shader_type spatial;
render_mode diffuse_burley;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/caustics.gdshaderinc"

uniform float cloudiness = 0.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = vnoise(wpos * 40.0) * 0.5 + vnoise(wpos * 9.0) * 0.5;
	vec3 sand = mix(vec3(0.5, 0.42, 0.29), vec3(0.74, 0.64, 0.46), grain);
	// Darker, greener toward the back where plants grow.
	float back = smoothstep(1.5, -2.5, wpos.z);
	sand = mix(sand, vec3(0.32, 0.3, 0.18), back * 0.6);
	sand = mix(sand, vec3(0.45, 0.42, 0.25), cloudiness * 0.6);
	ALBEDO = sand;
	ROUGHNESS = 0.95;
	float c = caustics(wpos, TIME);
	EMISSION = vec3(1.0, 0.88, 0.62) * c * 0.5 * (1.0 - back * 0.5) * (1.0 - cloudiness * 0.7);
}
