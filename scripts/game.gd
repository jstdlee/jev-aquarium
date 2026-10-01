extends Node
## Global state: settings, fish records, hunger simulation, save/load, and the shared water currents.

signal fish_died(rec: Dictionary, offline: bool)
signal population_reset

const SpeciesDB = preload("res://scripts/species.gd")

const SAVE_VERSION := 1
const MAX_FISH := 40
const MAX_OFFLINE_SECONDS := 30.0 * 24.0 * 3600.0

# Hunger stages: full >= 70, content >= 40, hungry >= 15, starving > 0.
# Default drain: full to hungry in ~8 h, hungry to starving in ~28 h, starving to death in ~36 h.
const STAGE_FULL := 70.0
const STAGE_CONTENT := 40.0
const STAGE_HUNGRY := 15.0
const PEACEFUL_FLOOR := 16.0

var save_path := "user://save.json"
var fresh := false

var settings := {
	"population_mode": "random",  # "random" or "fixed"
	"random_min": 12,
	"random_max": 22,
	"fixed_counts": {},
	"care_mode": "normal",  # "normal", "relaxed" or "peaceful"
	"time_scale": 1.0,  # hunger speed-up, for testing
}
var fish_records: Array = []
var memorial: Array = []
var cloudiness := 0.0
var next_id := 1
var show_debug := false
var offline_deaths: Array = []  # fish that died while the game was closed

# World state shared between the tank, fish and input.
var sim_time := 0.0
var cursor_pos := Vector3(0, 3.5, 1.6)
var cursor_seen_at := -100.0
var currents: Array = []  # {pos, vel, life}

var _save_timer := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save="):
			save_path = a.substr(7)
		elif a == "--fresh":
			fresh = true
	for id in SpeciesDB.ORDER:
		settings.fixed_counts[id] = SpeciesDB.get_spec(id).default_count
	if fresh or not load_game():
		generate_population()
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


func _process(delta: float) -> void:
	sim_time += delta
	var scaled: float = delta * float(settings.time_scale)
	for rec in fish_records:
		if rec.alive:
			drain(rec, scaled)
	for i in range(currents.size() - 1, -1, -1):
		currents[i].life -= delta
		if currents[i].life <= 0.0:
			currents.remove_at(i)
	_save_timer += delta
	if _save_timer > 30.0:
		_save_timer = 0.0
		save_game()


# --- Hunger -----------------------------------------------------------------

static func stage(satiety: float) -> String:
	if satiety >= STAGE_FULL:
		return "full"
	if satiety >= STAGE_CONTENT:
		return "content"
	if satiety >= STAGE_HUNGRY:
		return "hungry"
	if satiety > 0.0:
		return "starving"
	return "dead"


func _rate_per_hour(satiety: float) -> float:
	if satiety > STAGE_CONTENT:
		return (100.0 - STAGE_CONTENT) / 8.0
	if satiety > STAGE_HUNGRY:
		return (STAGE_CONTENT - STAGE_HUNGRY) / 28.0
	return STAGE_HUNGRY / 36.0


## Lowers satiety for `seconds` of real time, band by band so long absences are exact.
func drain(rec: Dictionary, seconds: float) -> void:
	var mult: float = SpeciesDB.get_spec(rec.species).get("drain", 1.0)
	if settings.care_mode == "relaxed":
		mult *= 0.5
	var hours := seconds / 3600.0 * mult
	var s: float = rec.satiety
	while hours > 0.0 and s > 0.0:
		var rate := _rate_per_hour(s)
		var band_floor := STAGE_CONTENT if s > STAGE_CONTENT else (STAGE_HUNGRY if s > STAGE_HUNGRY else 0.0)
		var need := (s - band_floor) / rate
		if need >= hours:
			s -= rate * hours
			hours = 0.0
		else:
			s = band_floor
			hours -= need
	if settings.care_mode == "peaceful":
		s = maxf(s, minf(rec.satiety, PEACEFUL_FLOOR))
	rec.satiety = s


func feed(rec: Dictionary, amount: float) -> void:
	rec.satiety = minf(100.0, rec.satiety + amount)


