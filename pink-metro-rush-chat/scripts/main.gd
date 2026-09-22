extends Node3D

# Pink Metro Rush — rail-based endless runner.
# The runtime is assembled from CC0 authored assets plus original game logic and pink-feline styling.

const LANE_X = [-2.65, 0.0, 2.65]
const PLAYER_Z: float = 1.2
const CHUNK_LEN: float = 18.0
const CHUNK_COUNT: int = 15
const TRAIN_ROOF_Y: float = 2.18

var rng := RandomNumberGenerator.new()

# Scene roots
var world_root: Node3D
var chunk_root: Node3D
var traffic_root: Node3D
var pickup_root: Node3D
var fx_root: Node3D
var player: Node3D
var visual: Node3D
var anim_player: AnimationPlayer
var camera: Camera3D
var tail_root: Node3D
var board_visual: Node3D
var intro_guard: Node3D

# Imported authored assets
var runner_scene: PackedScene
var train_scenes: Array[PackedScene] = []
var rail_scene: PackedScene
var building_scenes: Array[PackedScene] = []
var lamp_scene: PackedScene
var barrier_scene: PackedScene

# Runtime objects
var chunks: Array[Node3D] = []
var trains: Array = []
var hazards: Array = []
var coins_world: Array = []
var powerups: Array = []
var particles: Array = []
var speed_lines: Array[Node3D] = []

# Gameplay
var lane: int = 1
var surface_y: float = 0.0
var jump_offset: float = 0.0
var jump_v: float = 0.0
var slide_time: float = 0.0
var magnet_time: float = 0.0
var shield_time: float = 0.0
var shoes_time: float = 0.0
var x2_time: float = 0.0
var speed: float = 11.2
var distance: float = 0.0
var score: int = 0
var run_coins: int = 0
var total_coins: int = 0
var best_score: int = 0
var multiplier: int = 1
var started: bool = false
var game_over: bool = false
var is_paused: bool = false
var revive_used: bool = false
var spawn_timer: float = 0.7
var coin_timer: float = 0.35
var power_timer: float = 8.0
var run_time: float = 0.0
var shake: float = 0.0
var intro_time: float = 0.0
var mission_target: int = 30
var mission_done: bool = false

# Touch
var touch_start := Vector2.ZERO
var touch_active: bool = false

# UI
var ui: CanvasLayer
var score_label: Label
var coins_label: Label
var multi_label: Label
var best_label: Label
var mission_label: Label
var power_label: Label
var start_panel: Control
var gameover_panel: Control
var gameover_score: Label
var pause_panel: Control
var flash_rect: ColorRect
var pause_button: Button
var revive_button: Button

# Audio
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var train_sfx: AudioStreamPlayer

# Materials
var mat_ballast: StandardMaterial3D
var mat_rail: StandardMaterial3D
var mat_sleeper: StandardMaterial3D
var mat_platform: StandardMaterial3D
var mat_pink: StandardMaterial3D
var mat_pink_dark: StandardMaterial3D
var mat_pink_light: StandardMaterial3D
var mat_purple: StandardMaterial3D
var mat_gold: StandardMaterial3D
var mat_black: StandardMaterial3D
var mat_white: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_green: StandardMaterial3D
var mat_cyan: StandardMaterial3D
var mat_neon_pink: StandardMaterial3D
var mat_neon_cyan: StandardMaterial3D

func _ready() -> void:
	rng.seed = 774300
	_make_materials()
	_setup_environment()
	_setup_roots()
	_load_assets()
	_setup_player()
	_setup_camera()
	_setup_world()
	_setup_speed_lines()
	_setup_ui()
	_setup_audio()
	_load_save()
	_setup_intro_guard()
	_update_hud()

func _process(delta: float) -> void:
	if is_paused:
		_update_camera(delta)
		return

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
		_update_idle(delta)

	_update_camera(delta)
	_update_ui_fx(delta)

func _input(event: InputEvent) -> void:
	if is_paused:
		return
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

func _handle_swipe(d: Vector2) -> void:
	if game_over:
		return
	if not started:
		_start_run()
		return
	if d.length() < 55.0:
		_jump()
		return
	if abs(d.x) > abs(d.y):
		if d.x < 0.0:
			_lane_left()
		else:
			_lane_right()
	else:
		if d.y < 0.0:
			_jump()
		else:
			_slide()

# -------------------------------------------------------------------
# GAME LOOP

func _update_game(delta: float) -> void:
	run_time += delta
	intro_time += delta
	distance += speed * delta
	speed = min(25.0, 11.2 + distance * 0.0058)
	multiplier = min(8, 1 + int(distance / 430.0))
	var effective_multi: int = multiplier * (2 if x2_time > 0.0 else 1)
	score += int(speed * delta * 8.5 * float(effective_multi))

	player.position.x = lerpf(player.position.x, float(LANE_X[lane]), min(1.0, delta * 14.0))

	_update_vertical(delta)
	_update_chunks(delta)
	_update_trains(delta)
	_update_hazards(delta)
	_update_coins(delta)
	_update_powerups(delta)
	_update_powers(delta)
	_update_speed_lines(delta)
	_update_intro(delta)
	_update_character_fx(delta)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = max(0.62, 1.28 - (speed - 11.2) * 0.038)
		_spawn_pattern()

	coin_timer -= delta
	if coin_timer <= 0.0:
		coin_timer = rng.randf_range(0.62, 0.95)
		_spawn_coin_pattern()

	power_timer -= delta
	if power_timer <= 0.0:
		power_timer = rng.randf_range(10.0, 15.0)
		_spawn_powerup()

	if not mission_done and run_coins >= mission_target:
		mission_done = true
		score += 3000
		_flash(Color(1.0, 0.45, 0.78, 0.24))
		_play_sfx("power.wav", 1.15)

	_update_hud()

func _update_vertical(delta: float) -> void:
	var roof: float = _roof_under_player()

	if jump_offset > 0.0 or jump_v > 0.0:
		jump_v -= (17.2 if shoes_time > 0.0 else 21.0) * delta
		jump_offset += jump_v * delta
		if jump_offset <= 0.0:
			jump_offset = 0.0
			jump_v = 0.0

	if roof >= 0.0:
		var absolute_y: float = surface_y + jump_offset
		if surface_y > 1.0:
			surface_y = roof
		elif absolute_y >= roof - 0.20 and jump_v <= 0.0:
			jump_offset = max(0.0, absolute_y - roof)
			surface_y = roof
			if jump_offset < 0.08:
				jump_offset = 0.0
				_play_run()
	else:
		if surface_y > 0.0:
			surface_y = max(0.0, surface_y - delta * 9.5)

	player.position.y = surface_y + jump_offset

	if slide_time > 0.0:
		slide_time -= delta
		if slide_time <= 0.0:
			_play_run()

