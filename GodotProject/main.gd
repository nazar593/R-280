extends Node3D

const Hud := preload("res://hud.gd")
const Terrain := preload("res://terrain.gd")
const Dynamics := preload("res://vehicle_dynamics.gd")
const Fleet := preload("res://fleet.gd")
const Freight := preload("res://freight.gd")
const LOADOUTS := ["2 × 12,7","20 мм","23 мм"]
const SKY := [Color("#92adbd"),Color("#b39b85"),Color("#26374c")]
const RETICLE := Color("#87f2a0")
const AMBER := Color("#eab970")
var road: Terrain
var env: Environment
var sunlight: DirectionalLight3D
var camera: Camera3D
var arena: Node3D
var rig: Node3D
var car: VehicleBody3D
var drivetrain: Dynamics
var drone: CharacterBody3D
var drone_skin: Node3D
var rotor: Node3D
var turret: Node3D
var ai: Node3D
var primary: Freight
var convoy: Array[Freight] = []
var hazards: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var time_run := 0.0
var signal_strength := 1.0
var battery := 1.0
var last_fix := Vector3.ZERO
var yaw := 0.0
var pitch := .16
var recoil := 0.0
var cooldown := 0.0
var seat := 0
var role := ""
var active := false
var van := false
var wet := false
var time_choice := 0
var quality := 1
var profile := 0
var linked_scout := false
var mark_until := 0.0
var menu: PanelContainer
var top: HBoxContainer
var info: Label
var task: Label
var notice: Label
var choice: Button
var gun_choice: Button
var weather: Button
var daylight: Button
var quality_choice: Button
var camera_button: Button
var target_button: Button
var seat_button: Button
var status_panel: PanelContainer
var hud: Hud
var map_visible := false
var left := Vector2.ZERO
var look_touch := Vector2.ZERO
var left_id := -1
var look_id := -1
var lift_id := -1
var lift := 0.0
var origin_left := Vector2.ZERO
var origin_look := Vector2.ZERO
var drone_motor: AudioStreamPlayer3D
var escort_motor: AudioStreamPlayer3D
var engine_clip: AudioStreamWAV
var prop_clip: AudioStreamWAV
var hit_clip: AudioStreamWAV
var gun_clip: AudioStreamWAV
var hiss_clip: AudioStreamWAV
var scan_clip: AudioStreamWAV

func _ready() -> void:
	road = Terrain.new()
	add_child(road)
	road.build()
	var scene_env := WorldEnvironment.new()
	env = Environment.new()
	scene_env.environment = env
	add_child(scene_env)
	sunlight = DirectionalLight3D.new()
	add_child(sunlight)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 66
	camera.near = .07
	load_sounds()
	make_ui()
	apply_weather()
	menu_camera()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	elif "--screenshots" in OS.get_cmdline_user_args():
		call_deferred("capture")
	elif "--record-gameplay" in OS.get_cmdline_user_args():
		call_deferred("record_gameplay")

func load_sounds() -> void:
	engine_clip = wave(0,.5,true)
	prop_clip = wave(1,.4,true)
	gun_clip = wave(2,.2,false)
	hit_clip = wave(3,.65,false)
	hiss_clip = wave(4,.46,false)
	scan_clip = wave(5,.2,false)

