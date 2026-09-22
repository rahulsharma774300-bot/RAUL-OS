extends Node3D

var hero: Node3D
var body_root: Node3D
var head_root: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var tail_root: Node3D
var tail_segments: Array[Node3D] = []
var camera: Camera3D

var state: String = "Idle"
var anim_time: float = 0.0
var yaw_target: float = 0.0
var mouse_down: bool = false

var status_label: Label
var angle_label: Label

var mat_fur: StandardMaterial3D
var mat_shirt: StandardMaterial3D
var mat_denim: StandardMaterial3D
var mat_cream: StandardMaterial3D
var mat_black: StandardMaterial3D
var mat_lens: StandardMaterial3D
var mat_gold: StandardMaterial3D
var mat_nose: StandardMaterial3D
var mat_darkpink: StandardMaterial3D
var mat_floor: StandardMaterial3D

func _ready() -> void:
	_make_materials()
	_make_environment()
	_make_stage()
	_make_hero()
	_make_camera()
	_make_ui()
	_set_state("Idle")

func _process(delta: float) -> void:
	anim_time += delta
	_update_preview_animation(delta)
	hero.rotation.y = lerp_angle(hero.rotation.y, yaw_target, min(1.0, delta * 7.0))
	_update_angle_label()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		yaw_target += drag.relative.x * 0.012
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = mb.pressed
	elif event is InputEventMouseMotion and mouse_down:
		var mm := event as InputEventMouseMotion
		yaw_target += mm.relative.x * 0.012

func _make_materials() -> void:
	mat_fur = _mat(Color("#FF7EB6"), 0.54)
	mat_shirt = _mat(Color("#F87CA7"), 0.68)
	mat_denim = _mat(Color("#5B88C7"), 0.78)
	mat_cream = _mat(Color("#F7E7D6"), 0.72)
	mat_black = _mat(Color("#1A1A1A"), 0.30, 0.18)
	mat_lens = _mat(Color("#1B263A"), 0.12, 0.28)
	mat_gold = _mat(Color("#D4A017"), 0.22, 0.74)
	mat_nose = _mat(Color("#C72F62"), 0.42)
	mat_darkpink = _mat(Color("#D34D8B"), 0.55)
	mat_floor = _mat(Color("#F7EDF1"), 0.96)

func _mat(c: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	return m

func _make_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#F7D6E3")
	sky_mat.sky_horizon_color = Color("#FFF5F7")
	sky_mat.ground_horizon_color = Color("#F5E4EB")
	sky_mat.ground_bottom_color = Color("#EBCDD9")
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.88
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color("#FFF0E0")
	key.light_energy = 1.65
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 24.0
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30.0, 145.0, 0.0)
	rim.light_color = Color("#FF8BC6")
	rim.light_energy = 0.50
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(2.4, 3.0, 4.0)
	fill.omni_range = 10.0
	fill.light_color = Color("#A8C7FF")
	fill.light_energy = 1.6
	add_child(fill)

func _make_stage() -> void:
	var floor := _box(Vector3(6.0, 0.08, 6.0), mat_floor)
	floor.position = Vector3(0.0, -0.08, 0.0)
	add_child(floor)

	var ring := TorusMesh.new()
	ring.inner_radius = 1.9
	ring.outer_radius = 2.0
	ring.rings = 48
	ring.ring_segments = 16
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	var glow := _mat(Color("#FFB5D7"), 0.42)
	glow.emission_enabled = true
	glow.emission = Color("#FF6BB6")
	glow.emission_energy_multiplier = 1.5
	ring_node.material_override = glow
	ring_node.rotation_degrees.x = 90.0
	ring_node.position.y = 0.012
	add_child(ring_node)

	for side in [-1.0, 1.0]:
		var pillar := _box(Vector3(0.08, 2.3, 0.08), mat_gold)
		pillar.position = Vector3(side * 2.7, 2.3, -1.2)
		add_child(pillar)
		var orb := _sphere(0.16, mat_gold)
		orb.position = Vector3(side * 2.7, 4.68, -1.2)
		add_child(orb)