func _roof_under_player() -> float:
	for t in trains:
		var node: Node3D = t["node"]
		if not is_instance_valid(node):
			continue
		if int(t["lane"]) != lane:
			continue
		var half_len: float = float(t["half_len"])
		if abs(node.position.z - PLAYER_Z) <= half_len - 0.25:
			var current_y: float = surface_y + jump_offset
			if current_y >= float(t["roof"]) - 0.32:
				return float(t["roof"])
	return -1.0

func _update_idle(delta: float) -> void:
	run_time += delta
	_update_speed_lines(delta * 0.22)
	if not started and not game_over and player:
		player.position.y = sin(run_time * 2.0) * 0.025
		if visual:
			visual.rotation.y = lerpf(visual.rotation.y, deg_to_rad(180.0), delta * 2.0)

# -------------------------------------------------------------------
# MATERIALS / WORLD

func _make_materials() -> void:
	mat_ballast = _mat(Color("#8e716f"), 0.96)
	mat_rail = _mat(Color("#727985"), 0.18, 0.82)
	mat_sleeper = _mat(Color("#68452f"), 0.92)
	mat_platform = _mat(Color("#e4c5d8"), 0.82)
	mat_pink = _mat(Color("#ff5fb5"), 0.42)
	mat_pink_dark = _mat(Color("#c92770"), 0.38)
	mat_pink_light = _mat(Color("#ffb8df"), 0.58)
	mat_purple = _mat(Color("#6c4fa5"), 0.44)
	mat_gold = _mat(Color("#ffc52f"), 0.24, 0.68)
	mat_black = _mat(Color("#17131d"), 0.30, 0.18)
	mat_white = _mat(Color("#fff4f5"), 0.68)
	mat_glass = _mat(Color("#17304a"), 0.10, 0.48)
	mat_green = _mat(Color("#78bf55"), 0.78)
	mat_cyan = _mat(Color("#5ee7f4"), 0.34, 0.10)
	mat_neon_pink = _emissive(Color("#ff3aa4"), 3.0)
	mat_neon_cyan = _emissive(Color("#32e8ff"), 2.5)

func _mat(c: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	return m

func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(c, 0.28, 0.12)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#42b8ff")
	sky_mat.sky_horizon_color = Color("#ffd2df")
	sky_mat.ground_horizon_color = Color("#f1b4cc")
	sky_mat.ground_bottom_color = Color("#8b6689")
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.12
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.88
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.04
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.28
	env.fog_enabled = true
	env.fog_light_color = Color("#f0d8e8")
	env.fog_light_energy = 0.72
	env.fog_density = 0.0055
	env.fog_sky_affect = 0.15
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-51.0, -28.0, 0.0)
	sun.light_color = Color("#fff1d2")
	sun.light_energy = 1.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95.0
	add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
	rim.light_color = Color("#ff9ed1")
	rim.light_energy = 0.32
	add_child(rim)

func _setup_roots() -> void:
	world_root = Node3D.new()
	world_root.name = "RailWorld"
	add_child(world_root)
	chunk_root = Node3D.new()
	chunk_root.name = "Chunks"
	world_root.add_child(chunk_root)
	traffic_root = Node3D.new()
	traffic_root.name = "TrainsAndHazards"
	world_root.add_child(traffic_root)
	pickup_root = Node3D.new()
	pickup_root.name = "Pickups"
	world_root.add_child(pickup_root)
	fx_root = Node3D.new()
	fx_root.name = "FX"
	add_child(fx_root)

func _load_assets() -> void:
	if ResourceLoader.exists("res://assets/runner/Rogue.glb"):
		var rr = load("res://assets/runner/Rogue.glb")
		if rr is PackedScene:
			runner_scene = rr

	for p in [
		"res://assets/trains/train-electric-subway-a.glb",
		"res://assets/trains/train-electric-subway-b.glb",
		"res://assets/trains/train-electric-city-a.glb",
		"res://assets/trains/train-electric-city-b.glb",
		"res://assets/trains/train-electric-bullet-a.glb"
	]:
		if ResourceLoader.exists(p):
			var s = load(p)
			if s is PackedScene:
				train_scenes.append(s)

	if ResourceLoader.exists("res://assets/trains/railroad-straight.glb"):
		var rs = load("res://assets/trains/railroad-straight.glb")
		if rs is PackedScene:
			rail_scene = rs

	for p in [
		"res://assets/city/building-a.glb",
		"res://assets/city/building-b.glb",
		"res://assets/city/building-c.glb",
		"res://assets/city/building-d.glb",
		"res://assets/city/building-e.glb",
		"res://assets/city/building-f.glb"
	]:
		if ResourceLoader.exists(p):
			var bs = load(p)
			if bs is PackedScene:
				building_scenes.append(bs)

	if ResourceLoader.exists("res://assets/city/streetlight.glb"):
		var ls = load("res://assets/city/streetlight.glb")
		if ls is PackedScene:
			lamp_scene = ls
	if ResourceLoader.exists("res://assets/city/barrier.glb"):
		var br = load("res://assets/city/barrier.glb")
		if br is PackedScene:
			barrier_scene = br

# -------------------------------------------------------------------
# PLAYER / ANIMATION

