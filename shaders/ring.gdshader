shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// progress 0..1 drives an expanding ring; mode 1 is a soft fingertip glow instead.
uniform float progress = 0.0;
uniform float strength = 1.0;
uniform int mode = 0;
uniform vec3 color : source_color = vec3(1.0, 0.95, 0.8);

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a;
	if (mode == 0) {
		float r = 0.15 + progress * 0.85;
		a = smoothstep(0.09, 0.0, abs(d - r)) * (1.0 - progress);
		a += smoothstep(0.5, 0.0, d) * pow(1.0 - progress, 4.0) * 0.6;
	} else {
		a = pow(max(1.0 - d, 0.0), 2.5);
	}
	ALBEDO = color * a * strength;
}
