// Animated water caustics, sampled in world space so every surface shares the same light pattern.
float caustic_pattern(vec2 p, float t) {
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 2.0);
}

float caustics(vec3 world_pos, float t) {
	vec2 p = world_pos.xz * 1.35 + vec2(world_pos.y * 0.18, world_pos.y * 0.1) + 40.0;
	return caustic_pattern(p, t * 0.45);
}
