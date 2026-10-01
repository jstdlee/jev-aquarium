shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform float cloudiness = 0.0;

void fragment() {
	float y = 1.0 - UV.y;
	vec3 deep = vec3(0.22, 0.5, 0.58);
	vec3 mid = vec3(0.5, 0.78, 0.88);
	vec3 top = vec3(0.92, 0.98, 1.0);
	vec3 col = mix(deep, mid, smoothstep(0.0, 0.55, y));
	col = mix(col, top, smoothstep(0.5, 1.0, y));
	// Soft out-of-focus plant silhouettes.
	float stalks = fbm(vec3(UV.x * 14.0, y * 1.5, 0.0));
	col *= mix(1.0, 0.82, smoothstep(0.45, 0.7, stalks) * smoothstep(0.95, 0.3, y));
	// Sun glow, upper left.
	col += vec3(1.0, 0.95, 0.8) * 0.3 * exp(-pow(distance(vec2(UV.x, y), vec2(0.3, 1.05)) * 2.2, 2.0));
	col = mix(col, vec3(0.3, 0.36, 0.2), cloudiness * 0.5);
	ALBEDO = col;
}