func _setup_player() -> void:
	player = Node3D.new()
	player.name = "PinkFelineRunner"
	player.position = Vector3(0.0, 0.0, PLAYER_Z)
	add_child(player)

	if runner_scene:
		visual = runner_scene.instantiate()
		visual.name = "RiggedRunner"
		visual.rotation_degrees.y = 180.0
		visual.scale = Vector3.ONE * 1.02
		player.add_child(visual)
		anim_player = _find_anim_player(visual)
		_recolor_runner(visual)
	else:
		visual = _fallback_runner()
		player.add_child(visual)

	_add_panther_head()
	_add_tail()
	_add_board()
	_add_shadow()
	_play_anim(["idle"], 1.0)

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for child in n.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for child in n.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _recolor_runner(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var base := mi.get_active_material(i)
				if base is StandardMaterial3D:
					var d := base.duplicate() as StandardMaterial3D
					var original := d.albedo_color
					var target := Color("#ff5cae") if i % 3 != 1 else Color("#355b8b")
					d.albedo_color = original.lerp(target, 0.58)
					d.roughness = clamp(d.roughness, 0.30, 0.78)
					mi.set_surface_override_material(i, d)
	for child in n.get_children():
		_recolor_runner(child)

func _add_panther_head() -> void:
	var attach_parent: Node3D = player
	var skeleton: Skeleton3D = null
	if visual:
		skeleton = _find_skeleton(visual)
	if skeleton:
		for i in range(skeleton.get_bone_count()):
			var bn := String(skeleton.get_bone_name(i)).to_lower()
			if "head" in bn:
				var ba := BoneAttachment3D.new()
				ba.bone_name = skeleton.get_bone_name(i)
				skeleton.add_child(ba)
				attach_parent = ba
				break

	var head_root := Node3D.new()
	head_root.name = "FelineHead"
	attach_parent.add_child(head_root)
	if attach_parent == player:
		head_root.position = Vector3(0.0, 1.72, 0.0)
	else:
		head_root.position = Vector3(0.0, 0.04, -0.02)

	var head := _sphere(0.37, mat_pink)
	head.scale = Vector3(0.92, 1.05, 0.94)
	head_root.add_child(head)

	for side in [-1.0, 1.0]:
		var ear := _sphere(0.15, mat_pink)
		ear.scale = Vector3(0.75, 1.28, 0.45)
		ear.position = Vector3(side * 0.27, 0.29, 0.0)
		ear.rotation_degrees.z = side * 17.0
		head_root.add_child(ear)

		var muzzle := _sphere(0.18, _mat(Color("#ffe0c0"), 0.72))
		muzzle.scale = Vector3(0.95, 0.72, 0.72)
		muzzle.position = Vector3(side * 0.11, -0.10, -0.30)
		head_root.add_child(muzzle)

	var nose := _sphere(0.085, mat_pink_dark)
	nose.scale = Vector3(1.15, 0.75, 0.72)
	nose.position = Vector3(0.0, -0.055, -0.43)
	head_root.add_child(nose)

	for side in [-1.0, 1.0]:
		var lens := _box(Vector3(0.18, 0.105, 0.035), mat_black)
		lens.position = Vector3(side * 0.19, 0.08, -0.355)
		lens.rotation_degrees.z = side * 5.0
		head_root.add_child(lens)
		var shine := _box(Vector3(0.055, 0.012, 0.008), mat_cyan)
		shine.position = Vector3(side * 0.21 - side * 0.03, 0.11, -0.395)
		head_root.add_child(shine)

	var bridge := _box(Vector3(0.055, 0.018, 0.025), mat_black)
	bridge.position = Vector3(0.0, 0.08, -0.37)
	head_root.add_child(bridge)

	var cap := _cylinder(0.285, 0.285, 0.10, mat_pink_dark)
	cap.position = Vector3(0.0, 0.37, 0.015)
	head_root.add_child(cap)
	var brim := _box(Vector3(0.24, 0.035, 0.15), mat_black)
	brim.position = Vector3(0.0, 0.38, 0.21)
	head_root.add_child(brim)

func _add_tail() -> void:
	tail_root = Node3D.new()
	tail_root.name = "LongFelineTail"
	tail_root.position = Vector3(0.18, 0.86, 0.20)
	player.add_child(tail_root)
	for i in range(17):
		var t: float = float(i) / 16.0
		var radius: float = 0.085 - t * 0.035
		var seg := _capsule(radius, 0.20, mat_pink)
		var a: float = t * 4.0
		seg.position = Vector3(0.13 + sin(a) * 0.30, 0.02 + t * 0.38 + sin(t * PI) * 0.18, t * 0.94)
		seg.rotation_degrees = Vector3(72.0, sin(a) * 24.0, cos(a) * 8.0)
		tail_root.add_child(seg)

func _add_board() -> void:
	board_visual = Node3D.new()
	board_visual.name = "ShieldBoard"
	board_visual.visible = false
	board_visual.position = Vector3(0.0, 0.08, 0.0)
	player.add_child(board_visual)
	var deck := _box(Vector3(0.46, 0.055, 0.78), mat_neon_pink)
	deck.rotation_degrees.x = 0.0
	board_visual.add_child(deck)
	for z in [-0.52, 0.52]:
		for x in [-0.35, 0.35]:
			var wheel := _sphere(0.09, mat_gold)
			wheel.position = Vector3(x, -0.08, z)
			board_visual.add_child(wheel)

func _add_shadow() -> void:
	var shadow := _sphere(0.65, _alpha_mat(Color(0.02, 0.01, 0.03, 0.34)))
	shadow.scale = Vector3(1.0, 0.045, 0.62)
	shadow.position = Vector3(0.0, 0.035, 0.0)
	player.add_child(shadow)

func _play_anim(patterns: Array, rate: float = 1.0, blend: float = 0.12) -> void:
	if not anim_player:
		return
	var chosen := ""
	for name in anim_player.get_animation_list():
		var low := String(name).to_lower()
		for p in patterns:
			var wanted := String(p).to_lower()
			if low == wanted or wanted in low:
				chosen = String(name)
				break
		if chosen != "":
			break
	if chosen != "":
		anim_player.play(chosen, blend, rate)

func _play_run() -> void:
	_play_anim(["running", "run"], 1.0 + (speed - 11.2) * 0.022, 0.10)

func _update_character_fx(delta: float) -> void:
	if tail_root:
		tail_root.rotation.y = sin(run_time * 7.8) * 0.15
		tail_root.rotation.z = sin(run_time * 4.3) * 0.09
	if visual:
		visual.rotation.z = lerpf(visual.rotation.z, 0.0, min(1.0, delta * 8.0))
	board_visual.visible = shield_time > 0.0

# -------------------------------------------------------------------
# CAMERA

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "RunnerCamera"
	camera.position = Vector3(0.0, 3.4, 9.15)
	camera.fov = 60.0
	camera.near = 0.07
	camera.far = 190.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.1, -8.0), Vector3.UP)

func _update_camera(delta: float) -> void:
	if not camera or not player:
		return
	var target_x: float = player.position.x * 0.24
	var target_y: float = 3.42 + player.position.y * 0.09
	camera.position.x = lerpf(camera.position.x, target_x, min(1.0, delta * 4.5))
	camera.position.y = lerpf(camera.position.y, target_y, min(1.0, delta * 4.0))
	var target_fov: float = 60.0 + clamp((speed - 11.2) * 0.76, 0.0, 11.0)
	camera.fov = lerpf(camera.fov, target_fov, min(1.0, delta * 2.6))
	if shake > 0.0:
		shake = max(0.0, shake - delta * 1.7)
		camera.position.x += rng.randf_range(-shake, shake)
		camera.position.y += rng.randf_range(-shake, shake)
	camera.look_at(Vector3(player.position.x * 0.10, 1.20 + player.position.y * 0.12, -7.8), Vector3.UP)

# -------------------------------------------------------------------
# RAIL WORLD / CHUNKS

func _setup_world() -> void:
	for i in range(CHUNK_COUNT):
		var chunk := _make_chunk(i)
		chunk.position.z = 7.0 - float(i) * CHUNK_LEN
		chunk_root.add_child(chunk)
		chunks.append(chunk)

