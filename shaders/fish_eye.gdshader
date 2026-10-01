shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/fish_common.gdshaderinc"

varying vec4 col;

void vertex() {
	col = COLOR;
	VERTEX = swim_deform(VERTEX, 0.0);
}

void fragment() {
	if (fade_out(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = col.rgb;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = col.rgb * (1.0 - col.a) * 2.5;
}
