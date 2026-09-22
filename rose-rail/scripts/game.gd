extends Node3D
## Rose Rail: fixed-step runner; a floating origin keeps long runs stable.
const LANES := [-3.2, 0.0, 3.2]
const LENGTH := 48.0
const ROOF := 3.12
const SAVE := "user://rose_rail_v1.json"
var rng := RandomNumberGenerator.new()
var hero: Node3D
var model: Node3D
var animation: AnimationPlayer
var camera: Camera3D
var world: Node3D
var drone: Node3D
var chunks: Array[Node3D] = []
var hazards: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var scenes: Dictionary = {}
var materials: Dictionary = {}
var mode := "menu"
var lane := 1
var velocity_y := 0.0
var grounded := true
var slide := 0.0
var speed := 13.0
var distance := 0.0
var run_coins := 0
var score := 0
var score_fraction := 0.0
var best := 0
var wallet := 0
var rank := 1
var mission_index := 0
var mission_progress := 0.0
var run_jumps := 0
var run_rolls := 0
var intro := 0.0
var elapsed := 0.0
var invincible := 0.0
var revived := false
var settled := false
var effects := {"magnet":0.0,"shield":0.0,"jump":0.0,"double":0.0}
var chunk_serial := 0
var gesture := Vector2.ZERO
var gesture_active := false
var muted := false
var reduced_fx := false
var anim_state := ""
var hud: Control
var overlay: Control
var score_text: Label
var coins_text: Label
var power_text: Label
var mission_text: Label
var toast: Label
var toast_time := 0.0
var pause_button: Button
var music: AudioStreamPlayer
var sounds: Dictionary = {}
var sound_pool: Array[AudioStreamPlayer] = []
var sound_index := 0
var shield_ring: MeshInstance3D
var headless := false

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	rng.seed = 197731
	_load_progress()
	_make_materials()
	for key in ["mika","train","station","tunnel","palm","building0","building1","building2","building3","building4"]:
		scenes[key] = load("res://assets/" + key + ".glb")
	_setup_world()
	_setup_ui()
	_setup_audio()
	_reset_track()
	_menu()
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func material(color: String, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.48
	m.metallic = metallic
	if emission > 0:
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = emission
	return m

func _make_materials() -> void:
	for pair in [["ballast","745e77"],["sleeper","413a50"],["rail","a6bbce"],["cream","ffe6be"],["pink","ef4085"],["dark","252540"],["teal","39c5c2"],["gold","ffd56e"],["glass","83dfea"],["concrete","cc97ae"]]:
		materials[pair[0]] = material(pair[1],0.65 if pair[0] == "rail" else 0.0)
	materials["glow"] = material("ffd56e",0.5,0.7)

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = materials[mat]
	parent.add_child(n)
	n.position = pos
	return n

func instance(key: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n: Node3D = scenes[key].instantiate()
	parent.add_child(n)
	n.position = pos
	return n

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4779ac")
	sky_mat.sky_horizon_color = Color("ffd3d5")
	sky_mat.ground_horizon_color = Color("edb3c7")
	sky_mat.ground_bottom_color = Color("40324e")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d0dafa")
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("dbb8d4")
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("ffdfc0")
	sun.light_energy = 0.8
	sun.shadow_enabled = not reduced_fx
	sun.directional_shadow_max_distance = 75
	add_child(sun)
	world = Node3D.new()
	add_child(world)
	hero = Node3D.new()
	add_child(hero)
	model = instance("mika",hero,Vector3.ZERO)
	# glTF conversion makes the authored forward (-Y) face +Z; turn down-track.
	model.rotation.y = PI
	animation = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if animation:
		for name in animation.get_animation_list():
			if "Run" in name or "Idle" in name:
				animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	var torus := TorusMesh.new()
	torus.inner_radius = .75
	torus.outer_radius = .81
	shield_ring = MeshInstance3D.new()
	shield_ring.mesh = torus
	shield_ring.material_override = materials["teal"]
	hero.add_child(shield_ring)
	shield_ring.position.y = .12
	shield_ring.visible = false
	drone = Node3D.new()
	add_child(drone)
	box(drone,Vector3.ZERO,Vector3(.75,.3,.5),"dark")
	box(drone,Vector3(0,0,-.28),Vector3(.5,.1,.08),"pink")
	for x in [-.6,.6]:box(drone,Vector3(x,.1,0),Vector3(.6,.06,.13),"teal")
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,5.3,9.3)
	camera.fov = 62
	camera.far = 260
	camera.current = true
	camera.look_at(Vector3(0,1.6,-9))

func _reset_track() -> void:
	for n in world.get_children():
		world.remove_child(n)
		n.queue_free()
	chunks.clear()
	hazards.clear()
	pickups.clear()
	chunk_serial = 0
	for i in range(6):
		_spawn_chunk(-float(i)*LENGTH)

func _multibox(parent: Node3D, transforms: Array[Transform3D], size: Vector3, mat: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = materials[mat]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	parent.add_child(mi)

func _spawn_chunk(z: float) -> void:
	var chunk := Node3D.new()
	world.add_child(chunk)
	chunk.position.z = z
	chunks.append(chunk)
	box(chunk,Vector3(0,-.21,-24),Vector3(11,.35,LENGTH),"ballast")
	var sleepers: Array[Transform3D] = []
	for x in LANES:
		for i in range(32):sleepers.append(Transform3D(Basis.IDENTITY,Vector3(x,-.005,-i*1.5)))
		for offset in [-.8,.8]:box(chunk,Vector3(x+offset,.075,-24),Vector3(.10,.15,LENGTH),"rail")
	_multibox(chunk,sleepers,Vector3(2.25,.12,.24),"sleeper")
	for side in [-1,1]:
		box(chunk,Vector3(side*6.1,-.02,-24),Vector3(2,.4,48),"concrete")
		box(chunk,Vector3(side*5.1,.26,-24),Vector3(.18,.45,48),"cream")
		for j in range(6):
			var b := instance("building"+str((chunk_serial+j+int(side)+5)%5),chunk,Vector3(side*(9.2+float(j%2)*.5),0,-j*8.0-3))
			b.rotation.y = -side*PI/2
			if j%2==0:
				instance("palm",chunk,Vector3(side*6.1,0,-j*8.0))
				box(chunk,Vector3(side*5.8,2.1,-j*8.0-3),Vector3(.12,4.2,.12),"dark")
				box(chunk,Vector3(side*5.6,4.2,-j*8.0-3),Vector3(.8,.16,.3),"cream")
	for dz in [-5,-29]:
		for side in [-1,1]:box(chunk,Vector3(side*5.0,3.7,dz),Vector3(.17,7.4,.17),"teal")
		box(chunk,Vector3(0,7.2,dz),Vector3(10.2,.18,.22),"dark")
	for x in LANES:box(chunk,Vector3(x,7,-24),Vector3(.026,.026,48),"dark")
	if chunk_serial%6==2:
		instance("station",chunk,Vector3(0,0,-25))
		_sign(chunk,"ROSE QUARTER",Vector3(0,5.16,-20.15),.005)
	elif chunk_serial%6==4:instance("tunnel",chunk,Vector3(0,0,-24))
	elif chunk_serial%6==5:
		box(chunk,Vector3(0,6.4,-24),Vector3(28,.65,7),"concrete")
		for s in [-1,1]:box(chunk,Vector3(s*5.7,3,-24),Vector3(.7,6,1),"purple" if materials.has("purple") else "dark")
	if chunk_serial==0:
		_train(0,z-31,false,true)
		_coin_line(1,z-12,8,0)
	else:
		_pattern(z-14,chunk_serial)
		_pattern(z-37,chunk_serial+1)
	chunk_serial += 1

func _sign(parent: Node3D, text: String, pos: Vector3, pixel: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 60
	label.pixel_size = pixel
	label.modulate = Color("ffdc9d")
	parent.add_child(label)
	label.position = pos

func _pattern(z: float, serial: int) -> void:
	# Every pattern reserves a ground escape lane; roof routes are optional rewards.
	var safe := serial%3
	var occupied := (safe+1)%3
	_train(occupied,z,serial%4==3,serial%4!=3)
	if serial%3==0:
		_barrier((safe+2)%3,z+4,"low")
	elif serial%3==1:
		_barrier((safe+2)%3,z,"high")
	_coin_line(safe,z+6,7,0)
	if serial%3==2:
		var kind: String = ["magnet","shield","jump","double"][(serial/3 as int)%4]
		_pickup(kind,Vector3(LANES[safe],1.2,z-9))

func _train(l: int, z: float, moving: bool, ramp: bool) -> void:
	var n := instance("train",world,Vector3(LANES[l],0,z))
	hazards.append({"node":n,"kind":"train","lane":l,"length":10.0,"move":8.0 if moving else 0.0})
	if moving:
		_sign(n,"EXPRESS",Vector3(0,2.67,5.07),.002)
	else:
		for i in range(5):_pickup("coin",Vector3(LANES[l],ROOF+1,z+4-i*2))
	if ramp:
		var r := Node3D.new()
		world.add_child(r)
		r.position = Vector3(LANES[l],0,z+8.5)
		var mesh := ArrayMesh.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-1.27,0,3.5)
		var b := Vector3(1.27,0,3.5)
		var c := Vector3(1.27,ROOF,-3.5)
		var d := Vector3(-1.27,ROOF,-3.5)
		for v in [a,c,b,a,d,c]:st.add_vertex(v)
		st.generate_normals()
		mesh = st.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = materials["gold"]
		r.add_child(mi)
		for x in [-1.3,1.3]:
			var edge := box(r,Vector3(x,ROOF/2+.1,0),Vector3(.13,.15,7.67),"teal")
			edge.rotation.x = atan(ROOF/7.0)
		hazards.append({"node":r,"kind":"ramp","lane":l,"length":7.0,"move":0.0})
		for i in range(5):_pickup("coin",Vector3(LANES[l],1+ROOF*i/5.0,z+12-i*1.4))

func _barrier(l: int,z: float,kind: String) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = Vector3(LANES[l],0,z)
	if kind=="low":
		box(n,Vector3(0,.48,0),Vector3(2.35,.95,.4),"pink")
		for i in range(5):box(n,Vector3(-.9+i*.45,.48,.22),Vector3(.2,.75,.04),"cream").rotation.z=-.4
	else:
		for x in [-1.15,1.15]:box(n,Vector3(x,1.6,0),Vector3(.17,3.2,.25),"teal")
		box(n,Vector3(0,2.35,0),Vector3(2.5,1.6,.3),"pink")
		_sign(n,"DUCK",Vector3(0,2.5,.18),.005)
	hazards.append({"node":n,"kind":kind,"lane":l,"length":.5,"move":0.0})

func _pickup(kind: String,pos: Vector3) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = pos
	var mi := MeshInstance3D.new()
	if kind=="coin":
		var mesh := CylinderMesh.new()
		mesh.top_radius = .25
		mesh.bottom_radius = .25
		mesh.height = .09
		mesh.radial_segments = 16
		mi.mesh = mesh
		mi.rotation.x = PI/2
		mi.material_override = materials["glow"]
	else:
		var mesh := PrismMesh.new()
		mesh.size = Vector3(.8,.8,.6)
		mi.mesh = mesh
		mi.material_override = materials["teal"] if kind in ["magnet","jump"] else materials["pink"]
		_sign(n,{"magnet":"M","shield":"S","jump":"J","double":"2×"}[kind],Vector3(0,0,.4),.008)
	n.add_child(mi)
	pickups.append({"node":n,"kind":kind,"base_y":pos.y})

func _coin_line(l: int,z: float,count: int,height: float) -> void:
	for i in count:_pickup("coin",Vector3(LANES[l],height+1,z-i*2.2))

func _physics_process(dt: float) -> void:
	if mode=="paused":return
	elapsed += dt
	if mode=="intro":
		intro -= dt
		_animate("Run")
		drone.position = Vector3(sin(elapsed*8)*.3,1.8,3.2)
		if intro<=0:mode="running"
	elif mode=="running":_step(dt)
	elif mode=="menu":_animate("Idle")
	if mode!="over":
		drone.visible = mode=="intro" or (mode=="running" and distance<70)
		if mode=="running":drone.position = Vector3(sin(elapsed*5)*.4,1.9,3+distance*.1)
	_update_camera(dt)
	shield_ring.visible = effects.shield>0 or invincible>0
	shield_ring.rotation.y += dt*3
	if toast_time>0:
		toast_time-=dt
		toast.visible=toast_time>0

func _step(dt: float) -> void:
	distance += speed*dt
	speed = minf(25,13+distance*.004)
	score_fraction += speed*dt*10*rank*(2 if effects.double>0 else 1)
	score += int(score_fraction)
	score_fraction -= int(score_fraction)
	hero.position.x = move_toward(hero.position.x,LANES[lane],dt*19)
	model.rotation.z = lerpf(model.rotation.z,(hero.position.x-LANES[lane])*.10,dt*10)
	slide=maxf(0,slide-dt)
	invincible=maxf(0,invincible-dt)
	for key in effects:effects[key]=maxf(0,effects[key]-dt)
	for ch in chunks:ch.position.z+=speed*dt
	if chunks[0].position.z>LENGTH+15:
		var old: Node3D=chunks.pop_front()
		old.queue_free()
		_spawn_chunk(chunks.back().position.z-LENGTH)
	for h in hazards:h.node.position.z+=(speed+h.move)*dt
	var floor_y := 0.0
	for h in hazards:
		if absf(h.node.position.x-hero.position.x)>.99:continue
		var z: float = h.node.position.z
		if h.kind=="ramp" and absf(z)<=3.55:
			floor_y=maxf(floor_y,clampf((z+3.5)/7,0,1)*ROOF)
		if h.kind=="train" and absf(z)<5.3 and hero.position.y>=ROOF-.25:
			floor_y=maxf(floor_y,ROOF)
	var previous_y := hero.position.y
	velocity_y-=25*dt
	hero.position.y+=velocity_y*dt
	if hero.position.y<=floor_y and (previous_y>=floor_y-.35 or grounded):
		hero.position.y=floor_y
		velocity_y=0
		grounded=true
	else:grounded=false
	for h in hazards:
		if h.get("hit",false) or absf(h.node.position.x-hero.position.x)>1.1:continue
		var z: float=h.node.position.z
		if absf(z)>h.length/2+.35:continue
		var hit: bool = (h.kind=="train" and hero.position.y<ROOF-.28) or (h.kind=="low" and hero.position.y<1.05) or (h.kind=="high" and (slide<=0 or hero.position.y>.2))
		if hit and invincible<=0:
			h["hit"]=true
			if effects.shield>0:
				effects.shield=0
				invincible=2.5
				_burst(hero.position+Vector3.UP,Color("72ffff"))
				_sound("hit")
				_notice("SHIELD SAVED YOU")
			else:
				_crash()
				return
	for i in range(hazards.size()-1,-1,-1):
		if hazards[i].node.position.z>20:
			hazards[i].node.queue_free()
			hazards.remove_at(i)
	for i in range(pickups.size()-1,-1,-1):
		var p: Dictionary=pickups[i]
		var n: Node3D=p.node
		n.position.z+=speed*dt
		n.rotation.y+=dt*2.5
		var aim := hero.position+Vector3(0,1,0)
		if effects.magnet>0 and p.kind=="coin" and n.position.distance_to(aim)<8:
			n.position=n.position.move_toward(aim,dt*28)
		if absf(n.position.z)<.85 and absf(n.position.x-hero.position.x)<.85 and absf(n.position.y-aim.y)<1.05:
			_collect(p.kind)
			n.queue_free()
			pickups.remove_at(i)
		elif n.position.z>14:
			n.queue_free()
			pickups.remove_at(i)
	_animate("Slide" if slide>0 else ("Run" if grounded else "Jump"))
	_check_mission()
	_update_hud()

func _collect(kind: String) -> void:
	if kind=="coin":
		run_coins+=1
		score+=25*rank
		_sound("coin")
	else:
		effects[kind]=12.0
		_sound("power")
		_notice({"magnet":"COIN MAGNET","shield":"SHIELD READY","jump":"SUPER JUMP","double":"DOUBLE SCORE"}[kind])
		_burst(hero.position+Vector3.UP,Color("ffd56e"))

func _animate(state: String) -> void:
	if state==anim_state or not animation:return
	anim_state=state
	for clip in animation.get_animation_list():
		if state in clip:
			animation.play(clip,.14,1.25 if state=="Run" else 1)
			return

func _update_camera(dt: float) -> void:
	var target := Vector3(hero.position.x*.24,5.4+hero.position.y*.48,9.5)
	if mode=="menu":target=Vector3(4.3,3.3,5.8)
	camera.position=camera.position.lerp(target,1-exp(-dt*5))
	var look := Vector3(hero.position.x*.22,1.8+hero.position.y*.5,-7)
	if mode=="menu":look=Vector3(0,1.4,0)
	camera.look_at(look)
	camera.fov=lerpf(camera.fov,62+(speed-13)*.45,dt*3)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT,KEY_A:_lane(-1)
			KEY_RIGHT,KEY_D:_lane(1)
			KEY_UP,KEY_W,KEY_SPACE:_jump()
			KEY_DOWN,KEY_S:_roll()
			KEY_ESCAPE,KEY_P:_pause()
			KEY_ENTER:
				if mode in ["menu","over"]:_start()
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		if event.pressed:
			gesture=event.position
			gesture_active=true
		elif gesture_active:
			_swipe(event.position-gesture)
			gesture_active=false
	if event is InputEventScreenDrag and gesture_active and event.position.distance_to(gesture)>45:
		_swipe(event.position-gesture)
		gesture_active=false

func _swipe(delta: Vector2) -> void:
	if delta.length()<30:return
	if absf(delta.x)>absf(delta.y):_lane(1 if delta.x>0 else -1)
	elif delta.y<0:_jump()
	else:_roll()

func _lane(direction: int) -> void:
	if mode!="running":return
	lane=clampi(lane+direction,0,2)
	_sound("swipe")

func _jump() -> void:
	if mode!="running" or not grounded:return
	velocity_y=14.5 if effects.jump>0 else 10.3
	grounded=false
	slide=0
	run_jumps+=1
	_sound("jump")

func _roll() -> void:
	if mode!="running":return
	slide=.85
	if not grounded:velocity_y=-20
	run_rolls+=1
	_sound("swipe")

func _start() -> void:
	if not settled and run_coins>0:_bank()
	distance=0
	score=0
	score_fraction=0
	run_coins=0
	run_jumps=0
	run_rolls=0
	speed=13
	lane=1
	velocity_y=0
	slide=0
	hero.position=Vector3.ZERO
	grounded=true
	revived=false
	settled=false
	invincible=0
	for k in effects:effects[k]=0.0
	_reset_track()
	mode="intro"
	intro=1.5
	overlay.visible=false
	hud.visible=true
	_notice("OUTRUN THE SECURITY DRONE")
	_update_hud()

func _crash() -> void:
	mode="over"
	_animate("Stumble")
	_sound("hit")
	_burst(hero.position+Vector3.UP,Color("ff6595"))
	best=maxi(best,score)
	_save_progress()
	_over()

func _bank() -> void:
	if settled:return
	wallet+=run_coins
	settled=true
	best=maxi(best,score)
	_save_progress()

func _revive() -> void:
	if revived:return
	revived=true
	invincible=3.5
	mode="running"
	overlay.visible=false
	_notice("BACK ON TRACK • 3 SECOND SHIELD")

func _pause() -> void:
	if mode=="running":
		mode="paused"
		_panel("TAKE A BREATHER","Your run is waiting.")
		_button("CONTINUE",_resume)
		_button("SOUND: "+("OFF" if muted else "ON"),_toggle_sound)
		_button("END RUN",func(): _bank(); _menu())
	elif mode=="paused":_resume()

func _resume() -> void:
	mode="running"
	overlay.visible=false

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED:
		if mode=="running":_pause()
		_save_progress()

func _check_mission() -> void:
	var goals := [30.0,500.0,12.0,8.0]
	var values := [float(run_coins),distance,float(run_jumps),float(run_rolls)]
	var idx := mission_index%4
	mission_progress=values[idx]
	if mission_progress>=goals[idx]:
		mission_index+=1
		rank=mini(10,rank+1)
		wallet+=50
		_notice("MISSION COMPLETE • +50 COINS • ×"+str(rank))
		_sound("power")
		_save_progress()

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE):return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if data is Dictionary:
		best=maxi(0,int(data.get("best",0)))
		wallet=maxi(0,int(data.get("coins",0)))
		rank=clampi(int(data.get("rank",1)),1,10)
		mission_index=maxi(0,int(data.get("mission",0)))
		muted=bool(data.get("muted",false))

func _save_progress() -> void:
	if "--smoke" in OS.get_cmdline_user_args():return
	var f := FileAccess.open(SAVE,FileAccess.WRITE)
	if f:f.store_string(JSON.stringify({"best":best,"coins":wallet,"rank":rank,"mission":mission_index,"muted":muted}))

func _burst(pos: Vector3,color: Color) -> void:
	if reduced_fx or headless:return
	var particles := CPUParticles3D.new()
	add_child(particles)
	particles.position=pos
	particles.amount=18
	particles.lifetime=.5
	particles.one_shot=true
	particles.explosiveness=1
	particles.direction=Vector3.UP
	particles.spread=150
	particles.initial_velocity_min=2
	particles.initial_velocity_max=5
	particles.gravity=Vector3(0,-8,0)
	particles.scale_amount_min=.04
	particles.scale_amount_max=.12
	particles.color=color
	particles.mesh=SphereMesh.new()
	particles.emitting=true
	get_tree().create_timer(.8).timeout.connect(particles.queue_free)

func _setup_audio() -> void:
	for key in ["coin","jump","swipe","hit","power"]:sounds[key]=load("res://generated/"+key+".wav")
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.volume_db=-13
		sound_pool.append(p)
	music=AudioStreamPlayer.new()
	add_child(music)
	var stream: AudioStreamWAV=load("res://generated/music.wav")
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=stream.data.size()/2
	music.stream=stream
	music.volume_db=-20
	if not muted:music.play()

func _sound(key: String) -> void:
	if muted or sound_pool.is_empty():return
	var p := sound_pool[sound_index%8]
	sound_index+=1
	p.stream=sounds[key]
	p.play()

func _toggle_sound() -> void:
	muted=not muted
	if muted:music.stop()
	else:music.play()
	_save_progress()
	if mode=="paused":mode="running";_pause()
	else:_menu()

func _style(bg: String,border: String="") -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=Color(bg)
	s.set_corner_radius_all(18)
	s.content_margin_left=20
	s.content_margin_right=20
	s.content_margin_top=12
	s.content_margin_bottom=12
	if border!="":
		s.border_color=Color(border)
		s.set_border_width_all(2)
	return s

func _label(parent: Node,text: String,size: int,color: String="fff2e3") -> Label:
	var l := Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color(color))
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud=Control.new()
	canvas.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	hud.add_child(top)
	top.position=Vector2(20,42)
	top.size=Vector2(500,80)
	top.add_theme_constant_override("separation",12)
	var card := VBoxContainer.new()
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(card)
	_label(card,"DISTANCE CLUB",11,"77e4df")
	score_text=_label(card,"000000",31)
	coins_text=_label(top,"● 0",25,"ffd56e")
	pause_button=Button.new()
	pause_button.text="Ⅱ"
	pause_button.custom_minimum_size=Vector2(56,56)
	pause_button.add_theme_stylebox_override("normal",_style("24233ee8"))
	top.add_child(pause_button)
	pause_button.pressed.connect(_pause)
	power_text=_label(hud,"",16,"77e4df")
	power_text.position=Vector2(20,130)
	power_text.size=Vector2(500,40)
	mission_text=_label(hud,"",16)
	mission_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	mission_text.offset_top=-85
	mission_text.offset_bottom=-45
	toast=_label(hud,"",17,"ffd56e")
	toast.position=Vector2(15,190)
	toast.size=Vector2(510,60)
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	overlay=Control.new()
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

