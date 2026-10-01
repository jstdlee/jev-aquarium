shader_type spatial;
// Added as next_pass on imported materials: draws the moving sunlight caustics on top of any surface
// that faces up, so rocks, wood and plants share the same light pattern as the sand.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

#include "res://shaders/caustics.gdshaderinc"

uniform float strength = 0.35;
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.65);

varying vec3 wpos;
varying float up;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	// Fade with depth: the pattern is strongest near the surface light.
	float depth_fade = mix(0.55, 1.0, clamp(wpos.y / 6.0, 0.0, 1.0));
	ALBEDO = color * caustics(wpos, TIME) * max(up, 0.0) * strength * depth_fade;
}