func _make_hero() -> void:
	hero = Node3D.new()
	hero.name = "PinkDashHero"
	add_child(hero)

	# Legs first: tall/slim proportions and oversized paws.
	left_leg = _make_leg(-0.20)
	right_leg = _make_leg(0.20)
	hero.add_child(left_leg)
	hero.add_child(right_leg)

	# Shorts.
	var shorts_root := Node3D.new()
	shorts_root.position.y = 1.48
	hero.add_child(shorts_root)
	for side in [-1.0, 1.0]:
		var short_leg := _rounded_box(Vector3(0.24, 0.27, 0.27), mat_denim)
		short_leg.position = Vector3(side * 0.22, -0.12, 0.0)
		shorts_root.add_child(short_leg)
	var waistband := _rounded_box(Vector3(0.48, 0.12, 0.28), mat_denim)
	waistband.position = Vector3(0.0, 0.12, 0.0)
	shorts_root.add_child(waistband)
	for side in [-1.0, 1.0]:
		var cuff := _box(Vector3(0.22, 0.025, 0.285), mat_cream)
		cuff.position = Vector3(side * 0.22, -0.39, 0.0)
		cuff.scale.y = 0.25
		shorts_root.add_child(cuff)

	# Shirt/torso.
	body_root = Node3D.new()
	body_root.position = Vector3(0.0, 2.16, 0.0)
	hero.add_child(body_root)

	var shirt_body := _capsule(0.43, 1.02, mat_shirt)
	shirt_body.scale = Vector3(1.10, 1.0, 0.78)
	body_root.add_child(shirt_body)
	var hem := _rounded_box(Vector3(0.47, 0.12, 0.31), mat_shirt)
	hem.position = Vector3(0.0, -0.47, 0.0)
	body_root.add_child(hem)

	# Shirt sleeves.
	for side in [-1.0, 1.0]:
		var sleeve := _capsule(0.20, 0.48, mat_shirt)
		sleeve.position = Vector3(side * 0.48, 0.23, 0.0)
		sleeve.rotation_degrees.z = side * 72.0
		body_root.add_child(sleeve)

	# Arms.
	left_arm = _make_arm(-0.53)
	right_arm = _make_arm(0.53)
	hero.add_child(left_arm)
	hero.add_child(right_arm)

	# Neck.
	var neck := _capsule(0.13, 0.50, mat_cream)
	neck.position = Vector3(0.0, 2.78, 0.0)
	hero.add_child(neck)

	# Head.
	head_root = Node3D.new()
	head_root.position = Vector3(0.0, 3.26, -0.02)
	hero.add_child(head_root)
	_make_head(head_root)

	# Chain.
	_make_chain()

	# Watch on right wrist.
	var watch_band := TorusMesh.new()
	watch_band.inner_radius = 0.105
	watch_band.outer_radius = 0.135
	watch_band.rings = 20
	watch_band.ring_segments = 10
	var watch := MeshInstance3D.new()
	watch.mesh = watch_band
	watch.material_override = mat_gold
	watch.position = Vector3(0.53, 1.58, -0.02)
	watch.rotation_degrees.z = 90.0
	hero.add_child(watch)
	var face := _cylinder(0.085, 0.085, 0.035, mat_gold)
	face.position = Vector3(0.64, 1.58, -0.02)
	face.rotation_degrees.z = 90.0
	hero.add_child(face)

	# Tail.
	tail_root = Node3D.new()
	tail_root.name = "Tail"
	tail_root.position = Vector3(0.0, 1.62, 0.20)
	hero.add_child(tail_root)
	for i in range(18):
		var t: float = float(i) / 17.0
		var radius: float = 0.105 - t * 0.048
		var seg_root := Node3D.new()
		var seg := _capsule(radius, 0.25, mat_fur)
		seg.rotation_degrees.x = 90.0
		seg_root.add_child(seg)
		var a: float = t * 3.6
		seg_root.position = Vector3(0.10 + sin(a) * 0.42, -0.12 + t * 0.52 + sin(t * PI) * 0.18, 0.20 + t * 1.35)
		seg_root.rotation_degrees = Vector3(0.0, sin(a) * 20.0, 0.0)
		tail_root.add_child(seg_root)
		tail_segments.append(seg_root)

	# Subtle shadow.
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.08, 0.03, 0.08, 0.22)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow := _sphere(0.75, shadow_mat)
	shadow.scale = Vector3(1.0, 0.03, 0.62)
	shadow.position = Vector3(0.0, 0.025, 0.02)
	hero.add_child(shadow)

