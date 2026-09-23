extends Node3D

var hero: Node3D
var camera: Camera3D
var yaw: float = 0.0
var target_yaw: float = 0.0
var distance: float = 7.0
var target_distance: float = 7.0
var auto_rotate: bool = false
var drag_active: bool = false
var view_label: Label
var info_label: Label
var t: float = 0.0

func _ready() -> void:
	_setup_environment()
	_setup_stage()
	_setup_ui()
	_load_hero()
	_setup_camera()

func _process(delta: float) -> void:
	t += delta
	if auto_rotate:
		target_yaw += delta * 0.42
	yaw = lerp_angle(yaw, target_yaw, min(1.0, delta * 8.0))
	distance = lerpf(distance, target_distance, min(1.0, delta * 7.0))
	if hero:
		hero.rotation.y = yaw
		hero.position.y = sin(t * 1.7) * 0.006
	_update_camera()
	_update_view_label()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		target_yaw += d.relative.x * 0.010
		auto_rotate = false
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			drag_active = mb.pressed
	elif event is InputEventMouseMotion and drag_active:
		var mm := event as InputEventMouseMotion
		target_yaw += mm.relative.x * 0.010
		auto_rotate = false

func _load_hero() -> void:
	var path := "res://generated/PinkHeroV4.glb"
	if not ResourceLoader.exists(path):
		info_label.text = "MODEL MISSING"
		return
	var packed = load(path)
	if packed is PackedScene:
		hero = packed.instantiate()
		hero.name = "PinkHeroV4Model"
		add_child(hero)
		info_label.text = "CUSTOM GLB • 80 MESH PARTS • PBR MATERIALS"
	else:
		info_label.text = "MODEL IMPORT FAILED"

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#f1aeca")
	sky_mat.sky_horizon_color = Color("#fff0f5")
	sky_mat.ground_horizon_color = Color("#e6d5dc")
	sky_mat.ground_bottom_color = Color("#bdabb2")
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.92
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.10
	env.adjustment_saturation = 1.08
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -26.0, 0.0)
	key.light_color = Color("#fff0df")
	key.light_energy = 1.85
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 25.0
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	rim.light_color = Color("#ff86c1")
	rim.light_energy = 0.60
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(2.7, 3.1, 4.0)
	fill.omni_range = 10.0
	fill.light_color = Color("#c4d6ff")
	fill.light_energy = 1.35
	add_child(fill)

func _setup_stage() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#f5e8ed")
	floor_mat.roughness = 0.94

	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 3.1
	floor_mesh.bottom_radius = 3.1
	floor_mesh.height = 0.16
	floor_mesh.radial_segments = 64

	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.position.y = -0.10
	add_child(floor)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("#ff66b0")
	ring_mat.emission_enabled = true
	ring_mat.emission = Color("#ff4fa7")
	ring_mat.emission_energy_multiplier = 1.3
	ring_mat.roughness = 0.35

	var torus := TorusMesh.new()
	torus.inner_radius = 2.30
	torus.outer_radius = 2.38
	torus.rings = 64
	torus.ring_segments = 16

	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = ring_mat
	ring.rotation_degrees.x = 90.0
	ring.position.y = 0.005
	add_child(ring)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 43.0
	camera.near = 0.05
	camera.far = 40.0
	add_child(camera)
	_update_camera()

func _update_camera() -> void:
	if not camera:
		return
	camera.position = Vector3(0.0, 2.20, distance)
	camera.look_at(Vector3(0.0, 2.02, 0.15), Vector3.UP)

func _setup_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var top := ColorRect.new()
	top.color = Color(0.055, 0.03, 0.07, 0.84)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 136
	ui.add_child(top)

	var title := _label("PINK HERO V4", 34, Color("#ff76b8"))
	title.position = Vector2(28, 20)
	ui.add_child(title)

	info_label = _label("LOADING CUSTOM GLB...", 18, Color.WHITE)
	info_label.position = Vector2(30, 73)
	ui.add_child(info_label)

	view_label = _label("FRONT", 19, Color("#ffd85b"))
	view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	view_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	view_label.offset_left = -260
	view_label.offset_right = -28
	view_label.offset_top = 74
	view_label.offset_bottom = 106
	ui.add_child(view_label)

	var hint := _label("Drag left/right to inspect the imported 3D model", 18, Color("#55434d"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -245
	hint.offset_bottom = -210
	ui.add_child(hint)

	var bottom := ColorRect.new()
	bottom.color = Color(1.0, 0.965, 0.982, 0.94)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -198
	ui.add_child(bottom)

	var views := [
		["FRONT", 0.0],
		["SIDE", -PI * 0.5],
		["BACK", PI],
		["AUTO", 99.0]
	]
	for i in range(views.size()):
		var b := Button.new()
		b.text = String(views[i][0])
		b.add_theme_font_size_override("font_size", 18)
		b.position = Vector2(28 + i * 256, 1740)
		b.size = Vector2(224, 62)
		b.pressed.connect(_set_view.bind(float(views[i][1])))
		ui.add_child(b)

	var zoom_in := Button.new()
	zoom_in.text = "CLOSE-UP"
	zoom_in.add_theme_font_size_override("font_size", 18)
	zoom_in.position = Vector2(155, 1814)
	zoom_in.size = Vector2(360, 58)
	zoom_in.pressed.connect(_set_zoom.bind(5.35))
	ui.add_child(zoom_in)

	var full := Button.new()
	full.text = "FULL BODY"
	full.add_theme_font_size_override("font_size", 18)
	full.position = Vector2(565, 1814)
	full.size = Vector2(360, 58)
	full.pressed.connect(_set_zoom.bind(7.0))
	ui.add_child(full)

	var note := _label("V4 = imported custom mesh. Rig + real run/jump/slide animation comes after model approval.", 16, Color("#4e3945"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.position = Vector2(90, 1648)
	note.size = Vector2(900, 70)
	ui.add_child(note)

func _set_view(angle: float) -> void:
	if angle > 90.0:
		auto_rotate = not auto_rotate
	else:
		auto_rotate = false
		target_yaw = angle

func _set_zoom(value: float) -> void:
	target_distance = value

func _update_view_label() -> void:
	if not view_label:
		return
	var deg: float = fposmod(rad_to_deg(yaw), 360.0)
	if deg < 22.5 or deg >= 337.5:
		view_label.text = "FRONT"
	elif deg < 67.5:
		view_label.text = "FRONT 3/4"
	elif deg < 112.5:
		view_label.text = "SIDE"
	elif deg < 157.5:
		view_label.text = "BACK 3/4"
	elif deg < 202.5:
		view_label.text = "BACK"
	elif deg < 247.5:
		view_label.text = "BACK 3/4"
	elif deg < 292.5:
		view_label.text = "SIDE"
	else:
		view_label.text = "FRONT 3/4"

func _label(text_value: String, size_value: int, color_value: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_color_override("font_color", color_value)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.35))
	return l
