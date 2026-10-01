shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 ripples[8];
uniform float now = 0.0;
uniform float cloudiness = 0.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float w = 0.6 * fbm(vec3(p * 1.8, TIME * 0.3)) + 0.4 * fbm(vec3(p * 4.5 + 7.0, TIME * 0.5));
	float ring = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 r = ripples[i];
		float age = now - r.z;
		if (r.w > 0.0 && age > 0.0 && age < 3.0) {
			float d = distance(p, r.xy);
			float front = age * 1.4;
			ring += sin((d - front) * 18.0) * exp(-pow((d - front) * 3.0, 2.0)) * (1.0 - age / 3.0) * r.w;
		}
	}
	// Underside of the water: mostly a dim mirror of the green tank, with bright glints of sky.
	float glint = smoothstep(0.5, 0.72, w + ring * 0.5);
	float front = smoothstep(-2.5, 2.5, wpos.z);
	vec3 mirror = mix(vec3(0.42, 0.46, 0.26), vec3(0.7, 0.66, 0.42), w);
	vec3 col = mix(mirror, vec3(1.0, 0.94, 0.75) * 1.4, glint * (0.4 + 0.4 * front));
	col += vec3(0.9, 0.8, 0.5) * ring * 0.4;
	col = mix(col, vec3(0.6, 0.62, 0.4), cloudiness * 0.5);
	ALBEDO = col;
	ALPHA = 0.7;
}
