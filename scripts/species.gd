extends RefCounted
## Species catalogue: body shape (for the procedural mesh), colors, and personality.
## Units: the tank is 12 wide, 7 tall, 5 deep.
## "model" points at an artist-made GLB (see CREDITS.md). Its numbers come from tools/blender_inspect.py:
##   yaw: degrees to turn the model so its head faces -Z; center: model-space centre of the rest pose;
##   size: model-space length head to tail tip; length (top level) is the length in the tank.
## The procedural shape fields are only a fallback when a species has no model.

const ORDER := ["goldfish", "oranda", "betta", "discus", "guppy", "neon"]

const DATA := {
	"goldfish": {
		"clip_hz": 1.16, "beat_hz": 1.2,
		"spine": 0.55,
		"glide": 0.4, "turn": 1.8, "hover": 0.3,
		"name": "Jikin Goldfish",
		"model": {"path": "res://assets/fish/goldfish_swim.glb", "yaw": 180.0, "fix": Vector3(-90, 0, 0), "center": Vector3(2.09, 0.09, -3.25), "size": 13.1, "anim_speed": 1.0},
		"length": 1.25, "height_ratio": 0.5, "width_ratio": 0.62, "peak": 0.38, "stem": 0.22,
		"belly_drop": 0.35, "blunt": 0.35,
		"tail": {"type": "twin", "len": 0.8, "spread": 0.95},
		"dorsal": {"t0": 0.3, "t1": 0.64, "h": 0.5},
		"anal": {"t0": 0.62, "t1": 0.74, "h": 0.28},
		"pect": 0.24, "eye": 0.07, "eye_t": 0.14,
		"pattern": 1, "pattern_scale": 2.2, "specks": 0.55,
		"col_a": Color(1.0, 0.42, 0.08), "col_b": Color(1.0, 0.96, 0.9), "col_belly": Color(1.0, 0.9, 0.75),
		"fin_a": Color(1.0, 0.55, 0.2), "fin_b": Color(1.0, 0.97, 0.92), "fin_alpha": 0.8,
		"speed": 0.9, "max_speed": 2.4, "freq": 1.8, "amp": 0.11, "wave_k": 3.2,
		"curiosity": 0.95, "shy": 0.0, "school": 0.0, "greed": 1.0, "startle": 1.0,
		"depth": Vector2(1.0, 5.6), "drain": 1.0, "food_value": 6.0, "weight": 3.0, "default_count": 2,
	},
	"oranda": {
		"clip_hz": 1.10, "beat_hz": 1.1,
		"spine": 0.5,
		"glide": 0.5, "turn": 1.5, "hover": 0.45,
		"name": "Redcap Oranda",
		"model": {"path": "res://assets/fish/oranda_swim.glb", "yaw": 180.0, "fix": Vector3(-90, 0, 0), "center": Vector3(0.72, -1.6, -4.56), "size": 13.8, "anim_speed": 0.9},
		"length": 1.35, "height_ratio": 0.66, "width_ratio": 0.8, "peak": 0.42, "stem": 0.24,
		"belly_drop": 0.45, "blunt": 0.6,
		"tail": {"type": "twin", "len": 0.55, "spread": 0.85},
		"dorsal": {},
		"anal": {"t0": 0.66, "t1": 0.76, "h": 0.22},
		"pect": 0.22, "eye": 0.075, "eye_t": 0.16,
		"pattern": 1, "pattern_scale": 1.6, "specks": 0.0,
		"col_a": Color(0.98, 0.16, 0.06), "col_b": Color(1.0, 0.97, 0.93), "col_belly": Color(1.0, 0.93, 0.85),
		"fin_a": Color(1.0, 0.35, 0.2), "fin_b": Color(1.0, 0.95, 0.9), "fin_alpha": 0.8,
		"speed": 0.6, "max_speed": 1.6, "freq": 2.4, "amp": 0.15, "wave_k": 2.6,
		"curiosity": 1.0, "shy": 0.0, "school": 0.0, "greed": 1.1, "startle": 0.8,
		"depth": Vector2(0.8, 4.6), "drain": 1.0, "food_value": 6.0, "weight": 2.0, "default_count": 2,
	},
	"betta": {
		"clip_hz": 1.01, "beat_hz": 1.0,
		"spine": 0.4,
		"glide": 0.55, "turn": 1.3, "hover": 0.6,
		"name": "Betta",
		"model": {"path": "res://assets/fish/betta_swim.glb", "yaw": 180.0, "center": Vector3(0.0, 0.67, -0.15), "size": 6.5, "anim_speed": 0.8},
		"length": 1.5, "height_ratio": 0.3, "width_ratio": 0.5, "peak": 0.3, "stem": 0.3,
		"belly_drop": 0.1, "blunt": 0.3,
		"tail": {"type": "veil", "len": 1.0, "spread": 1.0},
		"dorsal": {"t0": 0.4, "t1": 0.7, "h": 0.6},
		"anal": {"t0": 0.35, "t1": 0.8, "h": 0.5},
		"pect": 0.15, "eye": 0.07, "eye_t": 0.12,
		"pattern": 0, "pattern_scale": 1.0, "specks": 0.0,
		"col_a": Color(0.1, 0.4, 0.8), "col_b": Color(0.9, 0.4, 0.1), "col_belly": Color(0.2, 0.5, 0.8),
		"fin_a": Color(0.1, 0.5, 0.8), "fin_b": Color(1.0, 0.5, 0.2), "fin_alpha": 0.8,
		"speed": 0.45, "max_speed": 1.8, "freq": 1.2, "amp": 0.08, "wave_k": 2.5,
		"curiosity": 1.0, "shy": 0.0, "school": 0.0, "greed": 1.0, "startle": 0.9,
		"depth": Vector2(3.0, 6.0), "drain": 0.8, "food_value": 7.0, "weight": 1.0, "default_count": 1, "max_count": 1,
	},
	"discus": {
		"beat_hz": 1.0,
		"procedural": false,  # its bones sit away from the mesh; keep the canned clip
		"spine": 0.3,
		"glide": 0.5, "turn": 1.6, "hover": 0.5,
		"name": "Discus",
		"model": {"path": "res://assets/fish/discus.glb", "yaw": -90.0, "center": Vector3(15.0, 56.7, -6.2), "size": 100.0, "anim_speed": 0.7},
		"length": 1.3, "height_ratio": 0.92, "width_ratio": 0.3, "peak": 0.45, "stem": 0.16,
		"belly_drop": 0.0, "blunt": 0.5,
		"tail": {"type": "round", "len": 0.28, "spread": 0.7},
		"dorsal": {"t0": 0.18, "t1": 0.86, "h": 0.2},
		"anal": {"t0": 0.38, "t1": 0.86, "h": 0.17},
		"pect": 0.16, "eye": 0.06, "eye_t": 0.16,
		"pattern": 3, "pattern_scale": 9.0, "specks": 0.0,
		"col_a": Color(0.12, 0.85, 0.8), "col_b": Color(0.05, 0.42, 0.55), "col_belly": Color(0.5, 0.95, 0.85),
		"fin_a": Color(0.15, 0.75, 0.75), "fin_b": Color(1.0, 0.55, 0.25), "fin_alpha": 0.85,
		"speed": 0.5, "max_speed": 1.8, "freq": 1.3, "amp": 0.05, "wave_k": 2.0,
		"curiosity": 0.45, "shy": 0.35, "school": 0.15, "greed": 0.8, "startle": 1.2,
		"depth": Vector2(2.4, 5.6), "drain": 0.9, "food_value": 7.0, "weight": 2.0, "default_count": 2,
	},
	"guppy": {
		"clip_hz": 1.0, "beat_hz": 2.4,
		"spine": 0.6,
		"glide": 0.35, "turn": 3.0, "hover": 0.15,
		"name": "Fancy Guppy",
		"model": {"path": "res://assets/fish/guppy_swim.glb", "yaw": 0.0, "center": Vector3(-0.55, 0.07, -1.1), "size": 8.2, "anim_speed": 1.2},
		"length": 0.65, "height_ratio": 0.32, "width_ratio": 0.55, "peak": 0.3, "stem": 0.28,
		"belly_drop": 0.15, "blunt": 0.25,
		"tail": {"type": "veil", "len": 0.95, "spread": 1.0},
		"dorsal": {"t0": 0.42, "t1": 0.66, "h": 0.55},
		"anal": {},
		"pect": 0.18, "eye": 0.085, "eye_t": 0.13,
		"pattern": 4, "pattern_scale": 3.0, "specks": 0.0,
		"col_a": Color(1.0, 0.5, 0.12), "col_b": Color(0.55, 0.72, 0.85), "col_belly": Color(0.9, 0.92, 0.95),
		"fin_a": Color(1.0, 0.45, 0.08), "fin_b": Color(0.2, 0.4, 1.0), "fin_alpha": 0.85,
		"speed": 1.5, "max_speed": 3.0, "freq": 3.2, "amp": 0.12, "wave_k": 3.5,
		"curiosity": 0.6, "shy": 0.1, "school": 0.3, "greed": 1.0, "startle": 1.4,
		"depth": Vector2(3.2, 6.1), "drain": 1.1, "food_value": 9.0, "weight": 3.0, "default_count": 4,
	},
	"neon": {
		"clip_hz": 1.0, "beat_hz": 3.0,
		"spine": 0.55,
		"glide": 0.2, "turn": 3.6, "hover": 0.05,
		"name": "Neon Tetra",
		"model": {"path": "res://assets/fish/neon_swim.glb", "yaw": 180.0, "center": Vector3(0.0, -0.03, -0.15), "size": 8.6, "anim_speed": 1.4},
		"length": 0.45, "height_ratio": 0.27, "width_ratio": 0.6, "peak": 0.35, "stem": 0.26,
		"belly_drop": 0.1, "blunt": 0.2,
		"tail": {"type": "fork", "len": 0.32, "spread": 0.65},
		"dorsal": {"t0": 0.45, "t1": 0.6, "h": 0.4},
		"anal": {"t0": 0.6, "t1": 0.78, "h": 0.25},
		"pect": 0.15, "eye": 0.095, "eye_t": 0.13,
		"pattern": 2, "pattern_scale": 1.0, "specks": 0.0,
		"col_a": Color(0.05, 0.7, 1.0), "col_b": Color(1.0, 0.08, 0.15), "col_belly": Color(0.85, 0.9, 0.95),
		"fin_a": Color(0.8, 0.9, 0.95), "fin_b": Color(0.9, 0.95, 1.0), "fin_alpha": 0.35,
		"speed": 1.4, "max_speed": 3.2, "freq": 4.0, "amp": 0.1, "wave_k": 3.5,
		"curiosity": 0.2, "shy": 0.6, "school": 1.0, "greed": 0.9, "startle": 1.6,
		"depth": Vector2(2.0, 5.2), "drain": 1.2, "food_value": 12.0, "weight": 6.0, "default_count": 12,
	},
}

const NAMES := [
	"Mochi", "Kumo", "Hana", "Sora", "Biscuit", "Pebble", "Momo", "Yuzu", "Tofu", "Kiko",
	"Bubbles", "Saffron", "Maple", "Lumi", "Nori", "Peach", "Tama", "Sunny", "Koi", "Ume",
	"Clover", "Juniper", "Mango", "Pip", "Ripple", "Coral", "Fern", "Miso", "Haru", "Kiwi",
]


static func get_spec(id: String) -> Dictionary:
	return DATA[id]


static func has(id: String) -> bool:
	return DATA.has(id)
