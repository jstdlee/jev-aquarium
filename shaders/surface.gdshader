shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

// Underside of the water. Seen from below at a shallow angle, the surface acts as a mirror
// (total internal reflection): we reflect the rendered tank about the waterline, ripple it,
// and let bright glints of the sky through where the waves face the camera.
#include "res://shaders/noise.gdshaderinc"

uniform sampler2D reflect_tex : source_color, filter_linear, repeat_disable;
uniform mat4 reflect_vp;  // view-projection of the mirrored camera that renders reflect_tex
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
	vec2 ripple = vec2(w - 0.5, ring) * 0.025;
	// Planar reflection: look up where this point lands in the mirrored camera's image.
	vec4 c = reflect_vp * vec4(wpos, 1.0);
	vec2 uv = c.xy / c.w * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	uv = clamp(uv + ripple, vec2(0.001), vec2(0.999));
	vec3 mirror = texture(reflect_tex, uv).rgb * 0.85;
	float glint = smoothstep(0.62, 0.8, w + ring * 0.4);
	vec3 col = mirror + vec3(1.0, 0.95, 0.8) * glint * 0.55;
	col = mix(col, col * vec3(0.8, 0.85, 0.6), cloudiness * 0.5);
	ALBEDO = col;
}
