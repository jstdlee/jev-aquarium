shader_type spatial;
render_mode diffuse_burley;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	// Beach ball: six coloured panels with white caps.
	float ang = atan(lp.z, lp.x);
	float seg = floor((ang + PI) / (TAU / 6.0));
	vec3 cols[6] = vec3[](vec3(0.95, 0.2, 0.2), vec3(1.0, 1.0, 1.0), vec3(1.0, 0.8, 0.1),
		vec3(1.0, 1.0, 1.0), vec3(0.15, 0.45, 0.95), vec3(1.0, 1.0, 1.0));
	vec3 col = cols[int(clamp(seg, 0.0, 5.0))];
	float cap = smoothstep(0.85, 0.9, abs(normalize(lp).y));
	ALBEDO = mix(col, vec3(1.0), cap);
	ROUGHNESS = 0.2;
	SPECULAR = 0.7;
	RIM = 0.3;
}
