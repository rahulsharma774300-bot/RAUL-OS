extends Node3D

var fur: StandardMaterial3D
var cream: StandardMaterial3D
var shirt: StandardMaterial3D
var denim: StandardMaterial3D
var black: StandardMaterial3D
var glass: StandardMaterial3D
var gold: StandardMaterial3D
var nose_mat: StandardMaterial3D
var shirt_dark: StandardMaterial3D

var body: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var tail: Node3D
var tail_segments: Array[Node3D] = []

var anim_time: float = 0.0
var state: String = "idle"

func _ready() -> void:
	_make_materials()
	_build_character()

func _process(delta: float) -> void:
	anim_time += delta
	_animate_character()

func _make_materials() -> void:
	fur = _mat(Color("#ff68ad"), 0.58)
	cream = _mat(Color("#f5dfc8"), 0.78)
	shirt = _mat(Color("#f47dac"), 0.70)
	shirt_dark = _mat(Color("#c84f84"), 0.72)
	denim = _mat(Color("#537fae"), 0.86)
	black = _mat(Color("#121218"), 0.30, 0.14)
	glass = _mat(Color("#182335"), 0.08, 0.35)
	glass.emission_enabled = true
	glass.emission = Color("#25334c")
	glass.emission_energy_multiplier = 0.10
	gold = _mat(Color("#d7a11c"), 0.20, 0.86)
	nose_mat = _mat(Color("#c72d63"), 0.45)

func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _build_character() -> void:
	body = Node3D.new()
	body.name = "CharacterBody"
	add_child(body)

	left_leg = _make_leg(-0.22)
	right_leg = _make_leg(0.22)
	body.add_child(left_leg)
	body.add_child(right_leg)

	var shorts := Node3D.new()
	shorts.position.y = 1.55
	body.add_child(shorts)

	var waist := _box(Vector3(0.47, 0.18, 0.28), denim)
	shorts.add_child(waist)

	for side in [-1.0, 1.0]:
		var short_leg := _box(Vector3(0.24, 0.30, 0.28), denim)
		short_leg.position = Vector3(side * 0.22, -0.23, 0.0)
		shorts.add_child(short_leg)

		var cuff := _box(Vector3(0.23, 0.022, 0.29), cream)
		cuff.position = Vector3(side * 0.22, -0.53, 0.0)
		cuff.scale.y = 0.35
		shorts.add_child(cuff)

	var torso := _capsule(0.43, 1.10, shirt)
	torso.position.y = 2.23
	torso.scale = Vector3(1.12, 1.0, 0.78)
	body.add_child(torso)

	var shirt_bottom := _box(Vector3(0.49, 0.15, 0.30), shirt)
	shirt_bottom.position.y = 1.72
	body.add_child(shirt_bottom)

	for side in [-1.0, 1.0]:
		var sleeve := _capsule(0.19, 0.52, shirt)
		sleeve.position = Vector3(side * 0.52, 2.39, 0.0)
		sleeve.rotation_degrees.z = side * 72.0
		body.add_child(sleeve)

	left_arm = _make_arm(-0.58)
	right_arm = _make_arm(0.58)
	body.add_child(left_arm)
	body.add_child(right_arm)

	var neck := _capsule(0.14, 0.58, cream)
	neck.position.y = 2.92
	body.add_child(neck)

	head = Node3D.new()
	head.position = Vector3(0.0, 3.48, -0.03)
	body.add_child(head)
	_build_head()

	_build_chain()
	_build_watch()
	_build_tail()

	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.07, 0.02, 0.07, 0.24)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow := _sphere(0.72, shadow_material)
	shadow.scale = Vector3(1.0, 0.035, 0.62)
	shadow.position = Vector3(0.0, 0.025, 0.0)
	add_child(shadow)

