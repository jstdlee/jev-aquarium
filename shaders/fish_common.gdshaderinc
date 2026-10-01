// Swim motion: a travelling wave down the body, strongest at the tail. Driven from fish.gd.
uniform float swim_phase = 0.0;
uniform float swim_amp = 0.1;
uniform float turn_bend = 0.0;
uniform float body_len = 1.0;
uniform float head_z = -0.5;
uniform float wave_k = 3.0;
uniform float vitality = 1.0;
uniform float fade = 1.0;

vec3 swim_deform(vec3 v, float flex) {
	float s = clamp((v.z - head_z) / body_len, 0.0, 1.8);
	float a = swim_amp * (0.1 + s * s) * body_len;
	v.x += sin(swim_phase - s * wave_k) * a;
	v.x += turn_bend * s * s * body_len * 0.45;
	// Fins ripple a little on their own and droop when the fish is weak.
	v.x += flex * sin(swim_phase * 1.6 + v.y * 5.0 + v.z * 4.0) * 0.05 * body_len;
	v.y -= flex * (1.0 - vitality) * 0.25 * abs(v.y);
	return v;
}

bool fade_out(vec2 frag) {
	float d = fract(sin(dot(floor(frag), vec2(12.9898, 78.233))) * 43758.5453);
	return fade < 0.999 && d > fade;
}
