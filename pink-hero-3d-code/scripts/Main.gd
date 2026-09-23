extends Node3D

@onready var hero: Node3D = $PinkHero

var camera: Camera3D
var orbit: Node3D
var camera_yaw: float = 0.0
var camera_distance: float = 7.4
var touch_start := Vector2.ZERO
var touching: bool = false
var state_label: Label
var view_label: Label
var auto_rotate: bool = false

func _ready() -> void:
	_setup_environment()
	_setup_stage()
	_setup_ui()
	_setup_camera()

func _process(delta: float) -> void:
	if auto_rotate:
		camera_yaw += delta * 0.42
	_update_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			touch_start = t.position
			touching = true
		else:
			touching = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		camera_yaw -= d.relative.x * 0.010
		auto_rotate = false
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			touching = m.pressed
	elif event is InputEventMouseMotion and touching:
		var mm := event as InputEventMouseMotion
		camera_yaw -= mm.relative.x * 0.010
		auto_rotate = false

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#f3b1cc")
	sky_mat.sky_horizon_color = Color("#fff1f6")
	sky_mat.ground_horizon_color = Color("#ead6df")
	sky_mat.ground_bottom_color = Color("#ccb8c0")
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.03
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	key.light_color = Color("#fff0df")
	key.light_energy = 1.8
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30.0
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24.0, 145.0, 0.0)
	rim.light_color = Color("#ff8fc8")
	rim.light_energy = 0.55
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(2.8, 3.3, 4.0)
	fill.omni_range = 11.0
	fill.light_color = Color("#b8d0ff")
	fill.light_energy = 1.2
	add_child(fill)

func _setup_stage() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#f5e9ee")
	floor_mat.roughness = 0.94

	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 3.2
	floor_mesh.bottom_radius = 3.2
	floor_mesh.height = 0.16
	floor_mesh.radial_segments = 64

	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.position.y = -0.10
	add_child(floor)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("#ff6db6")
	ring_mat.emission_enabled = true
	ring_mat.emission = Color("#ff4ca8")
	ring_mat.emission_energy_multiplier = 1.4
	ring_mat.roughness = 0.35

	var torus := TorusMesh.new()
	torus.inner_radius = 2.45
	torus.outer_radius = 2.53
	torus.rings = 64
	torus.ring_segments = 16

	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = ring_mat
	ring.rotation_degrees.x = 90.0
	ring.position.y = 0.005
	add_child(ring)

func _setup_camera() -> void:
	orbit = Node3D.new()
	add_child(orbit)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 45.0
	camera.near = 0.05
	camera.far = 50.0
	orbit.add_child(camera)
	_update_camera()

func _update_camera() -> void:
	var target := Vector3(0.0, 1.95, 0.0)
	var x := sin(camera_yaw) * camera_distance
	var z := cos(camera_yaw) * camera_distance
	camera.global_position = Vector3(x, 2.45, z)
	camera.look_at(target, Vector3.UP)

	if view_label == null:
		return
	var deg: float = fposmod(rad_to_deg(camera_yaw), 360.0)
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

func _setup_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var top := ColorRect.new()
	top.color = Color(0.06, 0.035, 0.075, 0.82)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 128
	ui.add_child(top)

	var title := _label("PINK HERO 3D VIEWER", 32, Color("#ff72b7"))
	title.position = Vector2(28, 22)
	ui.add_child(title)

	state_label = _label("IDLE", 19, Color.WHITE)
	state_label.position = Vector2(30, 72)
	ui.add_child(state_label)

	view_label = _label("FRONT", 19, Color("#ffd861"))
	view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	view_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	view_label.offset_left = -260
	view_label.offset_right = -28
	view_label.offset_top = 72
	view_label.offset_bottom = 108
	ui.add_child(view_label)

	var hint := _label("Drag left/right to inspect the 3D hero", 19, Color("#55434d"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -245
	hint.offset_bottom = -205
	ui.add_child(hint)

	var bottom := ColorRect.new()
	bottom.color = Color(1.0, 0.96, 0.98, 0.93)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -195
	ui.add_child(bottom)

	var states := ["IDLE", "RUN", "JUMP", "SLIDE"]
	for i in range(states.size()):
		var b := Button.new()
		b.text = states[i]
		b.add_theme_font_size_override("font_size", 19)
		b.position = Vector2(26 + i * 258, 1738)
		b.size = Vector2(230, 64)
		b.pressed.connect(_set_state.bind(states[i].to_lower()))
		ui.add_child(b)

	var views := [
		["FRONT", 0.0],
		["SIDE", -PI * 0.5],
		["BACK", PI],
		["AUTO", 999.0]
	]
	for i in range(views.size()):
		var b := Button.new()
		b.text = String(views[i][0])
		b.add_theme_font_size_override("font_size", 17)
		b.position = Vector2(26 + i * 258, 1810)
		b.size = Vector2(230, 56)
		b.pressed.connect(_set_view.bind(float(views[i][1])))
		ui.add_child(b)

func _set_state(s: String) -> void:
	if hero.has_method("set_state"):
		hero.call("set_state", s)
	state_label.text = s.to_upper()

func _set_view(angle: float) -> void:
	if angle > 100.0:
		auto_rotate = not auto_rotate
	else:
		auto_rotate = false
		camera_yaw = angle

func _label(text_value: String, size_value: int, color_value: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_color_override("font_color", color_value)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.35))
	return l