func _build_head() -> void:
	var skull := _sphere(0.48, fur)
	skull.scale = Vector3(1.07, 0.92, 1.0)
	head.add_child(skull)

	for side in [-1.0, 1.0]:
		var ear := _sphere(0.18, fur)
		ear.scale = Vector3(0.75, 1.10, 0.50)
		ear.position = Vector3(side * 0.38, 0.24, 0.0)
		head.add_child(ear)

		var inner := _sphere(0.10, cream)
		inner.scale = Vector3(0.78, 1.0, 0.42)
		inner.position = Vector3(side * 0.38, 0.24, -0.11)
		head.add_child(inner)

	for side in [-1.0, 1.0]:
		var muzzle := _sphere(0.22, cream)
		muzzle.scale = Vector3(1.0, 0.72, 0.80)
		muzzle.position = Vector3(side * 0.15, -0.13, -0.36)
		head.add_child(muzzle)

	var chin := _sphere(0.18, cream)
	chin.scale = Vector3(0.95, 0.76, 0.80)
	chin.position = Vector3(0.0, -0.30, -0.31)
	head.add_child(chin)

	var nose := _sphere(0.11, nose_mat)
	nose.scale = Vector3(1.20, 0.72, 0.76)
	nose.position = Vector3(0.0, -0.05, -0.51)
	head.add_child(nose)

	for side in [-1.0, 1.0]:
		var lens := _box(Vector3(0.21, 0.13, 0.035), glass)
		lens.position = Vector3(side * 0.22, 0.09, -0.44)
		lens.rotation_degrees.z = side * 5.0
		head.add_child(lens)

		var shine := _box(Vector3(0.055, 0.010, 0.006), cream)
		shine.position = Vector3(side * 0.22 - side * 0.03, 0.135, -0.481)
		shine.rotation_degrees.z = side * 5.0
		head.add_child(shine)

		var temple := _box(Vector3(0.14, 0.025, 0.022), black)
		temple.position = Vector3(side * 0.42, 0.10, -0.30)
		temple.rotation_degrees.y = side * 24.0
		head.add_child(temple)

	var bridge := _box(Vector3(0.06, 0.022, 0.025), black)
	bridge.position = Vector3(0.0, 0.09, -0.45)
	head.add_child(bridge)

	for side in [-1.0, 1.0]:
		var brow := _box(Vector3(0.12, 0.025, 0.025), black)
		brow.position = Vector3(side * 0.21, 0.28, -0.38)
		brow.rotation_degrees.z = side * 12.0
		head.add_child(brow)

	for side in [-1.0, 1.0]:
		for j in range(3):
			var whisker := _cylinder(0.006, 0.006, 0.58, black)
			whisker.position = Vector3(side * 0.34, -0.12 + float(j - 1) * 0.07, -0.43)
			whisker.rotation_degrees.z = 90.0 + side * float(j - 1) * 7.0
			whisker.rotation_degrees.y = 90.0
			head.add_child(whisker)

func _make_leg(x: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, 1.46, 0.0)

	var leg := _capsule(0.105, 1.50, fur)
	leg.position.y = -0.66
	root.add_child(leg)

	var paw := _sphere(0.31, fur)
	paw.scale = Vector3(1.25, 0.55, 1.60)
	paw.position = Vector3(0.0, -1.40, -0.18)
	root.add_child(paw)

	for toe_i in range(3):
		var toe_mark := _box(Vector3(0.012, 0.055, 0.014), shirt_dark)
		toe_mark.position = Vector3(-0.10 + float(toe_i) * 0.10, -1.44, -0.48)
		root.add_child(toe_mark)

	return root

func _make_arm(x: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, 2.43, 0.0)

	var arm := _capsule(0.09, 1.18, fur)
	arm.position.y = -0.52
	root.add_child(arm)

	var hand := _sphere(0.16, fur)
	hand.scale = Vector3(0.92, 1.05, 0.90)
	hand.position.y = -1.08
	root.add_child(hand)
	return root

func _build_chain() -> void:
	for i in range(13):
		var t: float = float(i) / 12.0
		var angle: float = lerpf(-2.7, -0.45, t)
		var bead := _sphere(0.045, gold)
		bead.position = Vector3(cos(angle) * 0.30, 2.80 + sin(angle) * 0.22, -0.27)
		body.add_child(bead)

	var pendant := _box(Vector3(0.08, 0.10, 0.03), gold)
	pendant.position = Vector3(0.0, 2.52, -0.30)
	body.add_child(pendant)

	var pendant_mark := _sphere(0.020, black)
	pendant_mark.position = Vector3(0.0, 2.52, -0.335)
	body.add_child(pendant_mark)