func _make_chunk(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "RailChunk_%02d" % index

	# Track bed and three lanes.
	var bed := _box(Vector3(5.3, 0.12, CHUNK_LEN * 0.5), mat_ballast)
	bed.position.y = -0.14
	root.add_child(bed)

	for lane_i in range(3):
		var x: float = float(LANE_X[lane_i])
		_add_track(root, x)
	
	# Side platforms / service walkways.
	for side in [-1.0, 1.0]:
		var platform := _box(Vector3(1.15, 0.20, CHUNK_LEN * 0.5), mat_platform)
		platform.position = Vector3(side * 6.15, 0.08, 0.0)
		root.add_child(platform)
		var edge := _box(Vector3(0.10, 0.08, CHUNK_LEN * 0.5), mat_neon_pink)
		edge.position = Vector3(side * 5.08, 0.28, 0.0)
		root.add_child(edge)

	_add_gantry(root, -5.5)
	if index % 2 == 0:
		_add_gantry(root, 5.5)
	_add_city_scenery(root, index)
	return root

func _add_track(parent: Node3D, x: float) -> void:
	# Authored rail model if available; procedural rail stays underneath so collision/readability is deterministic.
	if rail_scene:
		var authored := rail_scene.instantiate() as Node3D
		authored.position = Vector3(x, 0.0, 0.0)
		authored.scale = Vector3.ONE * 1.15
		parent.add_child(authored)

	for rail_x in [-0.48, 0.48]:
		var rail := _box(Vector3(0.055, 0.065, CHUNK_LEN * 0.5), mat_rail)
		rail.position = Vector3(x + rail_x, 0.08, 0.0)
		parent.add_child(rail)
	for i in range(20):
		var sleeper := _box(Vector3(0.74, 0.045, 0.12), mat_sleeper)
		sleeper.position = Vector3(x, 0.015, -8.3 + float(i) * 0.88)
		parent.add_child(sleeper)

func _add_gantry(parent: Node3D, z: float) -> void:
	for side in [-1.0, 1.0]:
		var pole := _box(Vector3(0.085, 2.75, 0.085), mat_black)
		pole.position = Vector3(side * 5.15, 2.72, z)
		parent.add_child(pole)
	var top := _box(Vector3(5.25, 0.085, 0.085), mat_black)
	top.position = Vector3(0.0, 5.42, z)
	parent.add_child(top)
	for x in [-2.65, 0.0, 2.65]:
		var hanger := _box(Vector3(0.025, 0.42, 0.025), mat_black)
		hanger.position = Vector3(x, 4.94, z)
		parent.add_child(hanger)
		var wire := _box(Vector3(0.025, 0.025, CHUNK_LEN * 0.46), mat_black)
		wire.position = Vector3(x, 4.55, 0.0)
		parent.add_child(wire)

func _add_city_scenery(root: Node3D, index: int) -> void:
	for side in [-1.0, 1.0]:
		for slot in range(2):
			var z: float = -4.2 + float(slot) * 8.4 + rng.randf_range(-1.0, 1.0)
			if building_scenes.size() > 0:
				var scene := building_scenes[(index * 2 + slot + (1 if side > 0 else 0)) % building_scenes.size()]
				var building := scene.instantiate() as Node3D
				building.position = Vector3(side * rng.randf_range(8.2, 10.0), 0.0, z)
				building.scale = Vector3.ONE * rng.randf_range(2.0, 2.65)
				building.rotation_degrees.y = -90.0 if side < 0 else 90.0
				root.add_child(building)
			else:
				root.add_child(_fallback_building(index + slot, side, z))

			var sign := _box(Vector3(0.10, 0.42, 0.86), mat_neon_pink if (index + slot) % 2 == 0 else mat_neon_cyan)
			sign.position = Vector3(side * 6.9, 2.15 + slot * 0.25, z + 1.0)
			root.add_child(sign)

		if index % 2 == 0:
			if lamp_scene:
				var lamp := lamp_scene.instantiate() as Node3D
				lamp.position = Vector3(side * 5.85, 0.18, 2.5)
				lamp.scale = Vector3.ONE * 1.35
				lamp.rotation_degrees.y = 180.0 if side < 0 else 0.0
				root.add_child(lamp)
			else:
				_add_lamp(root, side * 5.8, 2.5)

		if index % 3 != 2:
			_add_tree(root, Vector3(side * 6.4, 0.24, -4.8))

	# Tunnel/bridge-like arch every few chunks.
	if index % 7 == 5:
		for side in [-1.0, 1.0]:
			var pier := _box(Vector3(0.75, 3.4, 1.0), mat_pink_dark)
			pier.position = Vector3(side * 5.0, 3.35, 0.0)
			root.add_child(pier)
		var bridge := _box(Vector3(5.75, 0.55, 1.0), mat_pink_dark)
		bridge.position = Vector3(0.0, 6.25, 0.0)
		root.add_child(bridge)
		var stripe := _box(Vector3(5.3, 0.07, 1.03), mat_neon_pink)
		stripe.position = Vector3(0.0, 5.80, -0.02)
		root.add_child(stripe)

func _fallback_building(index: int, side: float, z: float) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(side * 9.0, 0.0, z)
	var colors := [Color("#f27ea8"), Color("#ffb45f"), Color("#55b8ca"), Color("#8a69c8"), Color("#ef6f65")]
	var h: float = 5.0 + float(index % 4) * 1.4
	var body := _box(Vector3(2.15, h * 0.5, 2.7), _mat(colors[index % colors.size()], 0.72))
	body.position.y = h * 0.5
	n.add_child(body)
	for floor in range(1, int(h / 1.25)):
		for col in range(3):
			var w := _box(Vector3(0.03, 0.27, 0.31), mat_glass)
			w.position = Vector3(-side * 2.18, float(floor) * 1.18, -1.5 + col * 1.5)
			n.add_child(w)
	return n

func _add_tree(parent: Node3D, pos: Vector3) -> void:
	var trunk := _cylinder(0.12, 0.15, 1.55, _mat(Color("#7a4f39"), 0.9))
	trunk.position = pos + Vector3(0.0, 0.78, 0.0)
	parent.add_child(trunk)
	var crown := _sphere(0.72, mat_green)
	crown.scale = Vector3(0.92, 1.18, 0.92)
	crown.position = pos + Vector3(0.0, 1.92, 0.0)
	parent.add_child(crown)

func _add_lamp(parent: Node3D, x: float, z: float) -> void:
	var p := _cylinder(0.045, 0.055, 2.8, mat_black)
	p.position = Vector3(x, 1.4, z)
	parent.add_child(p)
	var b := _sphere(0.13, mat_neon_cyan)
	b.position = Vector3(x, 2.86, z)
	parent.add_child(b)

func _update_chunks(delta: float) -> void:
	for chunk in chunks:
		chunk.position.z += speed * delta
		if chunk.position.z > CHUNK_LEN + 7.0:
			chunk.position.z -= CHUNK_LEN * CHUNK_COUNT

# -------------------------------------------------------------------
# TRAINS / HAZARDS

func _spawn_pattern() -> void:
	var pattern: int = rng.randi_range(0, 6)
	if distance < 85.0:
		pattern = rng.randi_range(0, 2)

	match pattern:
		0:
			_spawn_train(rng.randi_range(0, 2), -72.0, false)
		1:
			var blocked: int = rng.randi_range(0, 2)
			_spawn_train(blocked, -76.0, rng.randf() < 0.25)
			var other: int = (blocked + rng.randi_range(1, 2)) % 3
			_spawn_barrier(other, -58.0, false)
		2:
			var free_lane: int = rng.randi_range(0, 2)
			for li in range(3):
				if li != free_lane:
					_spawn_train(li, -76.0 - float(li) * 2.0, li == (free_lane + 1) % 3)
		3:
			# Roof route: ramp then long train and roof coins.
			var roof_lane: int = rng.randi_range(0, 2)
			_spawn_ramp(roof_lane, -51.0)
			_spawn_train(roof_lane, -67.0, false, true)
			for i in range(10):
				_spawn_coin(roof_lane, -57.0 - float(i) * 2.0, TRAIN_ROOF_Y + 0.78)
		4:
			_spawn_overhead(rng.randi_range(0, 2), -57.0)
		5:
			var l: int = rng.randi_range(0, 2)
			_spawn_barrier(l, -56.0, true)
			var free2: int = (l + 1) % 3
			_spawn_train((l + 2) % 3, -73.0, true)
			for i in range(7):
				_spawn_coin(free2, -49.0 - float(i) * 2.15, 0.78)
		6:
			# Train corridor like the reference screenshots.
			var open_lane: int = rng.randi_range(0, 2)
			for li in range(3):
				if li != open_lane:
					_spawn_train(li, -72.0 - float(li) * 5.0, false, true)
			for i in range(8):
				_spawn_coin(open_lane, -49.0 - float(i) * 2.0, 0.82)

func _spawn_train(which_lane: int, z: float, moving_toward: bool, long_train: bool = false) -> void:
	var root := Node3D.new()
	root.name = "MetroTrain"
	root.position = Vector3(float(LANE_X[which_lane]), 0.0, z)
	traffic_root.add_child(root)

	var cars: int = 2 if long_train else 1
	for c in range(cars):
		var holder := Node3D.new()
		holder.position.z = -float(c) * 5.25
		root.add_child(holder)
		if train_scenes.size() > 0:
			var scene := train_scenes[rng.randi_range(0, train_scenes.size() - 1)]
			var model := scene.instantiate() as Node3D
			model.scale = Vector3.ONE * 1.42
			model.rotation_degrees.y = 0.0
			holder.add_child(model)
			_tint_train(model, c)
		else:
			_make_fallback_train(holder, c)

		# Pink belt line and safe/readable roof.
		var belt := _box(Vector3(1.02, 0.10, 2.42), mat_neon_pink)
		belt.position = Vector3(0.0, 0.78, 0.0)
		holder.add_child(belt)
		var roof_pad := _box(Vector3(0.93, 0.055, 2.35), mat_purple)
		roof_pad.position = Vector3(0.0, TRAIN_ROOF_Y - 0.05, 0.0)
		holder.add_child(roof_pad)

	var half_len: float = 2.55 + (5.25 if long_train else 0.0)
	trains.append({
		"node": root,
		"lane": which_lane,
		"half_len": half_len,
		"roof": TRAIN_ROOF_Y,
		"extra": 5.5 if moving_toward else 0.0,
		"horned": false
	})

func _tint_train(n: Node, variant: int) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var base := mi.get_active_material(i)
				if base is StandardMaterial3D:
					var d := base.duplicate() as StandardMaterial3D
					var tint := Color("#ff6fbf") if (i + variant) % 2 == 0 else Color("#9f71d1")
					d.albedo_color = d.albedo_color.lerp(tint, 0.34)
					d.roughness = clamp(d.roughness, 0.25, 0.70)
					mi.set_surface_override_material(i, d)
	for child in n.get_children():
		_tint_train(child, variant)

func _make_fallback_train(parent: Node3D, variant: int) -> void:
	var body := _box(Vector3(1.05, 0.82, 2.38), mat_pink if variant % 2 == 0 else mat_purple)
	body.position.y = 1.05
	parent.add_child(body)
	var front := _box(Vector3(0.78, 0.34, 0.03), mat_glass)
	front.position = Vector3(0.0, 1.25, -2.42)
	parent.add_child(front)
	for side in [-1.0, 1.0]:
		for i in range(4):
			var win := _box(Vector3(0.035, 0.27, 0.30), mat_glass)
			win.position = Vector3(side * 1.06, 1.18, -1.35 + float(i) * 0.88)
			parent.add_child(win)

func _spawn_barrier(which_lane: int, z: float, tall: bool) -> void:
	var root := Node3D.new()
	root.position = Vector3(float(LANE_X[which_lane]), 0.0, z)
	traffic_root.add_child(root)
	if barrier_scene:
		var b := barrier_scene.instantiate() as Node3D
		b.scale = Vector3.ONE * (2.0 if not tall else 2.35)
		b.rotation_degrees.y = 90.0
		root.add_child(b)
	else:
		var body := _box(Vector3(0.88, 0.42 if not tall else 0.62, 0.20), mat_pink_dark)
		body.position.y = 0.42 if not tall else 0.62
		root.add_child(body)
		for x in [-0.55, 0.0, 0.55]:
			var stripe := _box(Vector3(0.14, 0.44 if not tall else 0.62, 0.025), mat_white)
			stripe.position = Vector3(x, 0.44 if not tall else 0.62, -0.22)
			stripe.rotation_degrees.z = 25.0
			root.add_child(stripe)
	hazards.append({"node": root, "lane": which_lane, "type": "barrier", "height": 0.72 if not tall else 1.15})

func _spawn_overhead(which_lane: int, z: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(float(LANE_X[which_lane]), 0.0, z)
	traffic_root.add_child(root)
	for side in [-1.0, 1.0]:
		var pole := _box(Vector3(0.07, 1.18, 0.07), mat_black)
		pole.position = Vector3(side * 0.90, 1.18, 0.0)
		root.add_child(pole)
	var panel := _box(Vector3(1.02, 0.28, 0.16), mat_neon_pink)
	panel.position = Vector3(0.0, 2.05, 0.0)
	root.add_child(panel)
	hazards.append({"node": root, "lane": which_lane, "type": "overhead", "height": 0.0})

func _spawn_ramp(which_lane: int, z: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(float(LANE_X[which_lane]), 0.0, z)
	traffic_root.add_child(root)
	var ramp := _box(Vector3(0.92, 0.14, 2.20), mat_pink_dark)
	ramp.position = Vector3(0.0, 0.68, 0.0)
	ramp.rotation_degrees.x = -17.5
	root.add_child(ramp)
	var stripe := _box(Vector3(0.60, 0.035, 2.10), mat_neon_pink)
	stripe.position = Vector3(0.0, 0.86, -0.05)
	stripe.rotation_degrees.x = -17.5
	root.add_child(stripe)
	hazards.append({"node": root, "lane": which_lane, "type": "ramp", "height": 0.0})

func _update_trains(delta: float) -> void:
	for i in range(trains.size() - 1, -1, -1):
		var t = trains[i]
		var node: Node3D = t["node"]
		if not is_instance_valid(node):
			trains.remove_at(i)
			continue
		node.position.z += (speed + float(t["extra"])) * delta

		if not bool(t["horned"]) and node.position.z > -20.0 and float(t["extra"]) > 0.0:
			t["horned"] = true
			_play_train_horn()

		if node.position.z > 15.0:
			node.queue_free()
			trains.remove_at(i)
			continue

		if int(t["lane"]) != lane:
			continue
		var dz: float = abs(node.position.z - PLAYER_Z)
		var half_len: float = float(t["half_len"])
		if dz < half_len:
			var py: float = surface_y + jump_offset
			var roof: float = float(t["roof"])
			if py >= roof - 0.28 and jump_v <= 0.8:
				surface_y = roof
				if py > roof:
					jump_offset = py - roof
				else:
					jump_offset = 0.0
				player.position.y = surface_y + jump_offset
			elif py < roof - 0.45:
				_hit()
				return

func _update_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h = hazards[i]
		var node: Node3D = h["node"]
		if not is_instance_valid(node):
			hazards.remove_at(i)
			continue
		node.position.z += speed * delta
		if node.position.z > 12.0:
			node.queue_free()
			hazards.remove_at(i)
			continue
		if int(h["lane"]) != lane:
			continue
		if abs(node.position.z - PLAYER_Z) > 0.85:
			continue

		var typ := String(h["type"])
		if typ == "ramp":
			if surface_y < 0.25 and jump_offset < 0.15:
				jump_v = 9.2 if shoes_time <= 0.0 else 11.0
				_play_anim(["jump"], 1.12, 0.06)
				_play_sfx("jump.wav", 1.08)
			node.queue_free()
			hazards.remove_at(i)
			continue

		if typ == "barrier":
			var needed: float = float(h["height"])
			if surface_y + jump_offset < needed:
				_hit()
				return
		elif typ == "overhead":
			if slide_time <= 0.08:
				_hit()
				return

func _hit() -> void:
	if shield_time > 0.0:
		shield_time = 0.0
		shake = 0.28
		_flash(Color(0.25, 0.92, 1.0, 0.34))
		_play_sfx("power.wav", 0.88)
		return
	game_over = true
	started = false
	shake = 0.55
	_play_anim(["hit", "death"], 1.0, 0.08)
	_play_sfx("hit.wav", 1.0)
	_flash(Color(1.0, 0.14, 0.25, 0.40))
	total_coins += run_coins
	if score > best_score:
		best_score = score
	_save_game()
	else:
		_save_game()
	gameover_score.text = "SCORE  %d\nCOINS  %d\nBEST  %d" % [score, run_coins, best_score]
	revive_button.visible = (not revive_used and total_coins >= 30)
	gameover_panel.visible = true

# -------------------------------------------------------------------
# COINS / POWERUPS

func _spawn_coin_pattern() -> void:
	var li: int = rng.randi_range(0, 2)
	var count: int = rng.randi_range(6, 10)
	var style: int = rng.randi_range(0, 3)
	for i in range(count):
		var y: float = 0.78
		if style == 1:
			y += sin(float(i) / float(max(1, count - 1)) * PI) * 1.35
		elif style == 2:
			y = 1.30 if i % 2 == 0 else 0.80
		elif style == 3 and distance > 200.0:
			y = TRAIN_ROOF_Y + 0.78
		_spawn_coin(li, -45.0 - float(i) * 2.05, y)

func _spawn_coin(which_lane: int, z: float, y: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(float(LANE_X[which_lane]), y, z)
	pickup_root.add_child(root)

	var outer := _cylinder(0.29, 0.29, 0.085, mat_gold)
	outer.rotation_degrees.x = 90.0
	root.add_child(outer)
	var inner := _cylinder(0.18, 0.18, 0.092, mat_neon_pink)
	inner.rotation_degrees.x = 90.0
	root.add_child(inner)
	var star := _sphere(0.085, mat_gold)
	star.scale = Vector3(1.0, 0.42, 1.0)
	root.add_child(star)

	coins_world.append({"node": root, "lane": which_lane, "base_y": y, "phase": rng.randf_range(0.0, 6.0)})

func _update_coins(delta: float) -> void:
	for i in range(coins_world.size() - 1, -1, -1):
		var c = coins_world[i]
		var node: Node3D = c["node"]
		if not is_instance_valid(node):
			coins_world.remove_at(i)
			continue
		node.position.z += speed * delta
		c["phase"] = float(c["phase"]) + delta * 5.0
		node.rotation.y += delta * 5.6
		node.position.y = float(c["base_y"]) + sin(float(c["phase"])) * 0.055

		if magnet_time > 0.0 and node.position.z > -11.0 and node.position.z < 5.0:
			node.position.x = lerpf(node.position.x, player.position.x, min(1.0, delta * 7.2))
			node.position.y = lerpf(node.position.y, player.position.y + 0.95, min(1.0, delta * 6.5))

		var x_dist: float = abs(node.position.x - player.position.x)
		var z_dist: float = abs(node.position.z - PLAYER_Z)
		var y_dist: float = abs(node.position.y - (player.position.y + 0.92))
		var collect: bool = (x_dist < 0.60 and z_dist < 0.78 and y_dist < 1.20)
		if magnet_time > 0.0:
			collect = x_dist < 1.55 and z_dist < 1.8 and y_dist < 1.7

		if collect:
			run_coins += 1
			score += 55 * multiplier
			_play_sfx("coin.wav", rng.randf_range(0.98, 1.16))
			_flash(Color(1.0, 0.78, 0.15, 0.10))
			node.queue_free()
			coins_world.remove_at(i)
			continue
		if node.position.z > 12.0:
			node.queue_free()
			coins_world.remove_at(i)

func _spawn_powerup() -> void:
	var li: int = rng.randi_range(0, 2)
	var typ: int = rng.randi_range(0, 3)
	var root := Node3D.new()
	root.position = Vector3(float(LANE_X[li]), 1.05, -64.0)
	pickup_root.add_child(root)
	var color_mat: Material = mat_neon_cyan if typ == 0 else (mat_neon_pink if typ == 1 else (mat_gold if typ == 2 else mat_purple))
	var orb := _sphere(0.35, color_mat)
	root.add_child(orb)
	var ring := _cylinder(0.49, 0.49, 0.055, mat_white)
	ring.rotation_degrees.x = 90.0
	root.add_child(ring)
	powerups.append({"node": root, "lane": li, "type": typ})

func _update_powerups(delta: float) -> void:
	for i in range(powerups.size() - 1, -1, -1):
		var p = powerups[i]
		var node: Node3D = p["node"]
		if not is_instance_valid(node):
			powerups.remove_at(i)
			continue
		node.position.z += speed * delta
		node.rotation.y += delta * 2.8
		node.position.y = 1.05 + sin(run_time * 4.0 + float(i)) * 0.10
		if abs(node.position.z - PLAYER_Z) < 0.86 and abs(node.position.x - player.position.x) < 0.68:
			var typ: int = int(p["type"])
			if typ == 0:
				magnet_time = 8.0
			elif typ == 1:
				shield_time = 10.0
			elif typ == 2:
				shoes_time = 9.0
			else:
				x2_time = 10.0
			_play_sfx("power.wav", 1.0 + float(typ) * 0.05)
			_flash(Color(1.0, 0.36, 0.75, 0.22))
			node.queue_free()
			powerups.remove_at(i)
			continue
		if node.position.z > 12.0:
			node.queue_free()
			powerups.remove_at(i)

func _update_powers(delta: float) -> void:
	magnet_time = max(0.0, magnet_time - delta)
	shield_time = max(0.0, shield_time - delta)
	shoes_time = max(0.0, shoes_time - delta)
	x2_time = max(0.0, x2_time - delta)

# -------------------------------------------------------------------
# MOVEMENT

func _lane_left() -> void:
	if not started or game_over:
		return
	if lane > 0:
		lane -= 1
		if visual:
			visual.rotation.z = 0.10
		_play_sfx("lane.wav", 0.93)

func _lane_right() -> void:
	if not started or game_over:
		return
	if lane < 2:
		lane += 1
		if visual:
			visual.rotation.z = -0.10
		_play_sfx("lane.wav", 1.07)

func _jump() -> void:
	if not started or game_over:
		return
	if jump_offset <= 0.02 and slide_time <= 0.0:
		jump_v = 9.3 if shoes_time > 0.0 else 8.15
		_play_anim(["jump"], 1.08, 0.06)
		_play_sfx("jump.wav", 1.0)

func _slide() -> void:
	if not started or game_over:
		return
	if jump_offset <= 0.06:
		slide_time = 0.78
		_play_anim(["roll", "dodge", "duck", "crouch"], 1.15, 0.06)
		_play_sfx("slide.wav", 1.0)

# -------------------------------------------------------------------
# INTRO / SPEED FX

func _setup_intro_guard() -> void:
	intro_guard = Node3D.new()
	intro_guard.name = "MetroGuard"
	intro_guard.position = Vector3(-0.75, 0.0, 3.2)
	add_child(intro_guard)
	var body := _capsule(0.34, 1.15, _mat(Color("#4c678b"), 0.60))
	body.position.y = 1.0
	intro_guard.add_child(body)
	var head := _sphere(0.28, _mat(Color("#d9a278"), 0.72))
	head.position.y = 1.72
	intro_guard.add_child(head)
	var cap := _cylinder(0.30, 0.30, 0.10, mat_black)
	cap.position.y = 2.00
	intro_guard.add_child(cap)
	var badge := _box(Vector3(0.08, 0.10, 0.025), mat_gold)
	badge.position = Vector3(0.0, 1.22, -0.34)
	intro_guard.add_child(badge)

func _update_intro(delta: float) -> void:
	if not intro_guard:
		return
	if intro_time < 3.5:
		intro_guard.visible = true
		intro_guard.position.z = lerpf(intro_guard.position.z, 3.65, delta * 1.2)
		intro_guard.position.x = -0.8 + sin(intro_time * 8.0) * 0.08
	else:
		intro_guard.position.z += delta * 5.0
		if intro_guard.position.z > 11.0:
			intro_guard.visible = false

func _setup_speed_lines() -> void:
	for i in range(20):
		var s := _box(Vector3(0.022, 0.022, rng.randf_range(0.7, 1.7)), mat_neon_pink if i % 2 == 0 else mat_neon_cyan)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		s.position = Vector3(side * rng.randf_range(4.8, 8.0), rng.randf_range(0.35, 4.0), rng.randf_range(-50.0, 5.0))
		s.visible = false
		fx_root.add_child(s)
		speed_lines.append(s)

func _update_speed_lines(delta: float) -> void:
	var active: bool = speed > 15.0 and started and not game_over
	for s in speed_lines:
		s.visible = active
		if not active:
			continue
		s.position.z += speed * delta * 2.3
		if s.position.z > 8.0:
			var side: float = -1.0 if s.position.x < 0.0 else 1.0
			s.position = Vector3(side * rng.randf_range(4.8, 8.2), rng.randf_range(0.35, 4.0), rng.randf_range(-52.0, -25.0))

# -------------------------------------------------------------------
# UI

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var top := ColorRect.new()
	top.color = Color(0.04, 0.025, 0.08, 0.68)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 122.0
	ui.add_child(top)

	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.add_theme_font_size_override("font_size", 34)
	pause_button.position = Vector2(18, 15)
	pause_button.size = Vector2(76, 76)
	pause_button.pressed.connect(_toggle_pause)
	ui.add_child(pause_button)

	score_label = _label("000000", 36, Color.WHITE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.offset_left = -360
	score_label.offset_right = -25
	score_label.offset_top = 15
	score_label.offset_bottom = 60
	ui.add_child(score_label)

	multi_label = _label("x1", 34, Color("#ffe23d"))
	multi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	multi_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	multi_label.offset_left = -495
	multi_label.offset_right = -375
	multi_label.offset_top = 15
	multi_label.offset_bottom = 60
	ui.add_child(multi_label)

	coins_label = _label("0  ◉", 27, Color("#ffc83d"))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coins_label.offset_left = -300
	coins_label.offset_right = -25
	coins_label.offset_top = 67
	coins_label.offset_bottom = 104
	ui.add_child(coins_label)

	best_label = _label("BEST 0", 17, Color("#ff8dcc"))
	best_label.position = Vector2(110, 28)
	ui.add_child(best_label)

	mission_label = _label("MISSION  0/30 COINS", 18, Color("#f8edf7"))
	mission_label.position = Vector2(110, 65)
	ui.add_child(mission_label)

	power_label = _label("", 19, Color("#6eeeff"))
	power_label.position = Vector2(24, 134)
	ui.add_child(power_label)

	start_panel = _center_panel()
	ui.add_child(start_panel)
	var title := _label("PINK METRO\nRUSH", 64, Color("#ff58ae"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-390, -330)
	title.size = Vector2(780, 170)
	start_panel.add_child(title)
	var sub := _label("RAIL CITY RUNNER", 23, Color("#fff5fc"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(-350, -142)
	sub.size = Vector2(700, 50)
	start_panel.add_child(sub)
	var control := _label("SWIPE ← →  CHANGE TRACK\nSWIPE ↑  JUMP     ↓  ROLL\n\nRUN ON TRAIN ROOFS • GRAB POWER-UPS", 21, Color("#e7dcea"))
	control.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.position = Vector2(-395, 40)
	control.size = Vector2(790, 170)
	start_panel.add_child(control)
	var tap := _label("TAP TO RUN", 36, Color("#ffcf45"))
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.position = Vector2(-300, 250)
	tap.size = Vector2(600, 60)
	start_panel.add_child(tap)

	gameover_panel = _center_panel()
	gameover_panel.visible = false
	ui.add_child(gameover_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.015, 0.06, 0.74)
	dim.position = Vector2(-520, -650)
	dim.size = Vector2(1040, 1300)
	gameover_panel.add_child(dim)
	var busted := _label("BUSTED!", 64, Color("#ff526e"))
	busted.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	busted.position = Vector2(-340, -250)
	busted.size = Vector2(680, 90)
	gameover_panel.add_child(busted)
	gameover_score = _label("", 29, Color.WHITE)
	gameover_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameover_score.position = Vector2(-330, -110)
	gameover_score.size = Vector2(660, 170)
	gameover_panel.add_child(gameover_score)
	revive_button = Button.new()
	revive_button.text = "REVIVE — 30 COINS"
	revive_button.add_theme_font_size_override("font_size", 26)
	revive_button.position = Vector2(-250, 115)
	revive_button.size = Vector2(500, 72)
	revive_button.pressed.connect(_revive)
	gameover_panel.add_child(revive_button)
	var restart := Button.new()
	restart.text = "RUN AGAIN"
	restart.add_theme_font_size_override("font_size", 27)
	restart.position = Vector2(-250, 215)
	restart.size = Vector2(500, 72)
	restart.pressed.connect(_restart)
	gameover_panel.add_child(restart)

	pause_panel = _center_panel()
	pause_panel.visible = false
	ui.add_child(pause_panel)
	var pdim := ColorRect.new()
	pdim.color = Color(0.03, 0.015, 0.06, 0.78)
	pdim.position = Vector2(-520, -650)
	pdim.size = Vector2(1040, 1300)
	pause_panel.add_child(pdim)
	var ptitle := _label("PAUSED", 62, Color("#ff71bd"))
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptitle.position = Vector2(-300, -110)
	ptitle.size = Vector2(600, 90)
	pause_panel.add_child(ptitle)
	var resume := Button.new()
	resume.text = "RESUME"
	resume.add_theme_font_size_override("font_size", 28)
	resume.position = Vector2(-230, 55)
	resume.size = Vector2(460, 78)
	resume.pressed.connect(_toggle_pause)
	pause_panel.add_child(resume)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1,1,1,0)
	ui.add_child(flash_rect)

func _label(t: String, sz: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.07, 0.82))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.48))
	return l

func _center_panel() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	return c

func _update_hud() -> void:
	if not score_label:
		return
	score_label.text = "%06d" % score
	var effective: int = multiplier * (2 if x2_time > 0.0 else 1)
	multi_label.text = "x%d" % effective
	coins_label.text = "%d  ◉" % run_coins
	best_label.text = "BEST  %d" % best_score
	mission_label.text = "MISSION  %s" % ("DONE +3000" if mission_done else "%d/%d COINS" % [run_coins, mission_target])
	var powers: Array[String] = []
	if magnet_time > 0.0:
		powers.append("MAGNET %.0fs" % magnet_time)
	if shield_time > 0.0:
		powers.append("BOARD %.0fs" % shield_time)
	if shoes_time > 0.0:
		powers.append("SUPER JUMP %.0fs" % shoes_time)
	if x2_time > 0.0:
		powers.append("x2 %.0fs" % x2_time)
	power_label.text = "  •  ".join(powers)

func _toggle_pause() -> void:
	if not started or game_over:
		return
	is_paused = not is_paused
	pause_panel.visible = is_paused
	if music:
		music.stream_paused = is_paused

func _flash(c: Color) -> void:
	if flash_rect:
		flash_rect.color = c

func _update_ui_fx(delta: float) -> void:
	if flash_rect and flash_rect.color.a > 0.002:
		var c := flash_rect.color
		c.a = max(0.0, c.a - delta * 1.8)
		flash_rect.color = c

# -------------------------------------------------------------------
# START / RESTART / REVIVE / SAVE

func _start_run() -> void:
	started = true
	game_over = false
	start_panel.visible = false
	_play_run()

func _clear_dynamic() -> void:
	for collection in [trains, hazards, coins_world, powerups]:
		for item in collection:
			var n: Node3D = item["node"]
			if is_instance_valid(n):
				n.queue_free()
		collection.clear()

func _restart() -> void:
	_clear_dynamic()
	lane = 1
	surface_y = 0.0
	jump_offset = 0.0
	jump_v = 0.0
	player.position = Vector3(0.0, 0.0, PLAYER_Z)
	speed = 11.2
	distance = 0.0
	score = 0
	run_coins = 0
	multiplier = 1
	magnet_time = 0.0
	shield_time = 0.0
	shoes_time = 0.0
	x2_time = 0.0
	spawn_timer = 0.75
	coin_timer = 0.30
	power_timer = 8.0
	intro_time = 0.0
	revive_used = false
	mission_done = false
	game_over = false
	started = true
	is_paused = false
	gameover_panel.visible = false
	start_panel.visible = false
	pause_panel.visible = false
	if intro_guard:
		intro_guard.position = Vector3(-0.75, 0.0, 3.2)
		intro_guard.visible = true
	_play_run()
	_update_hud()

func _revive() -> void:
	if revive_used or total_coins < 30:
		return
	total_coins -= 30
	revive_used = true
	game_over = false
	started = true
	gameover_panel.visible = false
	shield_time = 4.0
	surface_y = 0.0
	jump_offset = 0.0
	player.position.y = 0.0
	for i in range(trains.size() - 1, -1, -1):
		var node: Node3D = trains[i]["node"]
		if is_instance_valid(node) and abs(node.position.z - PLAYER_Z) < 12.0:
			node.queue_free()
			trains.remove_at(i)
	for i in range(hazards.size() - 1, -1, -1):
		var hnode: Node3D = hazards[i]["node"]
		if is_instance_valid(hnode) and abs(hnode.position.z - PLAYER_Z) < 9.0:
			hnode.queue_free()
			hazards.remove_at(i)
	_play_sfx("revive.wav", 1.0)
	_flash(Color(0.35, 0.95, 1.0, 0.30))
	_play_run()
	_save_game()

func _load_save() -> void:
	if not FileAccess.file_exists("user://pink_metro.save"):
		return
	var f := FileAccess.open("user://pink_metro.save", FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		best_score = int(data.get("best", 0))
		total_coins = int(data.get("coins", 0))

func _save_game() -> void:
	var f := FileAccess.open("user://pink_metro.save", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best_score, "coins": total_coins}))

# -------------------------------------------------------------------
# AUDIO

func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -12.0
	add_child(music)
	if ResourceLoader.exists("res://generated/music.wav"):
		var m = load("res://generated/music.wav")
		if m is AudioStreamWAV:
			(m as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.stream = m
		music.play()

	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -2.5
	add_child(sfx)
	train_sfx = AudioStreamPlayer.new()
	train_sfx.volume_db = -7.0
	add_child(train_sfx)

func _play_sfx(file: String, pitch: float = 1.0) -> void:
	var path := "res://generated/" + file
	if sfx and ResourceLoader.exists(path):
		sfx.stream = load(path)
		sfx.pitch_scale = pitch
		sfx.play()

func _play_train_horn() -> void:
	if train_sfx and ResourceLoader.exists("res://generated/train_horn.wav"):
		train_sfx.stream = load("res://generated/train_horn.wav")
		train_sfx.pitch_scale = rng.randf_range(0.88, 1.05)
		train_sfx.play()

# -------------------------------------------------------------------
# MESH HELPERS

func _box(half: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = half * 2.0
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n

func _sphere(radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	return n

func _capsule(radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = max(height, radius * 2.05)
	mesh.radial_segments = 16
	mesh.rings = 8
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	return n

func _cylinder(top_radius: float, bottom_radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 18
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	return n

func _alpha_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
