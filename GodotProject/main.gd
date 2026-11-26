extends Node3D

const Hud := preload("res://hud.gd")
const Terrain := preload("res://terrain.gd")
const VehicleDynamics := preload("res://vehicle_dynamics.gd")
var dynamics: VehicleDynamics
var landscape: Terrain
var role := ""
var vehicle: Node3D
var car: VehicleBody3D
var drone: CharacterBody3D
var camera: Camera3D
var menu: VBoxContainer
var panel: HBoxContainer
var status: Label
var hud: Hud
var world: Node3D
var sun: DirectionalLight3D
var left := Vector2.ZERO
var right := Vector2.ZERO
var touch_left := -1
var touch_right := -1
var touch_brake := -1
var origin_left := Vector2.ZERO
var origin_right := Vector2.ZERO
var brake := false
var seat := 0
var yaw := 0.0
var pitch := 0.0
var throttle := 0.5
var flight_speed := 10.0
var steering := 0.0
var sensitivity := 1.0
var is_paused := false
var paint := Color("#515d43")
var dark := Color("#262b2b")
var glass := Color("#54737d")

func _ready() -> void:
	Engine.max_fps = 30
	world = Node3D.new()
	add_child(world)
	make_world()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.far = 1050
	camera.position = Vector3(12, 8, -20)
	camera.look_at(Vector3(0, 1, 0))
	make_ui()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	elif "--screenshots" in OS.get_cmdline_user_args():
		call_deferred("capture_previews")

func smoke_test() -> void:
	spawn("Pickup")
	for i in range(45):
		await get_tree().physics_frame
	left=Vector2(0,-1)
	for i in range(100):
		await get_tree().physics_frame
	print("R280 pickup test speed: ", car.linear_velocity.length(), " contacts: ", dynamics.contact_count)
	if not is_finite(car.linear_velocity.length()) or dynamics.contact_count==0 or car.linear_velocity.length()<0.25:
		push_error("R280 vehicle motion smoke test failed")
		get_tree().quit(1)
		return
	left=Vector2.ZERO
	spawn("Van")
	await get_tree().physics_frame
	spawn("Flight")
	await get_tree().physics_frame
	print("R280 role initialization smoke test complete")
	get_tree().quit()

func capture_previews() -> void:
	var folder := ProjectSettings.globalize_path("res://build/previews")
	DirAccess.make_dir_recursive_absolute(folder)
	spawn("Pickup")
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("01-road.png"))
	spawn("Flight")
	drone.position=Vector3(80,48,-70)
	drone.rotation.y=-0.4
	seat=1
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("02-landscape.png"))
	return_menu()
	menu.hide()
	camera.position=Vector3(132,45,36)
	camera.look_at(Vector3(110,0,80))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("03-village.png"))
	get_tree().quit()

func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, c: Color, collision := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat(c)
	parent.add_child(vis)
	vis.position = pos
	if collision:
		var shape := BoxShape3D.new()
		shape.size = dimensions
		var col := CollisionShape3D.new()
		col.shape = shape
		parent.add_child(col)
		col.position = pos
	return vis

func ground_box(pos: Vector3, dimensions: Vector3, c: Color) -> void:
	var body := StaticBody3D.new()
	world.add_child(body)
	box(body, pos, dimensions, c, true)

func make_world() -> void:
	landscape = Terrain.new()
	world.add_child(landscape)
	landscape.build()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("#547d9e")
	sky_mat.sky_horizon_color=Color("#b8c6cd")
	sky_mat.ground_horizon_color=Color("#b8c6cd")
	sky_mat.ground_bottom_color=Color("#666e64")
	sky.sky_material=sky_mat
	env.sky=sky
	env.fog_enabled=true
	env.fog_light_color=Color("#aab9c2")
	env.fog_density=0.0015
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a7b2bd")
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = Hud.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = VBoxContainer.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -190
	menu.offset_right = 190
	menu.offset_top = -150
	menu.offset_bottom = 150
	menu.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "R-280 / FIELD PROTOTYPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	menu.add_child(title)
	for option in ["Pickup", "Van", "Flight"]:
		var label: String = {"Pickup":"MOG / Pickup", "Van":"MOG / Utility van", "Flight":"UAV / Hornet prototype"}[option]
		add_button(menu,label,spawn.bind(option))
	var note := Label.new()
	note.text = "Stage 03 · vehicle physics"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(note)
	add_button(menu,"VOXEL LAB",func(): get_tree().change_scene_to_file("res://sandbox.tscn"))
	panel = HBoxContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = 8
	panel.add_theme_constant_override("separation", 8)
	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(status)
	add_button(panel,"VIEW",change_view)
	add_button(panel,"RESET",reset_vehicle)
	add_button(panel,"30/60 FPS",change_quality)
	add_button(panel,"PAUSE",toggle_pause)
	add_button(panel,"MENU",return_menu)
	panel.hide()