func _build_watch() -> void:
	var watch_band_mesh := TorusMesh.new()
	watch_band_mesh.inner_radius = 0.10
	watch_band_mesh.outer_radius = 0.135
	watch_band_mesh.rings = 20
	watch_band_mesh.ring_segments = 10

	var band := MeshInstance3D.new()
	band.mesh = watch_band_mesh
	band.material_override = gold
	band.position = Vector3(0.61, 1.75, -0.02)
	band.rotation_degrees.z = 90.0
	body.add_child(band)

	var face := _cylinder(0.08, 0.08, 0.035, black)
	face.position = Vector3(0.735, 1.75, -0.02)
	face.rotation_degrees.z = 90.0
	body.add_child(face)

func _build_tail() -> void:
	tail = Node3D.new()
	tail.position = Vector3(0.10, 1.62, 0.20)
	body.add_child(tail)

	for i in range(20):
		var t: float = float(i) / 19.0
		var radius: float = 0.10 - t * 0.045
		var holder := Node3D.new()
		var segment := _capsule(radius, 0.23, fur)
		segment.rotation_degrees.x = 90.0
		holder.add_child(segment)

		var a: float = t * 3.8
		holder.position = Vector3(
			sin(a) * 0.40,
			t * 0.50 + sin(t * PI) * 0.18,
			t * 1.35
		)
		tail.add_child(holder)
		tail_segments.append(holder)

func set_state(new_state: String) -> void:
	state = new_state.to_lower()
	anim_time = 0.0

func _animate_character() -> void:
	if not body:
		return

	body.rotation = Vector3.ZERO
	body.position = Vector3.ZERO
	head.rotation = Vector3.ZERO
	left_leg.rotation = Vector3.ZERO
	right_leg.rotation = Vector3.ZERO
	left_arm.rotation = Vector3.ZERO
	right_arm.rotation = Vector3.ZERO

	var p: float = anim_time

	match state:
		"idle":
			body.position.y = sin(p * 2.2) * 0.015
			head.rotation.z = sin(p * 1.4) * 0.025
			tail.rotation.y = sin(p * 2.5) * 0.15

		"run":
			var swing: float = sin(p * 9.0)
			left_leg.rotation.x = swing * 0.70
			right_leg.rotation.x = -swing * 0.70
			left_arm.rotation.x = -swing * 0.80
			right_arm.rotation.x = swing * 0.80
			body.position.y = abs(sin(p * 9.0)) * 0.06
			body.rotation.x = -0.06
			tail.rotation.y = sin(p * 5.5) * 0.20

		"jump":
			var cycle: float = fposmod(p, 1.45) / 1.45
			var arc: float = sin(cycle * PI)
			body.position.y = arc * 1.20
			left_arm.rotation.x = -arc * 0.70
			right_arm.rotation.x = -arc * 0.70
			left_leg.rotation.x = -0.20 * arc
			right_leg.rotation.x = 0.18 * arc

		"slide":
			body.position.y = -0.30
			body.rotation.x = -0.32
			head.rotation.x = 0.12
			left_leg.rotation.x = -0.60
			right_leg.rotation.x = -0.35
			left_arm.rotation.x = -0.35
			right_arm.rotation.x = -0.35

	for i in range(tail_segments.size()):
		var t_seg: float = float(i) / float(max(1, tail_segments.size() - 1))
		tail_segments[i].rotation.y = sin(p * 3.0 - t_seg * 2.4) * (0.04 + 0.15 * t_seg)

func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size * 2.0
	mesh.subdivide_width = 1
	mesh.subdivide_height = 1
	mesh.subdivide_depth = 1

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return node

func _sphere(radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 28
	mesh.rings = 18

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return node

func _capsule(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = max(height, radius * 2.05)
	mesh.radial_segments = 24
	mesh.rings = 12

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return node

func _cylinder(top_radius: float, bottom_radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return node
