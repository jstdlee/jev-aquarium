extends CanvasLayer
## Small panel in the top-right corner: add or remove fish by type, switch extras on and off.
## It folds away to a single button and fades when the mouse is elsewhere, so the tank stays the focus.

const SpeciesDB = preload("res://scripts/species.gd")

const EXTRA_LABELS := [
	["temple", "Temple ruin"], ["shell", "Sea shell"], ["toy", "Beach ball"], ["bubbles", "Air bubbles"],
	["leaves", "Floating leaves"], ["rays", "Light rays"], ["sparkles", "Sparkles"],
]

var root: PanelContainer
var body: VBoxContainer
var fold_btn: Button
var counts := {}  # species -> Label
var checks := {}  # extra -> CheckButton
var _hover := false
var _idle := 0.0


func _ready() -> void:
	layer = 5
	root = PanelContainer.new()
	root.anchor_left = 1.0
	root.anchor_right = 1.0
	root.offset_right = -14
	root.offset_top = 14
	root.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.custom_minimum_size = Vector2(250, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.12, 0.14, 0.62)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	root.add_theme_stylebox_override("panel", sb)
	root.mouse_entered.connect(func(): _hover = true)
	root.mouse_exited.connect(func(): _hover = false)
	add_child(root)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "My aquarium"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	fold_btn = Button.new()
	fold_btn.text = "–"
	fold_btn.flat = true
	fold_btn.tooltip_text = "Fold or unfold"
	fold_btn.pressed.connect(_toggle_fold)
	head.add_child(fold_btn)
	v.add_child(head)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	v.add_child(body)
	body.add_child(_section("Fish"))
	for id in SpeciesDB.ORDER:
		body.add_child(_fish_row(id))
	body.add_child(_section("Extras"))
	for e in EXTRA_LABELS:
		var c := CheckButton.new()
		c.text = e[1]
		c.add_theme_font_size_override("font_size", 13)
		c.toggled.connect(func(on: bool): Game.set_extra(e[0], on))
		checks[e[0]] = c
		body.add_child(c)
	var hint := Label.new()
	hint.text = "Esc · settings and care"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.75, 0.85, 0.85, 0.8))
	body.add_child(hint)

	Game.fish_added.connect(func(_r): _refresh())
	Game.fish_removed.connect(func(_r): _refresh())
	Game.fish_died.connect(func(_r, _o): _refresh())
	Game.population_reset.connect(_refresh)
	Game.extras_changed.connect(_refresh)
	_refresh()


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.65, 0.9, 0.92))
	return l


func _fish_row(id: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = SpeciesDB.get_spec(id).name
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lbl)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(26, 0)
	minus.tooltip_text = "Rehome one"
	minus.pressed.connect(func(): Game.remove_fish(id))
	h.add_child(minus)
	var n := Label.new()
	n.custom_minimum_size = Vector2(24, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 13)
	counts[id] = n
	h.add_child(n)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(26, 0)
	plus.tooltip_text = "Add one"
	plus.pressed.connect(func(): Game.add_fish(id))
	h.add_child(plus)
	return h


func _refresh() -> void:
	for id in counts:
		counts[id].text = str(Game.count_alive(id))
	for k in checks:
		checks[k].set_pressed_no_signal(bool(Game.settings.extras.get(k, false)))


func _toggle_fold() -> void:
	body.visible = not body.visible
	fold_btn.text = "–" if body.visible else "+"


func _process(delta: float) -> void:
	# Fade to a quiet presence when not in use.
	_idle = 0.0 if _hover else _idle + delta
	var target := 1.0 if _idle < 3.0 else 0.35
	root.modulate.a = lerpf(root.modulate.a, target, 1.0 - exp(-delta * 4.0))
