shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/caustics.gdshaderinc"
#include "res://shaders/fish_common.gdshaderinc"

uniform vec3 col_a : source_color = vec3(1.0, 0.5, 0.1);
uniform vec3 col_b : source_color = vec3(1.0);
uniform vec3 col_belly : source_color = vec3(1.0, 0.95, 0.85);
uniform int pattern = 0;
uniform float pattern_scale = 2.0;
uniform float specks = 0.0;
uniform float seed = 0.0;
uniform float body_h = 0.5;
uniform float caustic_strength = 0.55;

varying vec3 obj;
varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	obj = VERTEX;
	VERTEX = swim_deform(VERTEX, 0.0);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (fade_out(FRAGCOORD.xy)) {
		discard;
	}
	float s = clamp((obj.z - head_z) / body_len, 0.0, 1.0);
	float hy = obj.y / max(body_h * 0.5, 0.001);
	vec3 col = col_a;
	vec3 glow = vec3(0.0);
	vec3 sp = obj * pattern_scale + vec3(seed);
	if (pattern == 1) {
		float m = smoothstep(0.44, 0.56, fbm(sp * 1.3));
		col = mix(col_b, col_a, m);
		float dots = smoothstep(1.0 - specks * 0.3, 1.0 - specks * 0.25, vnoise(sp * 4.5));
		col = mix(col, vec3(0.05, 0.04, 0.05), dots * step(0.01, specks));
	} else if (pattern == 2) {
		float band = smoothstep(0.02, 0.12, hy) * smoothstep(0.45, 0.3, hy) * smoothstep(0.08, 0.2, s) * smoothstep(1.0, 0.85, s);
		float red = smoothstep(0.05, -0.1, hy) * smoothstep(0.4, 0.55, s) * smoothstep(-0.95, -0.6, hy);
		col = mix(col_belly * 0.8, col_b, red);
		col = mix(col, col_a, band);
		glow = col_a * band * 0.7 + col_b * red * 0.15;
	} else if (pattern == 3) {
		float w = sin(obj.y * pattern_scale * 6.0 + fbm(sp * 0.6) * 5.0 + obj.z * 3.0);
		col = mix(col_a, col_b, smoothstep(0.55, 0.85, w));
		float bars = smoothstep(0.75, 1.0, sin(s * 28.0)) * 0.25;
		col *= 1.0 - bars;
	} else if (pattern == 4) {
		col = mix(col_b, col_a, smoothstep(0.35, 0.8, s));
		float dots = smoothstep(0.7, 0.75, vnoise(sp * 5.0)) * smoothstep(0.3, 0.6, s);
		col = mix(col, vec3(0.1, 0.25, 0.9), dots * 0.8);
	}
	float belly = smoothstep(-0.05, -0.75, hy);
	col = mix(col, col_belly, belly * (pattern == 2 ? 0.6 : 0.75));
	// Starving fish lose their colour.
	float grey = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(vec3(grey) * 0.75 + 0.12, col, vitality);

	ALBEDO = col;
	ROUGHNESS = 0.32;
	SPECULAR = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	RIM = 0.4;
	RIM_TINT = 0.6;
	float c = caustics(wpos, TIME) * max(wnorm.y, 0.0) * caustic_strength;
	EMISSION = (glow + col * fres * 0.35 + vec3(1.0, 0.92, 0.75) * c * 0.6) * vitality;
}
