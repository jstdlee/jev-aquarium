shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	// Round lily-pad / frogbit leaf with a notch.
	float r = length(q);
	float notch = step(0.0, q.y) * step(abs(q.x), 0.08);
	if (r > 1.0 || notch > 0.5) {
		discard;
	}
	vec3 col = mix(vec3(0.2, 0.42, 0.1), vec3(0.42, 0.62, 0.18), r);
	ALBEDO = col;
	EMISSION = vec3(0.6, 0.75, 0.25) * 0.25 * (1.0 - r);
}
