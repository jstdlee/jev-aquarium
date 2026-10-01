shader_type spatial;
render_mode diffuse_burley;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/caustics.gdshaderinc"

uniform float seed = 0.0;
varying vec3 wpos;
varying vec3 wn;
varying vec3 lp;

void vertex() {
	vec3 p = VERTEX * 2.2 + vec3(seed);
	float d = fbm(p) - 0.5;
	// Craggy "dragon stone": sharp ridges plus a flattened base.
	d += 0.25 * abs(vnoise(p * 2.5) - 0.5);
	VERTEX += NORMAL * d * 0.55;
	VERTEX.y = max(VERTEX.y, -0.35);
	lp = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = fbm(lp * 6.0 + vec3(seed));
	vec3 col = mix(vec3(0.26, 0.24, 0.2), vec3(0.58, 0.54, 0.46), n);
	float cracks = smoothstep(0.48, 0.5, vnoise(lp * 11.0 + seed)) * smoothstep(0.52, 0.5, vnoise(lp * 11.0 + seed));
	col *= 1.0 - cracks * 0.6;
	float moss = smoothstep(0.55, 0.85, wn.y + (vnoise(lp * 5.0) - 0.5) * 0.6);
	col = mix(col, vec3(0.3, 0.5, 0.12), moss * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	EMISSION = vec3(1.0, 0.9, 0.65) * caustics(wpos, TIME) * max(wn.y, 0.0) * 0.45;
}
