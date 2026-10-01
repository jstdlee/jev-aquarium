shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// kind 0 = glowing dust mote, 1 = air bubble.
uniform int kind = 0;
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.6);
uniform float strength = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a;
	if (kind == 0) {
		a = pow(max(1.0 - d, 0.0), 2.0);
	} else {
		float rim = smoothstep(0.6, 0.92, d) * smoothstep(1.0, 0.92, d);
		float spot = smoothstep(0.25, 0.0, distance(UV, vec2(0.36, 0.34)));
		a = rim * 0.9 + spot + 0.08 * step(d, 1.0);
	}
	ALBEDO = color * a * COLOR.a * strength;
}