var panel_box: VBoxContainer
func _panel(title: String,subtitle: String) -> void:
	for c in overlay.get_children():
		overlay.remove_child(c)
		c.queue_free()
	overlay.visible=true
	var dim := ColorRect.new()
	dim.color=Color(0.07,.045,.14,.60)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",34)
	margin.add_theme_constant_override("margin_right",34)
	var center := VBoxContainer.new()
	center.alignment=BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center)
	panel_box=VBoxContainer.new()
	panel_box.add_theme_constant_override("separation",15)
	center.add_child(panel_box)
	_label(panel_box,"R O S E   R A I L",17,"77e4df")
	_label(panel_box,title,38)
	var sub := _label(panel_box,subtitle,17,"e0c5d7")
	sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _button(text: String,action: Callable) -> void:
	var b := Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(0,62)
	b.add_theme_font_size_override("font_size",19)
	b.add_theme_stylebox_override("normal",_style("e8397e"))
	b.add_theme_stylebox_override("hover",_style("f55f9b","ffdca4"))
	b.add_theme_stylebox_override("pressed",_style("a9235c"))
	panel_box.add_child(b)
	b.pressed.connect(action)

func _menu() -> void:
	mode="menu"
	hud.visible=false
	_panel("MIDNIGHT EXPRESS","Mika has a city to outrun.")
	_label(panel_box,"BEST  %06d   /   BANK  %d"%[best,wallet],18,"ffd56e")
	_button("LET’S RUN  →",_start)
	_button("HOW TO PLAY",_help)
	_button("SOUND: "+("OFF" if muted else "ON"),_toggle_sound)
	_label(panel_box,"ROSE QUARTER  /  VOL. 01",12,"b49bba")