func add_button(parent: Control, label: String, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(76,46)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	b.pressed.connect(action)

func spawn(which: String) -> void:
	clear_vehicle()
	role = which
	seat = 0
	yaw = 0
	pitch = 0
	throttle = 0.5
	flight_speed = 10
	steering = 0
	is_paused = false
	if which == "Flight":
		drone = CharacterBody3D.new()
		drone.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		add_child(drone)
		drone.position = Vector3(0,20,-100)
		box(drone,Vector3.ZERO,Vector3(0.5,0.35,2.5),dark,true)
		box(drone,Vector3(0,0,-0.15),Vector3(3.2,0.08,0.65),dark)
		box(drone,Vector3(0,0.12,-1.05),Vector3(1.1,0.08,0.35),dark)
		box(drone,Vector3(0,0.33,-1.05),Vector3(0.08,0.5,0.35),dark)
		vehicle = drone
	else:
		car = VehicleBody3D.new()
		add_child(car)
		car.mass = 1700
		car.position = Vector3(2,0.85,-30)
		car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		car.center_of_mass = Vector3(0,-0.25,0)
		box(car,Vector3.ZERO,Vector3(1.9,0.55,4.7),paint,true)
		var van := which == "Van"
		box(car,Vector3(0,0.65,0.8),Vector3(1.8,1.1,2.2 if van else 1.6),paint,true)
		box(car,Vector3(0,0.75,1.91 if van else 1.61),Vector3(1.65,0.55,0.05),glass)
		box(car,Vector3(0,0.38,-1.4),Vector3(1.8,0.18,1.7),dark)
		for side in [-1,1]:
			box(car,Vector3(side*0.88,0.6,-1.4),Vector3(0.1,0.4,1.7),paint)
		for i in range(4):
			var wheel := VehicleWheel3D.new()
			car.add_child(wheel)
			wheel.position = Vector3(-0.98 if i%2==0 else 0.98,-0.27,1.48 if i<2 else -1.48)
			wheel.wheel_radius = 0.43
			wheel.wheel_rest_length = 0.20
			wheel.suspension_travel = 0.24
			wheel.suspension_stiffness = 25
			wheel.damping_compression = 3
			wheel.damping_relaxation = 4
			wheel.suspension_max_force = 10000
			wheel.wheel_friction_slip = 2.0
			wheel.use_as_steering = i<2
			wheel.use_as_traction = true
			var vis := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.43
			cylinder.bottom_radius = 0.43
			cylinder.height = 0.26
			vis.mesh = cylinder
			vis.material_override = mat(dark)
			wheel.add_child(vis)
			vis.rotation.z = PI/2
		dynamics=VehicleDynamics.new()
		dynamics.configure(car,van)
		vehicle = car
	menu.hide()
	panel.show()
	hud.controls_visible = true

func clear_vehicle() -> void:
	if is_instance_valid(vehicle):
		remove_child(vehicle)
		vehicle.queue_free()
	vehicle = null
	car = null
	dynamics = null
	drone = null
	left = Vector2.ZERO
	right = Vector2.ZERO
	touch_left = -1
	touch_right = -1
	touch_brake = -1
	brake = false

func change_view() -> void:
	seat = (seat+1) % (2 if role=="Flight" else 4)
	yaw = 0
	pitch = 0

func reset_vehicle() -> void:
	spawn(role)

func return_menu() -> void:
	clear_vehicle()
	role = ""
	is_paused = false
	menu.show()
	panel.hide()
	hud.controls_visible = false
	hud.visible_reticle = false
	hud.queue_redraw()
	camera.position = Vector3(12,8,-20)
	camera.look_at(Vector3(0,1,0))

func change_quality() -> void:
	Engine.max_fps = 60 if Engine.max_fps == 30 else 30
	sun.shadow_enabled = Engine.max_fps == 30

func toggle_pause() -> void:
	is_paused = not is_paused
	if is_instance_valid(car):
		car.freeze = is_paused
	left = Vector2.ZERO
	right = Vector2.ZERO
	touch_left = -1
	touch_right = -1
	touch_brake = -1
	brake = false

func _unhandled_input(event: InputEvent) -> void:
	if role == "" or is_paused:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		var s := get_viewport().get_visible_rect().size
		if event.pressed and p.y > s.y*0.4:
			if abs(p.x-s.x*0.5)<s.x*0.09 and p.y>s.y*0.73:
				touch_brake = event.index
				brake = true
			elif p.x < s.x*0.5 and touch_left == -1:
				touch_left = event.index
				origin_left = p
			elif p.x >= s.x*0.5 and touch_right == -1:
				touch_right = event.index
				origin_right = p
		elif not event.pressed:
			if event.index == touch_left:
				touch_left = -1
				left = Vector2.ZERO
			if event.index == touch_right:
				touch_right = -1
				right = Vector2.ZERO
			if event.index == touch_brake:
				touch_brake = -1
				brake = false
	elif event is InputEventScreenDrag:
		if event.index == touch_left:
			left = ((event.position-origin_left)/75.0).limit_length()
		if event.index == touch_right:
			right = ((event.position-origin_right)/75.0).limit_length()

func _physics_process(dt: float) -> void:
	if role == "" or is_paused or not is_instance_valid(vehicle):
		return
	var move := left
	var look := right
	if not OS.has_feature("mobile"):
		move += Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		look += Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
	move = move.limit_length()
	look = look.limit_length()
	var stopping := brake or Input.is_physical_key_pressed(KEY_SPACE)
	if role == "Flight":
		# Fictional, unarmed flight sandbox. Not calibrated to a real aircraft.
		throttle = clampf(throttle - move.y*dt*0.45,0,1)
		flight_speed = move_toward(flight_speed,0.0 if stopping else 8+throttle*16,dt*5)
		drone.rotation.y -= move.x*dt*0.7
		drone.rotation.x = move_toward(drone.rotation.x,look.y*0.28,dt*0.75)
		drone.rotation.z = move_toward(drone.rotation.z,-move.x*0.35,dt*0.9)
		drone.velocity = drone.global_transform.basis.z*flight_speed
		drone.move_and_slide()
		hud.cross_y = move_toward(hud.cross_y,look.y,dt*2)
		if absf(drone.position.x)>495 or absf(drone.position.z)>495 or drone.position.y < -25:
			reset_vehicle()
	else:
		dynamics.step(dt,move,stopping,landscape)
		yaw = clampf(yaw-look.x*dt*1.3*sensitivity,-1.7,1.7)
		pitch = clampf(pitch-look.y*dt*sensitivity,-0.5,0.6)
		if absf(car.position.x)>495 or absf(car.position.z)>495 or car.position.y < -25:
			reset_vehicle()
	hud.left_stick = move
	hud.right_stick = look

func _process(dt: float) -> void:
	if role == "" or not is_instance_valid(vehicle):
		return
	hud.visible_reticle = role=="Flight" and seat==0
	if role!="Flight" and dynamics!=null:
		hud.drive_info="%s  |  %s  |  %d/4 wheels" % [("R" if dynamics.gear<0 else "N" if dynamics.gear==0 else str(dynamics.gear)),dynamics.surface,dynamics.contact_count]
	else:
		hud.drive_info=""
	hud.queue_redraw()
	var speed := drone.velocity.length() if role=="Flight" else car.linear_velocity.length()
	status.text = "%s | %d km/h | %s | %d FPS%s" % [role,roundi(speed*3.6),landscape.surface_at(vehicle.position.x,vehicle.position.z) if role!="Flight" else ("%d m" % roundi(vehicle.position.y)),Engine.get_frames_per_second()," PAUSED" if is_paused else ""]
	if is_paused:
		return
	var t := vehicle.global_transform
	var heading := t.basis.z
	if role=="Flight" and seat==0:
		camera.global_position = t*Vector3(0,0.08,1.38)
		camera.look_at(camera.global_position+heading,t.basis.y)
	elif seat==0 or role=="Flight":
		var orbit := heading.rotated(Vector3.UP,yaw)
		var target := vehicle.position + Vector3.UP*1.0
		var desired := target-orbit*7+Vector3.UP*(2.3+pitch*3)
		camera.global_position = camera.global_position.lerp(desired,1-exp(-dt*9))
		camera.look_at(target)
	else:
		var offsets := [Vector3.ZERO,Vector3(-0.35,1.25,1.0),Vector3(0,1.7,-1.1),Vector3(0.35,1.25,0.9)]
		camera.global_position = t*offsets[seat]
		var direction := heading.rotated(Vector3.UP,yaw)+Vector3.UP*pitch
		camera.look_at(camera.global_position+direction)
