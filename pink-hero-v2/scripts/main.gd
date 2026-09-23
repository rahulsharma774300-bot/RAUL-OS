extends Node2D

var hero: Sprite2D
var mode := "REFERENCE"
var t := 0.0
var base_pos := Vector2(540, 1035)
var base_scale := 0.76
var zoomed := false
var title: Label
var mode_label: Label
var note: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#f6b2c9"))
	_build_background()
	_build_hero()
	_build_ui()

func _process(delta: float) -> void:
	t += delta
	if not hero:
		return

	match mode:
		"REFERENCE":
			hero.position = hero.position.lerp(base_pos, min(1.0, delta * 8.0))
			hero.rotation = lerp(hero.rotation, 0.0, min(1.0, delta * 8.0))
			hero.scale = hero.scale.lerp(Vector2.ONE * (1.02 if zoomed else base_scale), min(1.0, delta * 8.0))
		"IDLE":
			var y := sin(t * 2.4) * 9.0
			var s := (1.02 if zoomed else base_scale) + sin(t * 2.4) * 0.004
			hero.position = hero.position.lerp(base_pos + Vector2(0, y), min(1.0, delta * 8.0))
			hero.rotation = sin(t * 1.3) * 0.008
			hero.scale = hero.scale.lerp(Vector2.ONE * s, min(1.0, delta * 8.0))
		"RUN":
			var phase := t * 9.5
			var y := abs(sin(phase)) * 18.0
			var lean := sin(phase * 0.5) * 0.015
			var s := 1.02 if zoomed else base_scale
			hero.position = base_pos + Vector2(sin(phase) * 6.0, -y)
			hero.rotation = lean
			hero.scale = Vector2.ONE * s
		"JUMP":
			var cycle := fposmod(t, 1.55) / 1.55
			var arc := sin(cycle * PI)
			var s := 1.02 if zoomed else base_scale
			hero.position = base_pos + Vector2(0, -arc * 240.0)
			hero.rotation = sin(cycle * PI * 2.0) * 0.018
			hero.scale = Vector2.ONE * s

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#f7b4cb")
	bg.position = Vector2.ZERO
	bg.size = Vector2(1080, 1920)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.92, 0.96, 0.24)
	glow.position = Vector2(0, 430)
	glow.size = Vector2(1080, 930)
	add_child(glow)

	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([
		Vector2(0, 1440), Vector2(1080, 1440),
		Vector2(1080, 1920), Vector2(0, 1920)
	])
	floor.color = Color("#f3a9c3")
	add_child(floor)

	for i in range(9):
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(1,1,1,0.12)
		line.points = PackedVector2Array([Vector2(80 + i*125, 1440), Vector2(540, 1920)])
		add_child(line)

func _build_hero() -> void:
	hero = Sprite2D.new()
	hero.texture = load("res://hero.svg")
	hero.position = base_pos
	hero.scale = Vector2.ONE * base_scale
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(hero)

func _build_ui() -> void:
	var top := ColorRect.new()
	top.color = Color(0.08,0.045,0.09,0.82)
	top.position = Vector2(0,0)
	top.size = Vector2(1080,155)
	add_child(top)

	title = _label("PINK HERO V2", 42, Color("#ff75b8"))
	title.position = Vector2(36, 25)
	add_child(title)

	mode_label = _label("REFERENCE LOOK", 21, Color.WHITE)
	mode_label.position = Vector2(38, 86)
	add_child(mode_label)

	note = _label("Hero approval build — city comes after the character is locked.", 18, Color("#5c3f4c"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.position = Vector2(40, 1515)
	note.size = Vector2(1000, 48)
	add_child(note)

	var controls := [
		["REFERENCE", "REFERENCE"],
		["IDLE", "IDLE"],
		["RUN TEST", "RUN"],
		["JUMP", "JUMP"]
	]
	for i in range(controls.size()):
		var b := Button.new()
		b.text = controls[i][0]
		b.position = Vector2(42 + i * 250, 1600)
		b.size = Vector2(222, 68)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_set_mode.bind(controls[i][1]))
		add_child(b)

	var zoom := Button.new()
	zoom.text = "ZOOM HERO"
	zoom.position = Vector2(290, 1695)
	zoom.size = Vector2(500, 70)
	zoom.add_theme_font_size_override("font_size", 22)
	zoom.pressed.connect(_toggle_zoom)
	add_child(zoom)

	var info := _label("Target details: slim pink feline • black shades • cream muzzle • pink tee • denim shorts • gold chain • long tail • large paws", 18, Color("#382934"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.position = Vector2(100, 1788)
	info.size = Vector2(880, 95)
	add_child(info)

func _label(text_value: String, size_value: int, color_value: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_color_override("font_color", color_value)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.05,0.025,0.05,0.22))
	return l

func _set_mode(next_mode: String) -> void:
	mode = next_mode
	t = 0.0
	mode_label.text = next_mode + (" LOOK" if next_mode == "REFERENCE" else " PREVIEW")

func _toggle_zoom() -> void:
	zoomed = not zoomed