func _help() -> void:
	_panel("OWN THE RAILS","Swipe ← → to change tracks\nSwipe ↑ to jump · ↓ to roll\n\nGold ramps lead to train roofs.\nAvoid oncoming express trains.\nM: magnet · S: shield · J: super jump\n2×: double score for 12 seconds\n\nComplete missions to raise your multiplier.\nKeyboard: arrows / WASD · P to pause")
	_button("GOT IT",_menu)

func _over() -> void:
	_panel("NICE RUN.","%d metres through Rose Quarter"%int(distance))
	_label(panel_box,"%06d"%score,48,"ffd56e")
	_label(panel_box,"+%d COINS   ·   BEST %06d"%[run_coins,best],18)
	if not revived:_button("ONE MORE CHANCE • FREE",_revive)
	_button("BANK & RUN AGAIN",func(): _bank(); _start())
	_button("BACK TO CITY",func(): _bank(); _menu())

func _notice(text: String) -> void:
	toast.text=text
	toast.visible=true
	toast_time=2.6

func _update_hud() -> void:
	score_text.text="%06d"%score
	coins_text.text="● %d"%run_coins
	var active: Array[String]=[]
	for k in effects:
		if effects[k]>0:active.append(k.to_upper()+" %ds"%int(ceil(effects[k])))
	power_text.text="  ·  ".join(active)
	var idx := mission_index%4
	var names := ["Collect 30 coins","Run 500 metres","Jump 12 times","Roll 8 times"]
	mission_text.text="×%d  •  %s  (%d)"%[rank,names[idx],int(mission_progress)]

