extends Node3D

const LANES := [-2.45, 0.0, 2.45]
const CHUNK_LENGTH := 16.0
const CHUNK_COUNT := 14
const PLAYER_Z := 1.0

var rng := RandomNumberGenerator.new()

var player: Node3D
var visual: Node3D
var anim_player: AnimationPlayer
var camera: Camera3D
var city_root: Node3D
var obstacle_root: Node3D
var coin_root: Node3D
var speed_root: Node3D

var mat_road: StandardMaterial3D
var mat_sidewalk: StandardMaterial3D
var mat_white: StandardMaterial3D
var mat_pink: StandardMaterial3D
var mat_pink_dark: StandardMaterial3D
var mat_gold: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_black: StandardMaterial3D
var mat_blue: StandardMaterial3D
var mat_red: StandardMaterial3D
var mat_cyan: StandardMaterial3D
var mat_green: StandardMaterial3D
var mat_concrete: StandardMaterial3D
var mat_neon_pink: StandardMaterial3D
var mat_neon_cyan: StandardMaterial3D

var chunks: Array[Node3D] = []
var obstacles: Array = []
var coins_world: Array = []
var powerups: Array = []
var streaks: Array[Node3D] = []
var building_scenes: Array[PackedScene] = []
var barrier_scene: PackedScene
var lamp_scene: PackedScene
var character_scene: PackedScene

var lane := 1
var target_x := 0.0
var jump_y := 0.0
var jump_v := 0.0
var slide_time := 0.0
var magnet_time := 0.0
var shield_time := 0.0
var speed := 10.0
var distance := 0.0
var score := 0
var coin_count := 0
var best_score := 0
var started := false
var game_over := false
var spawn_timer := 0.8
var coin_timer := 0.35
var power_timer := 9.0
var state_anim := "Run"
var run_time := 0.0
var shake := 0.0
var touch_start := Vector2.ZERO
var touch_active := false

var hud_layer: CanvasLayer
var score_label: Label
var coin_label: Label
var speed_label: Label
var best_label: Label
var start_panel: Control
var over_panel: Control
var over_score: Label
var shield_label: Label
var magnet_label: Label
var flash_rect: ColorRect

var music: AudioStreamPlayer
var sfx: AudioStreamPlayer