func _make_leg(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 1.48, 0.0)

	var leg := _capsule(0.105, 1.52, mat_fur)
	leg.position = Vector3(0.0, -0.67, 0.0)
	pivot.add_child(leg)

	var paw := _sphere(0.30, mat_fur)
	paw.scale = Vector3(1.22, 0.53, 1.62)
	paw.position = Vector3(0.0, -1.39, -0.18)
	pivot.add_child(paw)

	for toe_i in range(3):
		var toe := _box(Vector3(0.018, 0.08, 0.02), mat_darkpink)
		toe.position = Vector3(-0.10 + float(toe_i) * 0.10, -1.42, -0.47)
		pivot.add_child(toe)
	return pivot

func _make_arm(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 2.42, 0.0)

	var arm := _capsule(0.09, 1.22, mat_fur)
	arm.position = Vector3(0.0, -0.52, 0.0)
	pivot.add_child(arm)

	var hand := _sphere(0.16, mat_fur)
	hand.scale = Vector3(0.90, 1.06, 0.88)
	hand.position = Vector3(0.0, -1.10, 0.0)
	pivot.add_child(hand)
	return pivot

func _make_head(parent: Node3D) -> void:
	var cranium := _sphere(0.47, mat_fur)
	cranium.scale = Vector3(1.06, 0.92, 1.00)
	parent.add_child(cranium)

	# Cheeks/muzzle.
	for side in [-1.0, 1.0]:
		var muzzle := _sphere(0.22, mat_cream)
		muzzle.scale = Vector3(1.00, 0.75, 0.82)
		muzzle.position = Vector3(side * 0.15, -0.12, -0.35)
		parent.add_child(muzzle)

	# Chin.
	var chin := _sphere(0.18, mat_cream)
	chin.scale = Vector3(0.95, 0.72, 0.80)
	chin.position = Vector3(0.0, -0.28, -0.30)
	parent.add_child(chin)

	# Nose.
	var nose := _sphere(0.11, mat_nose)
	nose.scale = Vector3(1.18, 0.72, 0.76)
	nose.position = Vector3(0.0, -0.045, -0.50)
	parent.add_child(nose)

	# Ears.
	for side in [-1.0, 1.0]:
		var ear := _sphere(0.18, mat_fur)
		ear.scale = Vector3(0.76, 1.10, 0.52)
		ear.position = Vector3(side * 0.37, 0.24, -0.01)
		parent.add_child(ear)
		var inner := _sphere(0.105, mat_cream)
		inner.scale = Vector3(0.72, 0.96, 0.38)
		inner.position = Vector3(side * 0.375, 0.24, -0.10)
		parent.add_child(inner)

	# Sunglasses lenses + frame.
	for side in [-1.0, 1.0]:
		var lens := _rounded_box(Vector3(0.20, 0.125, 0.035), mat_lens)
		lens.position = Vector3(side * 0.21, 0.09, -0.43)
		lens.rotation_degrees.z = side * 5.0
		parent.add_child(lens)

		var shine := _box(Vector3(0.065, 0.012, 0.006), mat_cream)
		shine.position = Vector3(side * 0.23 - side * 0.02, 0.135, -0.475)
		shine.rotation_degrees.z = side * 5.0
		parent.add_child(shine)

		var temple := _box(Vector3(0.13, 0.025, 0.022), mat_black)
		temple.position = Vector3(side * 0.43, 0.10, -0.28)
		temple.rotation_degrees.y = side * 30.0
		parent.add_child(temple)

	var bridge := _box(Vector3(0.055, 0.022, 0.025), mat_black)
	bridge.position = Vector3(0.0, 0.095, -0.45)
	parent.add_child(bridge)

	# Brows peeking above sunglasses.
	for side in [-1.0, 1.0]:
		var brow := _box(Vector3(0.11, 0.025, 0.022), mat_black)
		brow.position = Vector3(side * 0.20, 0.275, -0.38)
		brow.rotation_degrees.z = side * 12.0
		parent.add_child(brow)

	# Whiskers as thin rods.
	for side in [-1.0, 1.0]:
		for j in range(3):
			var whisker := _cylinder(0.008, 0.008, 0.60, mat_black)
			whisker.rotation_degrees.z = 90.0 + side * float(j - 1) * 8.0
			whisker.rotation_degrees.y = 90.0
			whisker.position = Vector3(side * 0.34, -0.10 + float(j - 1) * 0.07, -0.40)
			parent.add_child(whisker)