func _capture() -> void:
	_start()
	mode="running"
	set_physics_process(false)
	_animate("Run")
	if animation:animation.advance(.15)
	for ch in chunks:ch.position.z+=8
	for h in hazards:h.node.position.z+=8
	for p in pickups:p.node.position.z+=8
	for i in range(120):_update_camera(1.0/60)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build-preview.png")
	get_tree().quit()

func _run_smoke() -> void:
	set_physics_process(false)
	_start()
	mode="running"
	assert(chunks.size()==6)
	_lane(-1)
	assert(lane==0)
	_jump()
	assert(velocity_y>0 and not grounded)
	_roll()
	assert(slide>0 and velocity_y<0)
	_collect("magnet")
	assert(effects.magnet==12)
	_collect("coin")
	assert(run_coins==1)
	# Approach the first ramp in lane 0 without jumping, then verify roof support.
	_start()
	mode="running"
	lane=0
	hero.position.x=LANES[0]
	for i in range(125):_step(1.0/60)
	assert(mode=="running" and hero.position.y>3.0,"Ramp must lead to a runnable train roof")
	_jump()
	assert(velocity_y>0 and hero.position.y>3.0,"Must jump from train roof")
	_start()
	mode="running"
	# Traverse thousands of metres with invulnerability to exercise chunk lifecycle.
	for i in range(18000):
		invincible=99
		_step(1.0/60)
		if i%120==0:await get_tree().process_frame
	assert(distance>4000)
	assert(chunks.size()==6)
	assert(hazards.size()<80 and pickups.size()<220)
	_pause()
	assert(mode=="paused")
	_resume()
	assert(mode=="running")
	_crash()
	assert(mode=="over")
	_revive()
	assert(mode=="running" and revived)
	print("ROSE_RAIL_SMOKE_OK distance=",distance," hazards=",hazards.size()," pickups=",pickups.size())
	await get_tree().process_frame
	get_tree().quit()
