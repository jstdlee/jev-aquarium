shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://shaders/caustics.gdshaderinc"

uniform vec3 stir_pos = vec3(0.0, -100.0, 0.0);
uniform vec3 stir_vel = vec3(0.0);
uniform float sway = 0.12;
uniform float sway_speed = 0.8;
uniform float glow = 0.1;

varying vec3 inst_col;
varying vec3 wpos;
varying float hfrac;

void vertex() {
	inst_col = COLOR.rgb;
	hfrac = UV.y;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = origin.x * 1.7 + origin.z * 2.3;
	vec3 wv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = wv.y - origin.y;
	float h2 = hfrac * hfrac;
	vec3 off = vec3(sin(TIME * sway_speed + ph), 0.0, 0.5 * cos(TIME * sway_speed * 0.7 + ph * 1.3)) * sway * h2 * height;
	float d = distance(wv, stir_pos);
	off += stir_vel * exp(-d * d / 3.0) * h2 * 0.5;
	off.y -= length(off.xz) * 0.25 * hfrac;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
	wpos = wv + off;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 col = inst_col * mix(0.4, 1.15, hfrac);
	ALBEDO = col;
	ROUGHNESS = 0.55;
	float c = caustics(wpos, TIME);
	EMISSION = col * glow * hfrac + vec3(1.0, 0.9, 0.65) * c * 0.25;
}