func _ready() -> void:
	rng.seed = 774300
	RenderingServer.set_default_clear_color(Color("#8fc8ff"))
	_make_materials()
	_setup_environment()
	_setup_scene_roots()
	_load_assets()
	_setup_player()
	_setup_camera()
	_setup_city()
	_setup_speed_lines()
	_setup_ui()
	_setup_audio()
	_load_best()
	_update_hud()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_left"):
		_lane_left()
	if Input.is_action_just_pressed("ui_right"):
		_lane_right()
	if Input.is_action_just_pressed("ui_up"):
		_jump()
	if Input.is_action_just_pressed("ui_down"):
		_slide()

	if started and not game_over:
		_update_game(delta)
	else:
		_idle_presentation(delta)

	_update_camera(delta)
	_update_ui_fx(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			touch_start = t.position
			touch_active = true
		else:
			if touch_active:
				_handle_swipe(t.position - touch_start)
			touch_active = false
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				touch_start = m.position
				touch_active = true
			else:
				if touch_active:
					_handle_swipe(m.position - touch_start)
				touch_active = false

func _handle_swipe(delta: Vector2) -> void:
	if game_over:
		_restart()
		return
	if not started:
		started = true
		start_panel.visible = false
		_play_anim("Run", 0.08, 1.1)
		return

	if delta.length() < 55.0:
		_jump()
		return

	if abs(delta.x) > abs(delta.y):
		if delta.x < 0.0:
			_lane_left()
		else:
			_lane_right()
	else:
		if delta.y < 0.0:
			_jump()
		else:
			_slide()

func _update_game(delta: float) -> void:
	run_time += delta
	distance += speed * delta
	speed = min(23.5, 10.0 + distance * 0.006)
	score = int(distance * 13.0) + coin_count * 45

	var target: float = float(LANES[lane])
	target_x = target
	player.position.x = lerpf(player.position.x, target_x, min(1.0, delta * 13.0))

	if jump_y > 0.0 or jump_v > 0.0:
		jump_v -= 21.5 * delta
		jump_y += jump_v * delta
		if jump_y <= 0.0:
			jump_y = 0.0
			jump_v = 0.0
			_play_anim("Run", 0.12, 1.0 + (speed - 10.0) * 0.025)
	player.position.y = jump_y

	if slide_time > 0.0:
		slide_time -= delta
		if slide_time <= 0.0 and jump_y <= 0.01:
			_play_anim("Run", 0.12, 1.0 + (speed - 10.0) * 0.025)

	if magnet_time > 0.0:
		magnet_time -= delta
	if shield_time > 0.0:
		shield_time -= delta

	_move_chunks(delta)
	_move_obstacles(delta)
	_move_coins(delta)
	_move_powerups(delta)
	_move_speed_lines(delta)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = max(0.66, 1.22 - (speed - 10.0) * 0.035)
		_spawn_obstacle_pattern()

	coin_timer -= delta
	if coin_timer <= 0.0:
		coin_timer = rng.randf_range(0.72, 1.05)
		_spawn_coin_trail()

	power_timer -= delta
	if power_timer <= 0.0:
		power_timer = rng.randf_range(9.0, 14.0)
		_spawn_powerup()

	_update_character_fx(delta)
	_update_hud()

func _idle_presentation(delta: float) -> void:
	run_time += delta
	if visual:
		visual.rotation.y = lerpf(visual.rotation.y, -0.18 if not game_over else 0.0, delta * 1.8)
		if not game_over:
			player.position.y = sin(run_time * 2.0) * 0.02
	_move_speed_lines(delta * 0.28)

func _setup_scene_roots() -> void:
	city_root = Node3D.new()
	city_root.name = "City"
	add_child(city_root)

	obstacle_root = Node3D.new()
	obstacle_root.name = "Obstacles"
	add_child(obstacle_root)

	coin_root = Node3D.new()
	coin_root.name = "Coins"
	add_child(coin_root)

	speed_root = Node3D.new()
	speed_root.name = "SpeedFX"
	add_child(speed_root)

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#5da9ff")
	sky_mat.sky_horizon_color = Color("#ffd4c8")
	sky_mat.ground_horizon_color = Color("#d7b9c8")
	sky_mat.ground_bottom_color = Color("#6f7a91")
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.18
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.78
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.18
	env.fog_enabled = true
	env.fog_light_color = Color("#d9c8dc")
	env.fog_light_energy = 0.65
	env.fog_density = 0.007
	env.fog_sky_affect = 0.25
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#fff0d2")
	sun.light_energy = 1.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	fill.light_color = Color("#a7c8ff")
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	add_child(fill)

func _make_materials() -> void:
	mat_road = _mat(Color("#252832"), 0.96)
	mat_sidewalk = _mat(Color("#b8adb7"), 0.88)
	mat_white = _mat(Color("#f5f3ee"), 0.72)
	mat_pink = _mat(Color("#ff5db1"), 0.48)
	mat_pink_dark = _mat(Color("#c82169"), 0.42)
	mat_gold = _mat(Color("#f6ba35"), 0.25, 0.72)
	mat_glass = _mat(Color("#192944"), 0.12, 0.55)
	mat_black = _mat(Color("#15131b"), 0.28, 0.15)
	mat_blue = _mat(Color("#315a8f"), 0.58)
	mat_red = _mat(Color("#e83d4f"), 0.46)
	mat_cyan = _mat(Color("#4ee6ef"), 0.30, 0.25)
	mat_green = _mat(Color("#49b871"), 0.70)
	mat_concrete = _mat(Color("#918b96"), 0.86)
	mat_neon_pink = _emissive_mat(Color("#ff3ca6"), 2.7)
	mat_neon_cyan = _emissive_mat(Color("#2fe8ff"), 2.2)

func _mat(color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color, 0.32, 0.1)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func _load_assets() -> void:
	for p in [
		"res://assets/building-a.glb",
		"res://assets/building-b.glb",
		"res://assets/building-c.glb",
		"res://assets/building-d.glb",
		"res://assets/building-e.glb",
		"res://assets/building-f.glb"
	]:
		if ResourceLoader.exists(p):
			var s = load(p)
			if s is PackedScene:
				building_scenes.append(s)

	if ResourceLoader.exists("res://assets/barrier.glb"):
		var b = load("res://assets/barrier.glb")
		if b is PackedScene:
			barrier_scene = b
	if ResourceLoader.exists("res://assets/streetlight.glb"):
		var l = load("res://assets/streetlight.glb")
		if l is PackedScene:
			lamp_scene = l
	if ResourceLoader.exists("res://assets/rae.gltf"):
		var c = load("res://assets/rae.gltf")
		if c is PackedScene:
			character_scene = c

func _setup_player() -> void:
	player = Node3D.new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.0, PLAYER_Z)
	add_child(player)

	if character_scene:
		visual = character_scene.instantiate()
		visual.name = "RunnerVisual"
		player.add_child(visual)
		visual.scale = Vector3.ONE * 0.93
		visual.rotation_degrees.y = 180.0
		_tint_character(visual)
		anim_player = _find_anim_player(visual)
		_add_runner_accessories(visual)
	else:
		visual = _make_fallback_runner()
		player.add_child(visual)

	_add_runner_shadow()
	_play_anim("Idle", 0.0, 1.0)

