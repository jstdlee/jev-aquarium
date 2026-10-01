extends CanvasLayer
## The only UI: a small settings panel behind Esc / right-click. The tank keeps living behind it.

const SpeciesDB = preload("res://scripts/species.gd")

var panel: PanelContainer
var mode_opt: OptionButton
var min_spin: SpinBox
var max_spin: SpinBox
var random_box: Control
var fixed_box: Control
var fixed_spins := {}
var care_opt: OptionButton
var speed_opt: OptionButton
var memorial_label: Label

const SPEEDS := [1.0, 60.0, 600.0, 3600.0]


func _ready() -> void:
	layer = 10
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.custom_minimum_size = Vector2(460, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.08, 0.86)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(_title("Tank settings"))

	mode_opt = OptionButton.new()
	mode_opt.add_item("Random fish")
	mode_opt.add_item("Choose fish")
	mode_opt.item_selected.connect(func(_i): _sync_visibility())
	v.add_child(_row("Population", mode_opt))

	random_box = VBoxContainer.new()
	min_spin = _spin(1, Game.MAX_FISH)
	max_spin = _spin(1, Game.MAX_FISH)
	random_box.add_child(_row("Fewest fish", min_spin))
	random_box.add_child(_row("Most fish", max_spin))
	v.add_child(random_box)

	fixed_box = VBoxContainer.new()
	for id in SpeciesDB.ORDER:
		var s := _spin(0, 20)
		fixed_spins[id] = s
		fixed_box.add_child(_row(SpeciesDB.get_spec(id).name, s))
	v.add_child(fixed_box)

	var restock := Button.new()
	restock.text = "Restock tank with these settings"
	restock.pressed.connect(_restock)
	v.add_child(restock)

	v.add_child(HSeparator.new())
	care_opt = OptionButton.new()
	care_opt.add_item("Normal: fish can die if not fed for ~3 days")
	care_opt.add_item("Relaxed: hunger is half as fast")
	care_opt.add_item("Peaceful: fish never die")
	care_opt.item_selected.connect(_care_changed)
	v.add_child(_row("Care", care_opt))

	speed_opt = OptionButton.new()
	for s in SPEEDS:
		speed_opt.add_item("%dx" % int(s))
	speed_opt.item_selected.connect(func(i): Game.settings.time_scale = SPEEDS[i])
	v.add_child(_row("Hunger speed (testing)", speed_opt))

	memorial_label = Label.new()
	memorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memorial_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.78))
	v.add_child(memorial_label)

	var hint := Label.new()
	hint.text = "Move: fish follow your finger · Click: tap glass · Double-click: feed\nTriple-click: bubbles & toy · Drag: stir water · F1: fish info · F11: fullscreen"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.68))
	v.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var resume := Button.new()
	resume.text = "Back to tank"
	resume.pressed.connect(toggle)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(_quit)
	buttons.add_child(quit)
	buttons.add_child(resume)
	v.add_child(buttons)
	visible = false


func _quit() -> void:
	Game.save_game()
	get_tree().quit()


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	return l


func _row(label: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(control)
	return h


func _spin(lo: int, hi: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	return s


func _sync_visibility() -> void:
	random_box.visible = mode_opt.selected == 0
	fixed_box.visible = mode_opt.selected == 1


func toggle() -> void:
	visible = not visible
	if visible:
		_load_from_settings()
	else:
		Game.save_game()
	# Re-centre after the panel has been sized.
	await get_tree().process_frame
	panel.position = (get_viewport().get_visible_rect().size - panel.size) * 0.5


func _load_from_settings() -> void:
	var s: Dictionary = Game.settings
	mode_opt.selected = 0 if s.population_mode == "random" else 1
	min_spin.value = s.random_min
	max_spin.value = s.random_max
	for id in fixed_spins:
		fixed_spins[id].value = s.fixed_counts.get(id, 0)
	care_opt.selected = ["normal", "relaxed", "peaceful"].find(s.care_mode)
	speed_opt.selected = maxi(0, SPEEDS.find(float(s.time_scale)))
	var names: Array = Game.memorial.map(func(m): return "%s (%s)" % [m.name, SpeciesDB.get_spec(m.species).name])
	memorial_label.text = "" if names.is_empty() else "Remembered: " + ", ".join(PackedStringArray(names))
	_sync_visibility()


func _care_changed(i: int) -> void:
	Game.settings.care_mode = ["normal", "relaxed", "peaceful"][i]


func _restock() -> void:
	var s: Dictionary = Game.settings
	s.population_mode = "random" if mode_opt.selected == 0 else "fixed"
	s.random_min = int(min_spin.value)
	s.random_max = maxi(int(min_spin.value), int(max_spin.value))
	for id in fixed_spins:
		s.fixed_counts[id] = int(fixed_spins[id].value)
	Game.generate_population()
	toggle()