func wave(kind: int,seconds: float,looping: bool) -> AudioStreamWAV:
	var sample := AudioStreamWAV.new()
	var count := roundi(16000*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var random := RandomNumberGenerator.new()
	random.seed = 280+kind
	for i in count:
		var t := i/16000.0
		var n := random.randf_range(-1,1)
		var sound := 0.0
		match kind:
			0: sound = sin(t*TAU*48)*.39+sin(t*TAU*96)*.21+sin(t*TAU*152)*.075+n*.018
			1: sound = sin(t*TAU*140)*.34+sin(t*TAU*280)*.22+sin(t*TAU*560)*.09+n*.02
			2: sound = exp(-t*27)*(n*.54+sin(TAU*t*(146-280*t))*.32)
			3: sound = exp(-t*10)*(n*.44+sin(TAU*t*(81-54*t))*.49)
			4: sound = n*sin(PI*t/seconds)*exp(-t*4)*.66
			5: sound = sin(TAU*t*(480+t*740))*exp(-t*12)*.42
		bytes.encode_s16(i*2,roundi(clampf(sound,-1,1)*32767))
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 16000
	sample.data = bytes
	if looping:
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sample.loop_end = count
	return sample

func audio_node(parent: Node3D,clip: AudioStreamWAV,db: float,span: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = clip
	audio.volume_db = db
	audio.max_distance = span
	audio.unit_size = 9.0
	parent.add_child(audio)
	return audio

func play_sound(clip: AudioStreamWAV,point: Vector3,db: float) -> void:
	var audio := audio_node(arena,clip,db,170)
	audio.position = point
	audio.finished.connect(audio.queue_free)
	audio.play()

func menu_camera() -> void:
	var start := road.pose(road.plan.start)
	camera.position = start*Vector3(17,9,-14)
	camera.look_at(road.at(road.plan.start+32)+Vector3.UP*1.6)

func apply_weather() -> void:
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var tint: Color = SKY[time_choice]
	if wet:
		tint = tint.lerp(Color("#5d6974"),.62)
	var clouds := ProceduralSkyMaterial.new()
	clouds.sky_top_color = tint.darkened(.37)
	clouds.sky_horizon_color = tint
	clouds.ground_horizon_color = tint
	clouds.ground_bottom_color = Color("#5b6255").lerp(tint,.38)
	sky.sky_material = clouds
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = tint.lightened(.28)
	env.ambient_light_energy = .52
	env.fog_enabled = true
	env.fog_light_color = tint
	env.fog_density = .008 if wet else .004 if time_choice==2 else .0021
	sunlight.rotation_degrees = Vector3(-44 if time_choice==0 else -17,-38,0)
	sunlight.light_color = Color.WHITE if time_choice==0 else Color("#ffd2a6") if time_choice==1 else Color("#b2c5ef")
	sunlight.light_energy = (1.20 if time_choice==0 else .99 if time_choice==1 else .22)*(.67 if wet else 1.0)
	Engine.max_fps = 30 if quality==0 else 60
	sunlight.shadow_enabled = quality>0
	sunlight.directional_shadow_max_distance = 115 if quality>1 else 64
	camera.far = [530,720,980][quality]
	if weather:
		weather.text = "Дождь" if wet else "Сухо"
		daylight.text = ["День","Закат","Ночь"][time_choice]
		quality_choice.text = ["Низкое","Среднее","Высокое"][quality]

func menu_card(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.content_margin_left = 19
	style.content_margin_right = 19
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func label(text: String,size_px: int) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size_px)
	return node

func button(parent: Control,text: String,action: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 43
	control.focus_mode = Control.FOCUS_NONE
	parent.add_child(control)
	control.pressed.connect(action)
	return control

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = Hud.new()
	root.add_child(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu = PanelContainer.new()
	root.add_child(menu)
	menu.position = Vector2(23,24)
	menu.custom_minimum_size.x = 362
	menu.add_theme_stylebox_override("panel",menu_card(Color("#142124e8")))
	var choices := VBoxContainer.new()
	menu.add_child(choices)
	choices.add_theme_constant_override("separation",8)
	var title := label("Р‑280",53)
	title.modulate = AMBER
	choices.add_child(title)
	choices.add_child(label("Северный участок · Сопровождение",16))
	button(choices,"МОГ  ·  начать рейс",start.bind("escort"))
	button(choices,"Hornet  ·  начать разведку",start.bind("recon"))
	choice = button(choices,"Машина · Hilux",func():
		van = not van
		choice.text = "Машина · Буханка" if van else "Машина · Hilux")
	gun_choice = button(choices,"Установка · "+LOADOUTS[0],func():
		profile = (profile+1)%LOADOUTS.size()
		gun_choice.text = "Установка · "+LOADOUTS[profile])
	var settings := HBoxContainer.new()
	choices.add_child(settings)
	daylight = button(settings,"День",func(): time_choice=(time_choice+1)%3; apply_weather())
	weather = button(settings,"Сухо",func(): wet=not wet; apply_weather())
	quality_choice = button(settings,"Среднее",func(): quality=(quality+1)%3; apply_weather())
	top = HBoxContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 13
	top.offset_right = -13
	top.offset_top = 9
	top.add_theme_constant_override("separation",8)
	button(top,"Меню",return_menu)
	button(top,"Планшет",toggle_map)
	notice = label("",15)
	notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color",AMBER)
	notice.add_theme_color_override("font_outline_color",Color("#1c2328"))
	notice.add_theme_constant_override("outline_size",5)
	top.add_child(notice)
	seat_button = button(top,"Стрелок",toggle_seat)
	camera_button = button(top,"Камера",toggle_camera)
	button(top,"Сброс",reset_role)
	status_panel = PanelContainer.new()
	root.add_child(status_panel)
	status_panel.position = Vector2(14,64)
	status_panel.add_theme_stylebox_override("panel",menu_card(Color("#142124d9")))
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var readout := VBoxContainer.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(readout)
	info = label("",15)
	readout.add_child(info)
	task = label("",14)
	task.modulate = AMBER
	readout.add_child(task)
	target_button = button(root,"Метка",action)
	target_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	target_button.offset_left = -113
	target_button.offset_right = -13
	target_button.offset_top = 24
	target_button.offset_bottom = 72
	top.hide()
	status_panel.hide()
	target_button.hide()

func start(which: String) -> void:
	dispose()
	role = which
	active = true
	time_run = 0
	battery = 1
	signal_strength = 1
	mark_until = 0
	yaw = 0
	pitch = .16
	recoil = 0
	seat = 0
	arena = Node3D.new()
	add_child(arena)
	var spawn := road.pose(road.plan.start,road.LANE)
	primary = truck(road.plan.start+34,1,0,0,true)
	for i in 9:
		var dir := 1.0 if i%3==0 else -1.0
		truck(road.plan.start+146+i*103 if dir>0 else 148+i*145,dir,i%4,i+1,false)
	for entry: Dictionary in road.plan.hazards:
		add_hazard(entry)
	if role=="escort":
		var data := Fleet.player(road,arena,spawn,van,profile)
		car = data.body
		turret = data.gun
		drivetrain = Dynamics.new()
		drivetrain.configure(car,van)
		car.body_entered.connect(on_collision)
		escort_motor = audio_node(car,engine_clip,-16,100)
		escort_motor.play()
		rig = car
	else:
		var data := Fleet.aircraft(arena)
		drone = data.body
		drone_skin = data.visual
		rotor = data.hub
		drone.transform = spawn.translated_local(Vector3(0,19,0))
		yaw = drone.rotation.y
		last_fix = drone.position
		drone_motor = audio_node(drone,prop_clip,-13,140)
		drone_motor.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
		drone_motor.play()
		rig = drone
	ai = Node3D.new()
	arena.add_child(ai)
	ai.transform = spawn
	if role=="recon":
		Fleet.hull(road,ai,van,profile)
		for x in [-.91,.91]:
			for z in [-1.51,1.51]:
				var wheel := Fleet.WHEEL.instantiate() as Node3D
				ai.add_child(wheel)
				wheel.position = Vector3(x,.36,z)
	else:
		ai.add_child(Fleet.HORNET.instantiate())
	menu.hide()
	top.show()
	status_panel.show()
	hud.controls_visible = true
	camera.position = rig.position+Vector3(0,3,-8)
	update_ui()

func truck(at: float,dir: float,kind: int,id: int,important: bool) -> Freight:
	var freight := Freight.new()
	freight.build(road,arena,at,dir,kind,id,important)
	freight.motor = audio_node(freight.root,engine_clip,-23,100)
	freight.brake_sound = hiss_clip
	freight.motor.play()
	convoy.append(freight)
	return freight

func add_hazard(record: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.set_collision_layer_value(1,true)
	body.set_meta("hazard",hazards.size())
	arena.add_child(body)
	body.position = road.at(record.distance,record.side*8.4)
	body.position.y = .29
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.45,1.63,1.5)
	collider.shape = shape
	collider.position.y = .79
	body.add_child(collider)
	road.block(body,Vector3(0,.27,0),Vector3(1.6,.49,1.62),Color("#373d3d"))
	road.block(body,Vector3(0,1.1,0),Vector3(1.08,.81,1.09),Color("#5a5f5a"))
	var lamp := road.block(body,Vector3(0,1.48,0),Vector3(.44,.33,.47),Color("#ed6b38"))
	var emission := road.mat(Color("#ed6b38"))
	emission.emission_enabled = true
	emission.emission = Color("#cc3514")
	lamp.material_override = emission
	hazards.append({"root":body,"at":float(record.distance),"hp":1.0,"mark":false,"volley":0.0,"intercept":0.0})

func dispose() -> void:
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	convoy.clear()
	hazards.clear()
	shots.clear()
	car = null
	drone = null
	rig = null
	drivetrain = null
	arena = null
	primary = null
	active = false
	map_visible = false
	reset_input()

func reset_input() -> void:
	left_id = -1
	look_id = -1
	lift_id = -1
	left = Vector2.ZERO
	look_touch = Vector2.ZERO
	lift = 0

func reset_role() -> void:
	if not role.is_empty():
		start(role)

func return_menu() -> void:
	dispose()
	role = ""
	top.hide()
	status_panel.hide()
	target_button.hide()
	menu.show()
	hud.controls_visible = false
	hud.visible_reticle = false
	hud.gun_reticle = false
	hud.tablet = false
	hud.queue_redraw()
	menu_camera()

func toggle_map() -> void:
	if active:
		map_visible = not map_visible
		reset_input()

func toggle_seat() -> void:
	if active and car:
		seat = 0 if seat==2 else 2
		yaw = 0
		pitch = .04 if seat==2 else .16

func toggle_camera() -> void:
	if active and rig:
		seat = 1 if seat==0 else 0
		yaw = 0
		pitch = .16

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB: toggle_map()
			KEY_V: toggle_camera()
			KEY_C: toggle_seat()
			KEY_F: action()
			KEY_R: reset_role()
			KEY_ESCAPE:
				if map_visible: toggle_map()
				else: return_menu()
	if map_visible:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x*.005
		pitch = clampf(pitch+event.relative.y*.004,-.65,.75)
	elif event is InputEventScreenTouch:
		var screen := get_viewport().get_visible_rect().size
		var p: Vector2 = event.position
		if event.pressed and p.y>screen.y*.61:
			if p.x>screen.x*.81:
				lift_id = event.index
				lift = -1 if p.y>screen.y*.82 else 1
			elif p.x<screen.x*.49 and left_id==-1:
				left_id = event.index
				origin_left = p
			elif p.x>=screen.x*.49 and look_id==-1:
				look_id = event.index
				origin_look = p
		elif not event.pressed:
			if event.index == left_id:
				left_id = -1
				left = Vector2.ZERO
			if event.index == look_id:
				look_id = -1
				look_touch = Vector2.ZERO
			if event.index == lift_id:
				lift_id = -1
				lift = 0
	elif event is InputEventScreenDrag:
		if event.index == left_id:
			left = ((event.position-origin_left)/62.0).limit_length()
		if event.index == look_id:
			look_touch = ((event.position-origin_look)/62.0).limit_length()

func axis(negative: Key,positive: Key) -> float:
	return float(Input.is_physical_key_pressed(positive))-float(Input.is_physical_key_pressed(negative))

func _physics_process(dt: float) -> void:
	if not active or not rig:
		return
	time_run += dt
	cooldown = maxf(0,cooldown-dt)
	var movement := Vector2.ZERO
	var aim := Vector2.ZERO
	if not map_visible:
		movement = (left+Vector2(axis(KEY_A,KEY_D),axis(KEY_W,KEY_S))).limit_length()
		aim = (look_touch+Vector2(axis(KEY_LEFT,KEY_RIGHT),axis(KEY_UP,KEY_DOWN))).limit_length()
	yaw = wrapf(yaw-aim.x*dt*1.65,-PI,PI)
	pitch = clampf(pitch+aim.y*dt*1.25,-.65,.75)
	recoil *= exp(-dt*14)
	if car:
		drivetrain.step(dt,movement if seat!=2 else Vector2.ZERO,seat==2 or lift<0 or Input.is_physical_key_pressed(KEY_SPACE),road,wet)
		turret.rotation.y = yaw if seat==2 else 0.0
		escort_motor.pitch_scale = .76+minf(drivetrain.speed_kmh/110,.61)
	elif drone:
		step_drone(dt,movement)
	step_shots(dt)
	step_traffic(dt)
	hud.left_stick = movement
	hud.right_stick = aim

func ray(start_at: Vector3,end_at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start_at,end_at)
	if rig is CollisionObject3D:
		query.exclude = [rig.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func step_drone(dt: float,move: Vector2) -> void:
	var relay := ai.position+Vector3.UP*3.0
	var desired := 1.0-smoothstep(280,640,drone.position.distance_to(relay))
	if not ray(drone.position,relay).is_empty():
		desired *= .10
	signal_strength = move_toward(signal_strength,desired,dt*.94)
	if signal_strength>.34:
		last_fix = drone.position
	var local := Vector3(-move.x*11,(lift+axis(KEY_Q,KEY_E))*6,-move.y*27)
	var target_velocity := Basis(Vector3.UP,yaw)*local
	if signal_strength<.13 or battery<.04:
		var point := last_fix.move_toward(relay,30)+Vector3.UP*11
		target_velocity = ((point-drone.position)*1.13).limit_length(21)
		if target_velocity.length()>2:
			yaw = lerp_angle(yaw,atan2(target_velocity.x,target_velocity.z),dt*2.1)
	if drone.position.y<4.0:
		target_velocity.y = maxf(2.8,target_velocity.y)
	if drone.position.y>116:
		target_velocity.y = minf(-2,target_velocity.y)
	if battery<=0:
		target_velocity = Vector3.DOWN*2.6
	var wind := Vector3(2.6+sin(time_run*.72)*1.2,.12,.47) if wet else Vector3(.31,0,.16)
	drone.velocity = drone.velocity.move_toward(target_velocity+wind,dt*9.0)
	drone.rotation.y = yaw
	drone.move_and_slide()
	battery = maxf(0,battery-dt*(.0012+target_velocity.length()*.000044))
	drone_skin.rotation.x = lerpf(drone_skin.rotation.x,local.z*.008,dt*5)
	drone_skin.rotation.z = lerpf(drone_skin.rotation.z,-local.x*.022,dt*5)
	rotor.rotate_z(dt*52)
	drone_motor.pitch_scale = .77+minf(.55,drone.velocity.length()/60)

func step_traffic(dt: float) -> void:
	var upcoming := {}
	for hazard in hazards:
		if hazard.hp>0 and hazard.at+17>=primary.distance:
			upcoming = hazard
			break
	for freight in convoy:
		var gap := INF
		for other in convoy:
			gap = minf(gap,freight.gap_to(other))
		if freight==primary and not upcoming.is_empty():
			gap = minf(gap,upcoming.at+22-primary.distance)
		freight.step(dt,gap,wet)
	if role=="recon":
		ai.transform = road.pose(primary.distance-21,road.LANE)
		if not upcoming.is_empty() and upcoming.mark and signal_strength>.18 and upcoming.at-primary.distance<65 and time_run>=upcoming.intercept:
			upcoming.intercept = time_run+.70
			var from := ai.position+Vector3.UP*2.0
			var to: Vector3 = upcoming.root.position+Vector3.UP
			var visible := ray(from,to)
			if visible.is_empty() or visible.collider==upcoming.root:
				trace(from,to,AMBER)
				play_sound(gun_clip,from,-18)
				damage_hazard(upcoming,.34)
	else:
		var ahead := road.pose(primary.distance+42)
		ai.transform = ahead.translated_local(Vector3(0,19,0))
		linked_scout = ai.position.distance_to(car.position)<250 and ray(ai.position,car.position+Vector3.UP*1.8).is_empty()
		if linked_scout and not upcoming.is_empty() and not upcoming.mark and upcoming.at-primary.distance<105:
			var target: Vector3 = upcoming.root.position+Vector3.UP
			var block := ray(ai.position,target)
			if block.is_empty() or block.collider==upcoming.root:
				upcoming.mark = true
				tell("Hornet передал метку")
	for hazard in hazards:
		if hazard.hp<=0 or absf(hazard.at-primary.distance)>25 or time_run<hazard.volley:
			continue
		hazard.volley = time_run+7.0
		var point := primary.root.position+Vector3.UP*1.25
		trace(hazard.root.position+Vector3.UP,point,Color("#ff6348"))
		burst(point)
		primary.damage("cab",.135)
		alert_traffic(point)
	if primary.lost():
		outcome(false)
	elif primary.distance>=road.plan.finish:
		outcome(true)

func tell(text: String) -> void:
	notice.text = text
	mark_until = time_run+2.55

func alert_traffic(point: Vector3) -> void:
	for item in convoy:
		if not item.priority and item.root.position.distance_squared_to(point)<70*70:
			item.alert = 3.2

func on_collision(body: Node) -> void:
	if not active or not body.has_meta("freight") or cooldown>.30:
		return
	var speed := car.linear_velocity.length()
	if speed>5:
		var truck_hit: Freight = body.get_meta("freight")
		truck_hit.damage(body.get_meta("zone","cab"),clampf(speed/43.0,.08,.38))
		cooldown = .45
		play_sound(hit_clip,car.position,-15)

func damage_hazard(target: Dictionary,amount: float) -> void:
	target.hp = maxf(0,target.hp-amount)
	if target.hp>0:
		return
	var where: Vector3 = target.root.position+Vector3.UP
	burst(where)
	target.root.queue_free()
	alert_traffic(where)
	tell("Участок открыт")

func action() -> void:
	if not active or map_visible or cooldown>0:
		return
	if drone:
		cooldown = .70
		if signal_strength<.18:
			tell("Связь с МОГ потеряна")
			return
		var s := get_viewport().get_visible_rect().size
		var reticle := s*.5+Vector2(0,hud.cross_y*76)
		var radius := s.y*.21
		var best := {}
		for target in hazards:
			if target.hp<=0 or target.mark: continue
			var v: Vector3 = target.root.position+Vector3.UP
			if camera.is_position_behind(v) or drone.position.distance_to(v)>300: continue
			var gap := reticle.distance_to(camera.unproject_position(v))
			if gap>=radius: continue
			var occluded := ray(drone.position,v)
			if not occluded.is_empty() and occluded.collider!=target.root: continue
			best = target
			radius = gap
		if best.is_empty():
			tell("Наведи камеру на оранжевый маяк")
		else:
			best.mark = true
			play_sound(scan_clip,drone.position,-5)
			tell("Метка передана экипажу")
	elif car and seat==2:
		cooldown = [.12,.24,.37][profile]
		recoil = 1.0
		var from := camera.position
		var target := from-camera.global_basis.z*135
		var muzzle := turret.to_global(Vector3(0,.84,1.15))
		var correction := ray(from,target)
		if not correction.is_empty():
			target = correction.position
		var direction := (target-muzzle).normalized()
		shots.append({"p":muzzle,"v":direction*92.0+Vector3.UP*1.25,"ttl":1.5,"strength":[.21,.34,.5][profile],"trace_at":time_run})
		play_sound(gun_clip,muzzle,-9)
		alert_traffic(muzzle)

func step_shots(dt: float) -> void:
	for i in range(shots.size()-1,-1,-1):
		var shot := shots[i]
		var from: Vector3 = shot.p
		var target: Vector3 = from+shot.v*dt
		var impact := ray(from,target)
		if not impact.is_empty():
			trace(from,impact.position,AMBER)
			var hit_node: Node3D = impact.collider
			var point: Vector3 = hit_node.to_local(impact.position)
			if hit_node.has_meta("hazard"):
				var entry: Dictionary = hazards[int(hit_node.get_meta("hazard"))]
				if entry.hp>0.0:
					damage_hazard(entry,shot.strength*lerpf(.66,1.0,clampf(shot.ttl/.93,0,1)))
			elif hit_node.has_meta("freight"):
				var hit_truck: Freight = hit_node.get_meta("freight")
				var zone: String = hit_node.get_meta("zone","cab")
				if point.y<.61:
					zone="tire"
				elif hit_truck.rigid and point.z<-.7:
					zone="load"
				hit_truck.damage(zone,shot.strength*(.29 if zone=="load" else .41))
			shots.remove_at(i)
			continue
		if time_run>=shot.trace_at:
			trace(from,target,AMBER)
			shot.trace_at = time_run+.05
		shot.p = target
		shot.v = (shot.v+Vector3.DOWN*(3.3*dt))*(1.0-.07*dt)
		shot.ttl -= dt
		if shot.ttl<=0:
			shots.remove_at(i)

func trace(from: Vector3,to: Vector3,color: Color) -> void:
	if from.distance_squared_to(to)<.01:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = .021
	mesh.bottom_radius = .021
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 4
	mesh.rings = 1
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(visual)
	visual.position = from.lerp(to,.5)
	visual.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
	get_tree().create_timer(.07).timeout.connect(visual.queue_free)

func burst(point: Vector3) -> void:
	var p := OmniLight3D.new()
	p.light_color = Color("#ffaf66")
	p.light_energy = 3.1
	p.omni_range = 10
	arena.add_child(p)
	p.position = point
	get_tree().create_timer(.095).timeout.connect(p.queue_free)
	play_sound(hit_clip,point,-9)
	var smoke: CPUParticles3D = primary.emitter(arena,point,false)
	smoke.one_shot = true
	smoke.amount = 13
	smoke.explosiveness = 1
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)

func outcome(success: bool) -> void:
	active = false
	map_visible = false
	reset_input()
	if car:
		car.brake = 55
		car.engine_force = 0
	tell("Груз доставлен" if success else "Рейс сорван")
	update_ui()

func _process(dt: float) -> void:
	if not active or not rig:
		return
	var forward := rig.global_basis.z.rotated(Vector3.UP,yaw if car else 0.0)
	var look := (forward*cos(pitch)-Vector3.UP*sin(pitch-recoil*.07)).normalized()
	if drone:
		drone_skin.visible = seat==1
		if seat==1:
			var p := drone.position-forward*6.8+Vector3.UP*2.35
			camera.position = camera.position.lerp(p,1.0-exp(-dt*9.0))
			camera.look_at(drone.position)
		else:
			camera.position = drone.position+forward*.78
			camera.look_at(camera.position+look)
	elif seat==0:
		var focus := car.position+Vector3.UP*1.15
		var wanted := focus-forward*7.75+Vector3.UP*(2.23+pitch*2.4)
		var occlusion := ray(focus,wanted)
		if not occlusion.is_empty():
			wanted = occlusion.position+occlusion.normal*.23
		camera.position = camera.position.lerp(wanted,1.0-exp(-dt*8.5))
		camera.look_at(focus)
	else:
		camera.position = turret.global_position+Vector3.UP*.97-forward*.46 if seat==2 else car.to_global(Vector3(-.33,1.13,1.05))
		camera.look_at(camera.position+look)
	if time_run>mark_until:
		notice.text = ""
	update_ui()

func update_ui() -> void:
	hud.controls_visible = active and not map_visible
	hud.visible_reticle = active and drone!=null and seat==0 and not map_visible
	hud.gun_reticle = active and car!=null and seat==2 and not map_visible
	hud.cross_y = clampf((pitch-.16)*1.26,-.92,.92)
	hud.tablet = map_visible
	hud.role = role
	target_button.visible = active and not map_visible and (drone!=null or seat==2)
	target_button.text = "Метка" if drone else "Огонь"
	seat_button.visible = car!=null
	seat_button.text = "Водитель" if seat==2 else "Стрелок"
	if not primary:
		return
	var health := roundi(minf(primary.cabin_health,primary.load_health)*100)
	var speed := roundi(drone.velocity.length()*3.6) if drone else roundi(car.linear_velocity.length()*3.6)
	if drone:
		info.text = "%d км/ч  ·  связь %d%%  ·  АКБ %d%%" % [speed,roundi(signal_strength*100),roundi(battery*100)]
	else:
		var surfaces := {"GRASS":"грунт","GRAVEL":"гравий","ASPHALT":"асфальт"}
		info.text = "%d км/ч  ·  %s  ·  фура %d%%" % [speed,surfaces.get(drivetrain.surface,"грунт"),health]
	var next_place := "Финиш"
	for place: Dictionary in road.plan.landmarks:
		if place.distance>primary.distance:
			next_place = place.label
			break
	if not active:
		task.text = "Груз доставлен" if not primary.lost() else "Рейс сорван"
	else:
		task.text = "Возврат к точке связи" if drone and signal_strength<.13 else next_place
	if map_visible:
		var truck_dots := PackedVector3Array()
		var hazard_dots := PackedVector3Array()
		var has_link := not drone or signal_strength>.18
		if has_link:
			for vehicle in convoy: truck_dots.append(vehicle.root.position)
			for hazard in hazards:
				if hazard.hp>0 and hazard.mark and (drone or linked_scout):
					hazard_dots.append(hazard.root.position)
		hud.map_points = road.points
		hud.trucks = truck_dots
		hud.hazards = hazard_dots
		hud.escort = ai.position if drone else car.position
		hud.aircraft = drone.position if drone else ai.position
		hud.map_info = "Кабина %d%%\nКузов %d%%\nШины %d%%" % [roundi(primary.cabin_health*100),roundi(primary.load_health*100),roundi(primary.tire_health*100)] if has_link else "Сигнал потерян"
		hud.map_progress = "%d / %d м" % [roundi(primary.distance-road.plan.start),roundi(road.plan.finish-road.plan.start)]
	hud.queue_redraw()

func smoke_test() -> void:
	start("escort")
	for i in 55: await get_tree().physics_frame
	left = Vector2.UP
	for i in 170: await get_tree().physics_frame
	var speed := car.linear_velocity.length()
	print("R280 pickup speed ",speed,"; wheels ",drivetrain.contact_count,"; trucks ",convoy.size(),"; surface ",drivetrain.surface,"; displaced ",car.position.distance_to(road.at(road.plan.start,road.LANE)))
	if speed<1 or drivetrain.contact_count<2 or convoy.size()!=10 or drivetrain.surface!="ASPHALT":
		push_error("Vehicle dynamics or traffic failed")
		get_tree().quit(1)
		return
	toggle_seat()
	var part: Freight = convoy[1]
	part.damage("tire",.61)
	part.damage("load",.68)
	if seat!=2 or part.tire_health>=.45 or not part.smoke.emitting:
		push_error("Gunner selection or separate damage failed")
		get_tree().quit(1)
		return
	start("recon")
	for i in 10: await get_tree().physics_frame
	var airplane := drone.position
	left=Vector2.UP
	for i in 92: await get_tree().physics_frame
	if drone.position.distance_to(airplane)<3 or signal_strength<.5:
		push_error("Drone motion or initial link failed")
		get_tree().quit(1)
		return
	drone.position = Vector3(710,75,-550)
	for i in 88: await get_tree().physics_frame
	if signal_strength>.23:
		push_error("Drone signal-loss handling failed")
		get_tree().quit(1)
		return
	toggle_map()
	update_ui()
	if hud.map_info!="Сигнал потерян":
		push_error("Disconnected tablet leaked telemetry")
		get_tree().quit(1)
		return
	for hazard in hazards:
		damage_hazard(hazard,1)
	primary.distance = road.plan.finish+1
	await get_tree().physics_frame
	await get_tree().process_frame
	if active or task.text!="Груз доставлен":
		push_error("Finish condition failed")
		get_tree().quit(1)
		return
	print("R280 role initialization smoke test complete")
	dispose()
	await get_tree().process_frame
	get_tree().quit()

func save_frame(folder: String,name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join(name))

func capture() -> void:
	var folder := ProjectSettings.globalize_path("res://build/previews")
	DirAccess.make_dir_recursive_absolute(folder)
	await get_tree().create_timer(.7).timeout
	await save_frame(folder,"01-menu.png")
	start("escort")
	left=Vector2.UP
	await get_tree().create_timer(2.0).timeout
	left=Vector2.ZERO
	await save_frame(folder,"02-mog.png")
	start("recon")
	drone.position=road.at(road.plan.start+105)+Vector3.UP*23
	await get_tree().create_timer(.7).timeout
	await save_frame(folder,"03-hornet-fpv.png")
	toggle_camera()
	await get_tree().create_timer(.7).timeout
	await save_frame(folder,"04-hornet.png")
	toggle_map()
	await get_tree().create_timer(.2).timeout
	await save_frame(folder,"05-tablet.png")
	get_tree().quit()


func record_gameplay() -> void:
	start("escort")
	left = Vector2.UP*.77
	await get_tree().create_timer(3.1).timeout
	start("recon")
	drone.position = road.at(road.plan.start+90)+Vector3.UP*21
	left=Vector2.UP*.58
	await get_tree().create_timer(1.65).timeout
	toggle_camera()
	await get_tree().create_timer(1.5).timeout
	toggle_map()
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()