func _make_chain() -> void:
	for i in range(13):
		var t: float = float(i) / 12.0
		var angle: float = lerpf(-2.72, -0.42, t)
		var bead := _sphere(0.045, mat_gold)
		bead.position = Vector3(cos(angle) * 0.30, 2.74 + sin(angle) * 0.22, -0.27)
		hero.add_child(bead)
	var pendant := _rounded_box(Vector3(0.075, 0.095, 0.026), mat_gold)
	pendant.position = Vector3(0.0, 2.47, -0.31)
	hero.add_child(pendant)
	var pendant_mark := _sphere(0.022, mat_black)
	pendant_mark.position = Vector3(0.0, 2.47, -0.34)
	hero.add_child(pendant_mark)

func _make_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 2.25, 7.25)
	camera.fov = 46.0
	camera.near = 0.05
	camera.far = 40.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.85, 0.0), Vector3.UP)

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var top := ColorRect.new()
	top.color = Color(0.07, 0.045, 0.10, 0.80)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 128.0
	layer.add_child(top)

	var title := _label("PINK DASH  •  HERO LAB", 31, Color("#FF75BB"))
	title.position = Vector2(28, 24)
	layer.add_child(title)

	status_label = _label("STAGE 1 — HERO PROTOTYPE", 18, Color.WHITE)
	status_label.position = Vector2(30, 72)
	layer.add_child(status_label)

	angle_label = _label("FRONT", 18, Color("#FFD45C"))
	angle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	angle_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	angle_label.offset_left = -260
	angle_label.offset_right = -25
	angle_label.offset_top = 72
	angle_label.offset_bottom = 105
	layer.add_child(angle_label)

	var hint := _label("SWIPE TO ROTATE HERO", 17, Color("#4D4A54"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -235
	hint.offset_bottom = -200
	layer.add_child(hint)

	var panel := ColorRect.new()
	panel.color = Color(1.0, 0.97, 0.985, 0.93)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -190
	layer.add_child(panel)

	var states := ["Idle", "Run", "Jump", "Slide"]
	for i in range(states.size()):
		var b := Button.new()
		b.text = String(states[i]).to_upper()
		b.add_theme_font_size_override("font_size", 19)
		b.position = Vector2(28 + i * 255, 1735)
		b.size = Vector2(230, 66)
		b.pressed.connect(_set_state.bind(String(states[i])))
		layer.add_child(b)

	var views := [
		["FRONT", 0.0],
		["SIDE", -PI * 0.5],
		["BACK", PI],
		["3/4", -PI * 0.25]
	]
	for i in range(views.size()):
		var vb := Button.new()
		vb.text = String(views[i][0])
		vb.add_theme_font_size_override("font_size", 16)
		vb.position = Vector2(28 + i * 255, 1810)
		vb.size = Vector2(230, 55)
		vb.pressed.connect(_set_view.bind(float(views[i][1])))
		layer.add_child(vb)

func _label(text_value: String, size_value: int, color_value: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_color_override("font_color", color_value)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06, 0.40))
	return l

func _set_state(next_state: String) -> void:
	state = next_state
	anim_time = 0.0
	status_label.text = "ANIMATION TEST — " + state.to_upper()

func _set_view(next_yaw: float) -> void:
	yaw_target = next_yaw

func _update_angle_label() -> void:
	var deg: float = fposmod(rad_to_deg(hero.rotation.y), 360.0)
	if deg < 22.5 or deg >= 337.5:
		angle_label.text = "FRONT"
	elif deg < 67.5:
		angle_label.text = "3/4 LEFT"
	elif deg < 112.5:
		angle_label.text = "LEFT SIDE"
	elif deg < 157.5:
		angle_label.text = "BACK 3/4"
	elif deg < 202.5:
		angle_label.text = "BACK"
	elif deg < 247.5:
		angle_label.text = "BACK 3/4"
	elif deg < 292.5:
		angle_label.text = "RIGHT SIDE"
	else:
		angle_label.text = "3/4 RIGHT"

func _update_preview_animation(delta: float) -> void:
	if not hero:
		return

	# Neutral defaults.
	hero.position.y = 0.0
	body_root.rotation = Vector3.ZERO
	head_root.rotation = Vector3.ZERO
	left_arm.rotation = Vector3.ZERO
	right_arm.rotation = Vector3.ZERO
	left_leg.rotation = Vector3.ZERO
	right_leg.rotation = Vector3.ZERO

	var phase: float = anim_time * 8.6

	match state:
		"Idle":
			var breathe: float = sin(anim_time * 2.0)
			hero.position.y = breathe * 0.012
			body_root.scale = Vector3(1.0 + breathe * 0.008, 1.0 + breathe * 0.014, 1.0)
			head_root.rotation.z = sin(anim_time * 1.25) * 0.028
			left_arm.rotation.z = -0.07
			right_arm.rotation.z = 0.07
		"Run":
			var swing: float = sin(phase)
			var bob: float = abs(sin(phase)) * 0.065
			hero.position.y = bob
			left_leg.rotation.x = swing * 0.72
			right_leg.rotation.x = -swing * 0.72
			left_arm.rotation.x = -swing * 0.82
			right_arm.rotation.x = swing * 0.82
			body_root.rotation.x = -0.10
			body_root.rotation.z = sin(phase * 0.5) * 0.035
			head_root.rotation.x = 0.06
		"Jump":
			var cycle: float = fposmod(anim_time, 1.5) / 1.5
			var arc: float = sin(cycle * PI)
			hero.position.y = arc * 1.10
			left_leg.rotation.x = -0.28 + arc * 0.30
			right_leg.rotation.x = 0.18 - arc * 0.22
			left_arm.rotation.x = -0.80 * arc
			right_arm.rotation.x = -0.80 * arc
			body_root.rotation.x = -0.12 * arc
		"Slide":
			var pulse: float = 0.5 + 0.5 * sin(anim_time * 3.0)
			hero.position.y = -0.32
			body_root.rotation.x = -0.42
			head_root.rotation.x = 0.22
			left_leg.rotation.x = -0.68
			right_leg.rotation.x = -0.30
			left_arm.rotation.x = -0.35 - pulse * 0.15
			right_arm.rotation.x = -0.35 - pulse * 0.15

	# Tail always feels alive.
	tail_root.rotation.y = sin(anim_time * 2.8) * 0.18
	tail_root.rotation.z = sin(anim_time * 1.9) * 0.08
	for i in range(tail_segments.size()):
		var t: float = float(i) / float(max(1, tail_segments.size() - 1))
		tail_segments[i].rotation.y = sin(anim_time * 3.2 - t * 2.4) * (0.06 + t * 0.16)

func _rounded_box(half: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = half * 2.0
	mesh.subdivide_width = 2
	mesh.subdivide_height = 2
	mesh.subdivide_depth = 2
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	return n

func _box(half: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = half * 2.0
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	return n

func _sphere(radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 28
	mesh.rings = 18
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	return n

func _capsule(radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = max(height, radius * 2.05)
	mesh.radial_segments = 24
	mesh.rings = 12
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	return n

func _cylinder(top_radius: float, bottom_radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	return n
