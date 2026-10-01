shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.86, 0.55);
uniform float strength = 0.35;
uniform float seed = 0.0;

void fragment() {
	float across = sin(UV.x * PI);
	float down = pow(1.0 - UV.y, 1.3) * smoothstep(0.0, 0.12, UV.y);
	float flicker = 0.55 + 0.45 * vnoise(vec3(UV.x * 5.0 + seed, UV.y * 0.6 - TIME * 0.05, TIME * 0.12 + seed));
	float shafts = 0.6 + 0.4 * sin(UV.x * 17.0 + seed * 3.0 + TIME * 0.2);
	ALBEDO = color * across * across * down * flicker * shafts * strength;
}
