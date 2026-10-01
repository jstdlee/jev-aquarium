shader_type spatial;
render_mode cull_disabled, diffuse_burley, depth_draw_never;

#include "res://shaders/caustics.gdshaderinc"
#include "res://shaders/fish_common.gdshaderinc"

uniform vec3 fin_a : source_color = vec3(1.0, 0.6, 0.3);
uniform vec3 fin_b : source_color = vec3(1.0);
uniform float fin_alpha = 0.8;

varying vec3 wpos;

void vertex() {
	VERTEX = swim_deform(VERTEX, COLOR.r);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (fade_out(FRAGCOORD.xy)) {
		discard;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float v = UV.y;
	float rays = 0.82 + 0.18 * sin(UV.x * 70.0);
	vec3 col = mix(fin_a, fin_b, smoothstep(0.15, 0.95, v)) * rays;
	float grey = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(vec3(grey) * 0.75 + 0.12, col, vitality);
	ALBEDO = col;
	ROUGHNESS = 0.5;
	float edge = smoothstep(0.75, 1.0, v);
	ALPHA = clamp(fin_alpha * mix(0.85, 0.4, v) + edge * 0.12, 0.0, 1.0) * mix(0.6, 1.0, vitality);
	// Light glows through thin fins.
	EMISSION = col * (0.38 + edge * 0.3) + vec3(1.0, 0.92, 0.75) * caustics(wpos, TIME) * 0.15;
}
