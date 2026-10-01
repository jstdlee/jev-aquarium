shader_type spatial;
render_mode diffuse_burley;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/caustics.gdshaderinc"

varying vec3 wpos;
varying vec3 wn;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 lp = wpos;
	float grain = fbm(vec3(lp.x * 2.0, lp.y * 9.0, lp.z * 2.0));
	vec3 wood = mix(vec3(0.16, 0.1, 0.06), vec3(0.4, 0.27, 0.15), grain);
	float moss = smoothstep(0.1, 0.5, wn.y + (fbm(lp * 3.0) - 0.5) * 0.9);
	vec3 moss_col = mix(vec3(0.16, 0.36, 0.07), vec3(0.48, 0.7, 0.18), vnoise(lp * 14.0));
	ALBEDO = mix(wood, moss_col, moss);
	ROUGHNESS = 0.9;
	EMISSION = vec3(1.0, 0.9, 0.65) * caustics(wpos, TIME) * max(wn.y, 0.0) * 0.4 + moss_col * moss * 0.06;
}