func _tint_character(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var base := mi.get_active_material(i)
				if base is StandardMaterial3D:
					var d := base.duplicate() as StandardMaterial3D
					var c := d.albedo_color
					d.albedo_color = c.lerp(Color("#ff67b5"), 0.56)
					d.roughness = min(0.78, max(0.28, d.roughness))
					mi.set_surface_override_material(i, d)
	for child in node.get_children():
		_tint_character(child)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

func _play_anim(wanted: String, blend := 0.12, rate := 1.0) -> void:
	if not anim_player:
		return
	var wanted_lower := wanted.to_lower()
	var picked := ""
	for n in anim_player.get_animation_list():
		var low := String(n).to_lower()
		if low == wanted_lower:
			picked = String(n)
			break
		if wanted_lower in low and picked == "":
			picked = String(n)
	if picked == "" and wanted == "Duck":
		for n in anim_player.get_animation_list():
			if "crouch" in String(n).to_lower() or "duck" in String(n).to_lower():
				picked = String(n)
				break
	if picked == "":
		return
	state_anim = wanted
	anim_player.play(picked, blend, rate)

func _add_runner_accessories(parent: Node3D) -> void:
	var acc := Node3D.new()
	acc.name = "PantherAccessories"
	parent.add_child(acc)
	acc.position = Vector3(0.0, 0.0, 0.0)

	# Oversized sunglasses visible during turns/start pose.
	var left_lens := _box(Vector3(0.25, 0.12, 0.045), mat_black)
	left_lens.position = Vector3(-0.18, 1.73, -0.33)
	left_lens.rotation_degrees.z = -6.0
	acc.add_child(left_lens)
	var right_lens := _box(Vector3(0.25, 0.12, 0.045), mat_black)
	right_lens.position = Vector3(0.18, 1.73, -0.33)
	right_lens.rotation_degrees.z = 6.0
	acc.add_child(right_lens)
	var bridge := _box(Vector3(0.09, 0.025, 0.025), mat_black)
	bridge.position = Vector3(0.0, 1.73, -0.345)
	acc.add_child(bridge)

	# Backwards cap.
	var cap := _cylinder(0.28, 0.28, 0.10, mat_pink_dark)
	cap.position = Vector3(0.0, 1.98, 0.0)
	acc.add_child(cap)
	var brim := _box(Vector3(0.28, 0.045, 0.20), mat_black)
	brim.position = Vector3(0.0, 1.98, 0.23)
	acc.add_child(brim)

	# Gold chain / pendant.
	for i in range(9):
		var angle := lerpf(-2.55, -0.58, float(i) / 8.0)
		var bead := _sphere(0.045, mat_gold)
		bead.position = Vector3(cos(angle) * 0.26, 1.24 + sin(angle) * 0.17, -0.28)
		acc.add_child(bead)
	var pendant := _box(Vector3(0.07, 0.10, 0.03), mat_gold)
	pendant.position = Vector3(0.0, 1.03, -0.29)
	acc.add_child(pendant)

	# Long segmented feline tail with a smooth silhouette.
	var tail_root := Node3D.new()
	tail_root.name = "CustomTail"
	tail_root.position = Vector3(0.20, 0.75, 0.24)
	acc.add_child(tail_root)
	for i in range(13):
		var t := float(i) / 12.0
		var seg := _capsule(0.075 - t * 0.018, 0.23, mat_pink)
		var a := t * 3.6
		seg.position = Vector3(0.20 + sin(a) * 0.30, 0.04 + t * 0.35 + sin(t * PI) * 0.12, t * 0.82)
		seg.rotation_degrees = Vector3(72.0, sin(a) * 28.0, 0.0)
		tail_root.add_child(seg)

func _add_runner_shadow() -> void:
	var shadow := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	shadow.mesh = mesh
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.02, 0.015, 0.03, 0.32)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = sm
	shadow.scale = Vector3(0.68, 0.025, 0.42)
	shadow.position = Vector3(0.0, 0.03, 0.0)
	player.add_child(shadow)
	shadow.top_level = true
	shadow.global_position = Vector3(0.0, 0.03, PLAYER_Z)

func _make_fallback_runner() -> Node3D:
	var root := Node3D.new()
	var torso := _capsule(0.34, 0.9, mat_pink_dark)
	torso.position.y = 1.08
	root.add_child(torso)
	var head := _sphere(0.35, mat_pink)
	head.position = Vector3(0.0, 1.78, -0.03)
	root.add_child(head)
	var shorts := _box(Vector3(0.42, 0.25, 0.28), mat_blue)
	shorts.position.y = 0.72
	root.add_child(shorts)
	for side in [-1.0, 1.0]:
		var leg := _capsule(0.10, 0.72, mat_pink)
		leg.position = Vector3(side * 0.18, 0.34, 0.0)
		root.add_child(leg)
		var foot := _capsule(0.16, 0.46, mat_pink)
		foot.rotation_degrees.x = 90.0
		foot.position = Vector3(side * 0.18, 0.08, -0.18)
		root.add_child(foot)
	return root

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "RunnerCamera"
	camera.position = Vector3(0.0, 3.45, 8.9)
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 170.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.15, -7.0), Vector3.UP)

func _setup_city() -> void:
	for i in range(CHUNK_COUNT):
		var chunk := _make_city_chunk(i)
		chunk.position.z = -float(i) * CHUNK_LENGTH + 6.0
		city_root.add_child(chunk)
		chunks.append(chunk)