func mark_dead(rec: Dictionary, offline: bool) -> void:
	if not rec.alive:
		return
	rec.alive = false
	memorial.append({"name": rec.name, "species": rec.species, "time": Time.get_datetime_string_from_system()})
	if offline:
		offline_deaths.append(rec)
	fish_died.emit(rec, offline)


# --- Population ---------------------------------------------------------------

func _new_record(species: String) -> Dictionary:
	var rec := {
		"id": next_id,
		"species": species,
		"name": SpeciesDB.NAMES[randi() % SpeciesDB.NAMES.size()],
		"satiety": randf_range(55.0, 85.0),
		"alive": true,
	}
	next_id += 1
	return rec


func generate_population() -> void:
	fish_records.clear()
	var counts := {}
	if settings.population_mode == "fixed":
		for id in SpeciesDB.ORDER:
			counts[id] = int(settings.fixed_counts.get(id, 0))
	else:
		var total := randi_range(int(settings.random_min), maxi(int(settings.random_min), int(settings.random_max)))
		for id in SpeciesDB.ORDER:
			counts[id] = 0
		# Schooling fish come in groups; the rest are picked by weight.
		if total >= 8 and randf() < 0.85:
			counts["neon"] = clampi(int(total * randf_range(0.35, 0.5)), 6, 14)
		var weights := 0.0
		for id in SpeciesDB.ORDER:
			if id != "neon":
				weights += float(SpeciesDB.get_spec(id).weight)
		var placed: int = counts["neon"]
		while placed < total:
			var pick := randf() * weights
			for id in SpeciesDB.ORDER:
				if id == "neon":
					continue
				pick -= float(SpeciesDB.get_spec(id).weight)
				if pick <= 0.0:
					if counts[id] < int(SpeciesDB.get_spec(id).get("max_count", 99)):
						counts[id] += 1
					break
			placed += 1
	var n := 0
	for id in SpeciesDB.ORDER:
		for i in counts[id]:
			if n >= MAX_FISH:
				break
			fish_records.append(_new_record(id))
			n += 1
	population_reset.emit()
	save_game()


func alive_records() -> Array:
	return fish_records.filter(func(r): return r.alive)


# --- Water currents (from the player's hand) -----------------------------------

func add_current(pos: Vector3, vel: Vector3) -> void:
	currents.append({"pos": pos, "vel": vel, "life": 1.6})
	if currents.size() > 48:
		currents.remove_at(0)


func current_at(p: Vector3) -> Vector3:
	var v := Vector3.ZERO
	for c in currents:
		var d2: float = p.distance_squared_to(c.pos)
		v += c.vel * exp(-d2 / 2.5) * clampf(c.life / 1.6, 0.0, 1.0)
	return v


func strongest_current() -> Dictionary:
	var best := {}
	var best_s := 0.0
	for c in currents:
		var s: float = c.vel.length() * c.life
		if s > best_s:
			best_s = s
			best = c
	return best


# --- Save / load ----------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"settings": settings,
		"fish": fish_records,
		"memorial": memorial,
		"cloudiness": cloudiness,
		"next_id": next_id,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	for k in data.get("settings", {}):
		settings[k] = data.settings[k]
	for id in SpeciesDB.ORDER:
		if not settings.fixed_counts.has(id):
			settings.fixed_counts[id] = SpeciesDB.get_spec(id).default_count
	fish_records = data.get("fish", []).filter(func(r): return SpeciesDB.has(r.species))
	memorial = data.get("memorial", [])
	cloudiness = float(data.get("cloudiness", 0.0))
	next_id = int(data.get("next_id", 1))
	for rec in fish_records:
		rec.id = int(rec.id)
	# Time passes while the game is closed: hunger keeps running.
	var away := clampf(Time.get_unix_time_from_system() - float(data.get("saved_at", 0.0)), 0.0, MAX_OFFLINE_SECONDS)
	for rec in fish_records:
		if rec.alive:
			drain(rec, away)
			if rec.satiety <= 0.0:
				mark_dead(rec, true)
	if alive_records().is_empty() and memorial.is_empty():
		return false
	return true
