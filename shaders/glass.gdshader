shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 tint : source_color = vec3(0.05, 0.09, 0.08);
uniform float edge = 0.0;

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float streak = smoothstep(0.92, 1.0, sin((UV.x + UV.y * 0.6) * 9.0)) * 0.25;
	vec3 col = tint * (0.12 + fres * 1.0 + streak);
	col += vec3(0.7, 0.9, 0.85) * edge;
	ALBEDO = col;
}