func _make_city_chunk(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%02d" % index

	var road := _box(Vector3(4.35, 0.10, CHUNK_LENGTH * 0.5), mat_road)
	road.position.y = -0.10
	root.add_child(road)

	for side in [-1.0, 1.0]:
		var sidewalk := _box(Vector3(1.30, 0.18, CHUNK_LENGTH * 0.5), mat_sidewalk)
		sidewalk.position = Vector3(side * 5.55, 0.04, 0.0)
		root.add_child(sidewalk)
		var curb := _box(Vector3(0.18, 0.25, CHUNK_LENGTH * 0.5), mat_white)
		curb.position = Vector3(side * 4.45, 0.11, 0.0)
		root.add_child(curb)

	# dashed lane separators
	for z in [-6.0, -2.0, 2.0, 6.0]:
		for x in [-1.22, 1.22]:
			var dash := _box(Vector3(0.045, 0.018, 1.05), mat_white)
			dash.position = Vector3(x, 0.025, z)
			root.add_child(dash)

	# road edge reflectors and occasional crosswalk
	for side in [-1.0, 1.0]:
		for z in [-6.0, 0.0, 6.0]:
			var reflector := _box(Vector3(0.06, 0.025, 0.18), mat_neon_cyan if index % 2 == 0 else mat_neon_pink)
			reflector.position = Vector3(side * 4.16, 0.035, z)
			root.add_child(reflector)

	if index % 5 == 0:
		for i in range(8):
			var cross := _box(Vector3(0.35, 0.020, 0.90), mat_white)
			cross.position = Vector3(-3.2 + i * 0.92, 0.03, -5.6)
			root.add_child(cross)

	_add_chunk_scenery(root, index)
	return root

func _add_chunk_scenery(root: Node3D, index: int) -> void:
	for side in [-1.0, 1.0]:
		if building_scenes.size() > 0:
			var scene := building_scenes[(index * 3 + (0 if side < 0 else 1)) % building_scenes.size()]
			var building := scene.instantiate() as Node3D
			building.name = "Building"
			building.position = Vector3(side * rng.randf_range(9.0, 10.5), 0.0, rng.randf_range(-2.5, 2.5))
			building.scale = Vector3.ONE * rng.randf_range(2.0, 2.7)
			building.rotation_degrees.y = -90.0 if side < 0 else 90.0
			root.add_child(building)
		else:
			var building := _procedural_building(index, side)
			root.add_child(building)

		# Storefront neon strips make imported buildings feel more game-like.
		var sign := _box(Vector3(0.12, 0.42, 1.10), mat_neon_pink if (index + int(side)) % 2 == 0 else mat_neon_cyan)
		sign.position = Vector3(side * 6.95, 2.15, -2.0 + side * 1.1)
		root.add_child(sign)

		if index % 2 == 0:
			if lamp_scene:
				var lamp := lamp_scene.instantiate() as Node3D
				lamp.position = Vector3(side * 5.35, 0.0, 3.4)
				lamp.scale = Vector3.ONE * 1.45
				lamp.rotation_degrees.y = 180.0 if side < 0 else 0.0
				root.add_child(lamp)
			else:
				_add_procedural_lamp(root, side * 5.25, 3.4)

		if index % 3 == 1:
			_add_tree(root, Vector3(side * 5.65, 0.18, -4.0))

func _procedural_building(index: int, side: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(side * 9.2, 0.0, 0.0)
	var h := 5.2 + float((index * 7) % 5) * 1.4
	var colors := [Color("#d86f6a"), Color("#5c8fc6"), Color("#e3af55"), Color("#7b6ab2"), Color("#66a77e")]
	var body_mat := _mat(colors[index % colors.size()], 0.72)
	var body := _box(Vector3(2.3, h * 0.5, 3.1), body_mat)
	body.position.y = h * 0.5
	root.add_child(body)
	var roof := _box(Vector3(2.5, 0.18, 3.3), mat_concrete)
	roof.position.y = h + 0.16
	root.add_child(roof)
	for floor in range(1, int(h / 1.3)):
		for col in range(3):
			var win := _box(Vector3(0.03, 0.30, 0.34), mat_glass)
			win.position = Vector3(-side * 2.32, float(floor) * 1.25, -1.65 + col * 1.65)
			root.add_child(win)
	return root

func _add_tree(parent: Node3D, pos: Vector3) -> void:
	var trunk := _cylinder(0.13, 0.16, 1.5, _mat(Color("#76523a"), 0.9))
	trunk.position = pos + Vector3(0.0, 0.75, 0.0)
	parent.add_child(trunk)
	var crown := _sphere(0.75, mat_green)
	crown.scale = Vector3(0.90, 1.15, 0.90)
	crown.position = pos + Vector3(0.0, 1.85, 0.0)
	parent.add_child(crown)

func _add_procedural_lamp(parent: Node3D, x: float, z: float) -> void:
	var pole := _cylinder(0.05, 0.06, 2.9, mat_black)
	pole.position = Vector3(x, 1.45, z)
	parent.add_child(pole)
	var bulb := _sphere(0.14, mat_neon_cyan)
	bulb.position = Vector3(x, 2.95, z)
	parent.add_child(bulb)

func _move_chunks(delta: float) -> void:
	for chunk in chunks:
		chunk.position.z += speed * delta
		if chunk.position.z > CHUNK_LENGTH + 5.5:
			chunk.position.z -= CHUNK_LENGTH * CHUNK_COUNT

func _spawn_obstacle_pattern() -> void:
	var first_lane := rng.randi_range(0, 2)
	var type := rng.randi_range(0, 3)
	_spawn_obstacle(first_lane, type, -68.0)

	if distance > 140.0 and rng.randf() < 0.35:
		var second := (first_lane + rng.randi_range(1, 2)) % 3
		_spawn_obstacle(second, rng.randi_range(0, 2), -72.5)

func _spawn_obstacle(which_lane: int, type: int, z: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(LANES[which_lane], 0.0, z)
	obstacle_root.add_child(root)

	if type == 0:
		if barrier_scene:
			var obj := barrier_scene.instantiate() as Node3D
			obj.scale = Vector3.ONE * 2.0
			obj.rotation_degrees.y = 90.0
			root.add_child(obj)
		else:
			_make_barrier(root)
	elif type == 1:
		_make_bus(root)
	elif type == 2:
		_make_overhead(root)
	else:
		_make_train(root)

	obstacles.append({"node": root, "lane": which_lane, "type": type})

func _make_barrier(root: Node3D) -> void:
	var body := _box(Vector3(0.95, 0.45, 0.22), mat_red)
	body.position.y = 0.48
	root.add_child(body)
	for x in [-0.62, 0.0, 0.62]:
		var stripe := _box(Vector3(0.16, 0.47, 0.025), mat_white)
		stripe.position = Vector3(x, 0.50, -0.245)
		stripe.rotation_degrees.z = 24.0
		root.add_child(stripe)
	for side in [-1.0, 1.0]:
		var leg := _box(Vector3(0.12, 0.36, 0.18), mat_black)
		leg.position = Vector3(side * 0.78, 0.24, 0.0)
		root.add_child(leg)

func _make_bus(root: Node3D) -> void:
	var bus_color := _mat(Color("#f3aa33") if rng.randf() < 0.5 else Color("#4b8bd4"), 0.35, 0.18)
	var body := _box(Vector3(1.03, 0.72, 2.15), bus_color)
	body.position.y = 0.83
	root.add_child(body)
	var roof := _box(Vector3(0.98, 0.13, 2.05), mat_white)
	roof.position.y = 1.58
	root.add_child(roof)
	var windshield := _box(Vector3(0.80, 0.34, 0.04), mat_glass)
	windshield.position = Vector3(0.0, 1.14, -2.18)
	root.add_child(windshield)
	for i in range(4):
		for side in [-1.0, 1.0]:
			var win := _box(Vector3(0.035, 0.28, 0.34), mat_glass)
			win.position = Vector3(side * 1.04, 1.12, -1.30 + i * 0.86)
			root.add_child(win)
	for z in [-1.35, 1.35]:
		for side in [-1.0, 1.0]:
			var wheel := _cylinder(0.23, 0.23, 0.16, mat_black)
			wheel.rotation_degrees.z = 90.0
			wheel.position = Vector3(side * 1.02, 0.27, z)
			root.add_child(wheel)
	var light_l := _sphere(0.09, mat_neon_cyan)
	light_l.position = Vector3(-0.55, 0.66, -2.22)
	root.add_child(light_l)
	var light_r := _sphere(0.09, mat_neon_cyan)
	light_r.position = Vector3(0.55, 0.66, -2.22)
	root.add_child(light_r)

func _make_overhead(root: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var pole := _cylinder(0.08, 0.09, 2.25, mat_black)
		pole.position = Vector3(side * 0.90, 1.12, 0.0)
		root.add_child(pole)
	var sign := _box(Vector3(1.10, 0.28, 0.15), mat_neon_pink)
	sign.position = Vector3(0.0, 2.18, 0.0)
	root.add_child(sign)
	var inner := _box(Vector3(0.72, 0.07, 0.16), mat_white)
	inner.position = Vector3(0.0, 2.18, -0.05)
	root.add_child(inner)

func _make_train(root: Node3D) -> void:
	var body_mat := _mat(Color("#d9dce2"), 0.28, 0.58)
	var body := _box(Vector3(1.08, 0.95, 3.7), body_mat)
	body.position.y = 1.0
	root.add_child(body)
	var lower := _box(Vector3(1.10, 0.18, 3.72), mat_pink_dark)
	lower.position.y = 0.30
	root.add_child(lower)
	for i in range(6):
		for side in [-1.0, 1.0]:
			var win := _box(Vector3(0.035, 0.28, 0.34), mat_glass)
			win.position = Vector3(side * 1.09, 1.22, -2.55 + i * 1.05)
			root.add_child(win)
	var front := _box(Vector3(0.78, 0.33, 0.04), mat_glass)
	front.position = Vector3(0.0, 1.25, -3.73)
	root.add_child(front)
	for x in [-0.55, 0.55]:
		var light := _sphere(0.10, mat_neon_cyan)
		light.position = Vector3(x, 0.63, -3.75)
		root.add_child(light)

func _move_obstacles(delta: float) -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var o = obstacles[i]
		var node := o["node"] as Node3D
		node.position.z += speed * delta
		if node.position.z > 10.0:
			node.queue_free()
			obstacles.remove_at(i)
			continue
		if abs(node.position.z - PLAYER_Z) < 1.1 and abs(player.position.x - LANES[int(o["lane"])]) < 0.68:
			var type := int(o["type"])
			var safe := false
			if type == 0:
				safe = jump_y > 0.82
			elif type == 2:
				safe = slide_time > 0.05
			if not safe:
				_hit_obstacle(i)
				return

func _hit_obstacle(index: int) -> void:
	if shield_time > 0.0:
		shield_time = 0.0
		var o = obstacles[index]
		(o["node"] as Node3D).queue_free()
		obstacles.remove_at(index)
		_flash(Color(0.25, 0.95, 1.0, 0.32))
		_play_sfx("power.wav", 0.90)
		shake = 0.32
		return
	game_over = true
	started = false
	_play_anim("Hit", 0.08, 1.0)
	_play_sfx("hit.wav", 0.95)
	_flash(Color(1.0, 0.15, 0.25, 0.40))
	shake = 0.65
	if score > best_score:
		best_score = score
		_save_best()
	over_score.text = "SCORE  %d\nCOINS  %d\nBEST  %d" % [score, coin_count, best_score]
	over_panel.visible = true

func _spawn_coin_trail() -> void:
	var l := rng.randi_range(0, 2)
	var count := rng.randi_range(6, 10)
	var arc := rng.randf() < 0.30
	for i in range(count):
		var y := 0.80
		if arc:
			y = 0.78 + sin(float(i) / float(max(1, count - 1)) * PI) * 1.45
		_spawn_coin(l, -43.0 - float(i) * 2.35, y)

func _spawn_coin(which_lane: int, z: float, y: float) -> void:
	var node := Node3D.new()
	node.position = Vector3(LANES[which_lane], y, z)
	coin_root.add_child(node)
	var coin := _cylinder(0.27, 0.27, 0.075, mat_gold)
	coin.rotation_degrees.x = 90.0
	node.add_child(coin)
	var center := _cylinder(0.14, 0.14, 0.085, mat_neon_pink)
	center.rotation_degrees.x = 90.0
	node.add_child(center)
	coins_world.append({"node": node, "lane": which_lane, "base_y": y, "t": rng.randf_range(0.0, 6.0)})

func _move_coins(delta: float) -> void:
	for i in range(coins_world.size() - 1, -1, -1):
		var c = coins_world[i]
		var node := c["node"] as Node3D
		node.position.z += speed * delta
		c["t"] = float(c["t"]) + delta * 5.5
		node.rotation.y += delta * 5.0
		node.position.y = float(c["base_y"]) + sin(float(c["t"])) * 0.06

		if magnet_time > 0.0 and node.position.z > -9.0 and node.position.z < 5.0:
			node.position.x = lerpf(node.position.x, player.position.x, min(1.0, delta * 6.5))
			node.position.y = lerpf(node.position.y, jump_y + 1.0, min(1.0, delta * 5.0))

		var near_lane: bool = abs(node.position.x - player.position.x) < (1.6 if magnet_time > 0.0 else 0.58)
		var near_z: bool = abs(node.position.z - PLAYER_Z) < (2.2 if magnet_time > 0.0 else 0.72)
		var near_y: bool = abs(node.position.y - (jump_y + 0.95)) < 1.25
		if near_lane and near_z and near_y:
			coin_count += 1
			_play_sfx("coin.wav", rng.randf_range(1.0, 1.16))
			_flash(Color(1.0, 0.82, 0.22, 0.12))
			node.queue_free()
			coins_world.remove_at(i)
			continue
		if node.position.z > 10.0:
			node.queue_free()
			coins_world.remove_at(i)

func _spawn_powerup() -> void:
	var l := rng.randi_range(0, 2)
	var type := 0 if rng.randf() < 0.58 else 1
	var root := Node3D.new()
	root.position = Vector3(LANES[l], 1.0, -62.0)
	coin_root.add_child(root)
	var orb := _sphere(0.34, mat_neon_cyan if type == 0 else mat_neon_pink)
	root.add_child(orb)
	var ring := _cylinder(0.48, 0.48, 0.055, mat_gold)
	ring.rotation_degrees.x = 90.0
	root.add_child(ring)
	powerups.append({"node": root, "lane": l, "type": type})

func _move_powerups(delta: float) -> void:
	for i in range(powerups.size() - 1, -1, -1):
		var p = powerups[i]
		var node := p["node"] as Node3D
		node.position.z += speed * delta
		node.rotation.y += delta * 2.4
		node.position.y = 1.0 + sin(run_time * 4.0 + float(i)) * 0.10
		if abs(node.position.z - PLAYER_Z) < 0.85 and abs(node.position.x - player.position.x) < 0.70:
			if int(p["type"]) == 0:
				magnet_time = 7.5
			else:
				shield_time = 8.0
			_play_sfx("power.wav", 1.0)
			_flash(Color(0.35, 0.9, 1.0, 0.20))
			node.queue_free()
			powerups.remove_at(i)
			continue
		if node.position.z > 10.0:
			node.queue_free()
			powerups.remove_at(i)

func _lane_left() -> void:
	if not started or game_over:
		return
	if lane > 0:
		lane -= 1
		_play_sfx("swipe.wav", 0.95)
		if visual:
			visual.rotation.z = 0.08

func _lane_right() -> void:
	if not started or game_over:
		return
	if lane < 2:
		lane += 1
		_play_sfx("swipe.wav", 1.05)
		if visual:
			visual.rotation.z = -0.08

func _jump() -> void:
	if not started or game_over:
		return
	if jump_y <= 0.02 and slide_time <= 0.0:
		jump_v = 8.2
		_play_anim("Jump", 0.06, 1.12)
		_play_sfx("jump.wav", 1.0)

func _slide() -> void:
	if not started or game_over:
		return
	if jump_y <= 0.06:
		slide_time = 0.78
		_play_anim("Duck", 0.06, 1.15)
		_play_sfx("swipe.wav", 0.82)

func _update_character_fx(delta: float) -> void:
	if visual:
		visual.rotation.z = lerpf(visual.rotation.z, 0.0, min(1.0, delta * 8.0))
		var tail := visual.find_child("CustomTail", true, false)
		if tail is Node3D:
			(tail as Node3D).rotation.y = sin(run_time * 7.0) * 0.12
			(tail as Node3D).rotation.z = sin(run_time * 4.0) * 0.10
	if anim_player and state_anim == "Run":
		anim_player.speed_scale = 1.0 + (speed - 10.0) * 0.025

func _setup_speed_lines() -> void:
	for i in range(18):
		var streak := _box(Vector3(0.025, 0.025, rng.randf_range(0.8, 1.8)), mat_neon_cyan if i % 2 == 0 else mat_neon_pink)
		var side := -1.0 if i % 2 == 0 else 1.0
		streak.position = Vector3(side * rng.randf_range(4.6, 7.8), rng.randf_range(0.35, 3.5), rng.randf_range(-40.0, 6.0))
		streak.visible = false
		speed_root.add_child(streak)
		streaks.append(streak)

func _move_speed_lines(delta: float) -> void:
	var active := speed > 14.0 and started and not game_over
	for s in streaks:
		s.visible = active
		if not active:
			continue
		s.position.z += speed * delta * 2.1
		if s.position.z > 8.0:
			var side := -1.0 if s.position.x < 0.0 else 1.0
			s.position = Vector3(side * rng.randf_range(4.6, 8.0), rng.randf_range(0.30, 3.8), rng.randf_range(-46.0, -22.0))

func _update_camera(delta: float) -> void:
	if not camera or not player:
		return
	var desired_x := player.position.x * 0.27
	var desired_y := 3.45 + jump_y * 0.10
	var desired_z := 8.9
	camera.position.x = lerpf(camera.position.x, desired_x, min(1.0, delta * 4.2))
	camera.position.y = lerpf(camera.position.y, desired_y, min(1.0, delta * 4.0))
	camera.position.z = lerpf(camera.position.z, desired_z, min(1.0, delta * 4.0))
	var target_fov: float = 62.0 + clamp((speed - 10.0) * 0.78, 0.0, 10.0)
	camera.fov = lerpf(camera.fov, target_fov, min(1.0, delta * 2.8))

	var sx := 0.0
	var sy := 0.0
	if shake > 0.0:
		shake = max(0.0, shake - delta * 1.55)
		sx = rng.randf_range(-shake, shake)
		sy = rng.randf_range(-shake, shake)
	camera.position.x += sx
	camera.position.y += sy
	camera.look_at(Vector3(player.position.x * 0.12, 1.25 + jump_y * 0.15, -6.8), Vector3.UP)

func _setup_ui() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	var top := ColorRect.new()
	top.color = Color(0.035, 0.025, 0.07, 0.62)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 112.0
	hud_layer.add_child(top)

	score_label = _ui_label("SCORE  0", 30, Color.WHITE)
	score_label.position = Vector2(28, 18)
	hud_layer.add_child(score_label)
	coin_label = _ui_label("COINS  0", 23, Color("#ffd560"))
	coin_label.position = Vector2(28, 59)
	hud_layer.add_child(coin_label)
	speed_label = _ui_label("x1.0", 22, Color("#6fe9ff"))
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	speed_label.offset_left = -215
	speed_label.offset_right = -25
	speed_label.offset_top = 20
	speed_label.offset_bottom = 55
	hud_layer.add_child(speed_label)
	best_label = _ui_label("BEST  0", 18, Color("#ff8cca"))
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	best_label.offset_left = -255
	best_label.offset_right = -25
	best_label.offset_top = 61
	best_label.offset_bottom = 92
	hud_layer.add_child(best_label)

	shield_label = _ui_label("SHIELD", 18, Color("#76efff"))
	shield_label.position = Vector2(28, 126)
	shield_label.visible = false
	hud_layer.add_child(shield_label)
	magnet_label = _ui_label("MAGNET", 18, Color("#ff83ce"))
	magnet_label.position = Vector2(28, 153)
	magnet_label.visible = false
	hud_layer.add_child(magnet_label)

	start_panel = _make_center_panel()
	hud_layer.add_child(start_panel)
	var title := _ui_label("NEON PANTHER\nRUSH PRO", 50, Color("#ff63ba"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-360, -220)
	title.size = Vector2(720, 130)
	start_panel.add_child(title)
	var sub := _ui_label("COMMERCIAL-STYLE 3D RUNNER", 20, Color("#f5f2ff"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(-330, -82)
	sub.size = Vector2(660, 44)
	start_panel.add_child(sub)
	var controls := _ui_label("SWIPE  ← →  CHANGE LANE\nSWIPE  ↑  JUMP     ↓  SLIDE\n\nCOLLECT COINS • DODGE TRAFFIC", 20, Color("#d8d6e5"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.position = Vector2(-365, 20)
	controls.size = Vector2(730, 160)
	start_panel.add_child(controls)
	var tap := _ui_label("TAP TO RUN", 31, Color("#ffd05a"))
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.position = Vector2(-260, 210)
	tap.size = Vector2(520, 60)
	start_panel.add_child(tap)

	over_panel = _make_center_panel()
	over_panel.visible = false
	hud_layer.add_child(over_panel)
	var caught := _ui_label("BUSTED!", 56, Color("#ff536e"))
	caught.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caught.position = Vector2(-300, -180)
	caught.size = Vector2(600, 80)
	over_panel.add_child(caught)
	over_score = _ui_label("", 26, Color.WHITE)
	over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_score.position = Vector2(-300, -45)
	over_score.size = Vector2(600, 150)
	over_panel.add_child(over_score)
	var again := _ui_label("TAP TO RUN AGAIN", 29, Color("#ff72c3"))
	again.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	again.position = Vector2(-300, 165)
	again.size = Vector2(600, 60)
	over_panel.add_child(again)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1,1,1,0)
	hud_layer.add_child(flash_rect)

func _make_center_panel() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.position = Vector2.ZERO
	return c

func _ui_label(text_value: String, size_value: int, color_value: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_color_override("font_color", color_value)
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.55))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.04,0.025,0.07,0.75))
	return l

func _update_hud() -> void:
	if not score_label:
		return
	score_label.text = "SCORE  %d" % score
	coin_label.text = "COINS  %d" % coin_count
	speed_label.text = "SPEED  %.1fx" % (speed / 10.0)
	best_label.text = "BEST  %d" % best_score
	shield_label.visible = shield_time > 0.0
	magnet_label.visible = magnet_time > 0.0
	if shield_time > 0.0:
		shield_label.text = "SHIELD  %.1fs" % shield_time
	if magnet_time > 0.0:
		magnet_label.text = "MAGNET  %.1fs" % magnet_time

func _flash(color: Color) -> void:
	if flash_rect:
		flash_rect.color = color

func _update_ui_fx(delta: float) -> void:
	if flash_rect and flash_rect.color.a > 0.002:
		var c := flash_rect.color
		c.a = max(0.0, c.a - delta * 1.6)
		flash_rect.color = c

func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -13.0
	add_child(music)
	if ResourceLoader.exists("res://generated/music.wav"):
		var stream = load("res://generated/music.wav")
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.stream = stream
		music.play()

	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -3.0
	add_child(sfx)

func _play_sfx(file: String, pitch := 1.0) -> void:
	if not sfx:
		return
	var path := "res://generated/" + file
	if ResourceLoader.exists(path):
		sfx.stream = load(path)
		sfx.pitch_scale = pitch
		sfx.play()

func _restart() -> void:
	for o in obstacles:
		if is_instance_valid(o["node"]):
			(o["node"] as Node3D).queue_free()
	obstacles.clear()
	for c in coins_world:
		if is_instance_valid(c["node"]):
			(c["node"] as Node3D).queue_free()
	coins_world.clear()
	for p in powerups:
		if is_instance_valid(p["node"]):
			(p["node"] as Node3D).queue_free()
	powerups.clear()

	lane = 1
	player.position = Vector3(0.0, 0.0, PLAYER_Z)
	jump_y = 0.0
	jump_v = 0.0
	slide_time = 0.0
	magnet_time = 0.0
	shield_time = 0.0
	speed = 10.0
	distance = 0.0
	score = 0
	coin_count = 0
	spawn_timer = 0.85
	coin_timer = 0.35
	power_timer = 8.5
	game_over = false
	started = true
	over_panel.visible = false
	start_panel.visible = false
	_play_anim("Run", 0.10, 1.0)
	_update_hud()

func _load_best() -> void:
	if FileAccess.file_exists("user://runner.save"):
		var f := FileAccess.open("user://runner.save", FileAccess.READ)
		if f:
			best_score = int(f.get_as_text())

func _save_best() -> void:
	var f := FileAccess.open("user://runner.save", FileAccess.WRITE)
	if f:
		f.store_string(str(best_score))

# ---------- mesh helpers ----------

func _box(half_extents: Vector3, material: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = half_extents * 2.0
	var n := MeshInstance3D.new()
	n.mesh = m
	n.material_override = material
	return n

func _sphere(radius: float, material: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 20
	m.rings = 12
	var n := MeshInstance3D.new()
	n.mesh = m
	n.material_override = material
	return n

func _capsule(radius: float, height: float, material: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = max(height, radius * 2.05)
	m.radial_segments = 16
	m.rings = 8
	var n := MeshInstance3D.new()
	n.mesh = m
	n.material_override = material
	return n

func _cylinder(top_radius: float, bottom_radius: float, height: float, material: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = 18
	var n := MeshInstance3D.new()
	n.mesh = m
	n.material_override = material
	return n
