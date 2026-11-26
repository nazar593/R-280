extends Node3D

const CELL := 0.5
const MAX_DEBRIS := 48
var grid: GridMap
var player: CharacterBody3D
var camera: Camera3D
var debris: Array[RigidBody3D]=[]
var original: Dictionary={}
var removed := 0
var pending := false
var reset_pending := false
var movement := Vector2.ZERO
var move_id := -1
var look_id := -1
var move_origin := Vector2.ZERO
var pitch := 0.0
var status: Label
var palette: Array[Color]=[Color("#b1a28b"),Color("#776d60"),Color("#4d5844"),Color("#69503b"),Color("#aeb4b1")]
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	Engine.max_fps=30
	rng.seed=280
	make_world()
	make_player()
	make_ui()
	if "--voxel-test" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	elif "--voxel-previews" in OS.get_cmdline_user_args():
		call_deferred("previews")

func material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=0.9
	return m

func make_world() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	ground.position=Vector3(0,-0.3,0)
	var mesh := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size=Vector3(100,0.6,100)
	mesh.mesh=floor_mesh
	mesh.material_override=material(Color("#777d62"))
	ground.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=floor_mesh.size
	col.shape=shape
	ground.add_child(col)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees=Vector3(-48,-35,0)
	sun.shadow_enabled=true
	sun.light_energy=1.1
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#a6bbc9")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#b9c3d0")
	env.ambient_light_energy=0.7
	var we := WorldEnvironment.new()
	we.environment=env
	add_child(we)
	grid=GridMap.new()
	grid.cell_size=Vector3.ONE*CELL
	grid.cell_octant_size=8
	var library := MeshLibrary.new()
	for i in range(palette.size()):
		library.create_item(i)
		library.set_item_name(i,"Material "+str(i))
		var cube := BoxMesh.new()
		cube.size=Vector3.ONE*CELL
		cube.material=material(palette[i])
		library.set_item_mesh(i,cube)
		var cube_shape := BoxShape3D.new()
		cube_shape.size=Vector3.ONE*CELL
		library.set_item_shapes(i,[cube_shape,Transform3D.IDENTITY])
	grid.mesh_library=library
	add_child(grid)
	# Small fictional training-yard buildings with hollow interiors.
	build_shed(Vector3i(-8,0,-25),16,10,13)
	build_shed(Vector3i(13,0,-32),13,8,10)
	for x in range(-23,-13):
		for y in range(3):
			for z in range(-18,-14):
				put(Vector3i(x,y,z),2)
	for x in range(12,22):
		for y in range(2):
			put(Vector3i(x,y,-12),1)
	for x in range(-28,-24):
		for y in range(3):
			for z in range(-32,-28):
				put(Vector3i(x,y,z),3)
	status_update()

func put(cell: Vector3i,item: int) -> void:
	grid.set_cell_item(cell,item)
	original[cell]=item

func build_shed(o: Vector3i,w: int,h: int,d: int) -> void:
	for x in range(w):
		for z in range(d):
			put(o+Vector3i(x,0,z),1)
			put(o+Vector3i(x,h,z),2)
	for y in range(1,h):
		for x in range(w):
			for z in [0,d-1]:
				if z==d-1 and x>=w/2-2 and x<=w/2+1 and y<5:
					continue
				if y>=4 and y<=6 and x>=2 and x<=4:
					continue
				put(o+Vector3i(x,y,z),0 if (x+y)%5!=0 else 1)
		for z in range(1,d-1):
			for x in [0,w-1]:
				if y>=4 and y<=6 and z>=4 and z<=6:
					continue
				put(o+Vector3i(x,y,z),0)
	for x in range(w):
		put(o+Vector3i(x,h+1,0),2)
		put(o+Vector3i(x,h+1,d-1),2)

func make_player() -> void:
	player=CharacterBody3D.new()
	player.collision_layer=2
	player.collision_mask=1
	add_child(player)
	player.position=Vector3(0,1.1,1)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.33
	capsule.height=1.75
	col.shape=capsule
	player.add_child(col)
	camera=Camera3D.new()
	player.add_child(camera)
	camera.position.y=0.64
	camera.current=true
	camera.far=160
	camera.fov=76

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left=12
	top.offset_right=-12
	top.offset_top=10
	status=Label.new()
	status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(status)
	button(top,"RESET",func(): reset_pending=true)
	button(top,"DRIVE / FLY",func(): get_tree().change_scene_to_file("res://main.tscn"))
	var aim := Label.new()
	aim.text="+"
	aim.add_theme_font_size_override("font_size",28)
	aim.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	aim.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	root.add_child(aim)
	aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aim.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left=14
	bottom.offset_right=-14
	bottom.offset_top=-65
	bottom.offset_bottom=-12
	var hint := Label.new()
	hint.text="LEFT: WALK   •   RIGHT: LOOK"
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)
	button(bottom,"REMOVE BLOCKS",func(): pending=true)
	status_update()

func button(parent: Control,label: String,cb: Callable) -> void:
	var b := Button.new()
	b.text=label
	b.custom_minimum_size=Vector2(110,46)
	b.focus_mode=Control.FOCUS_NONE
	parent.add_child(b)
	b.pressed.connect(cb)

func status_update() -> void:
	if is_instance_valid(status):
		status.text="R-280 / VOXEL LAB    Removed: %d" % removed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var s := get_viewport().get_visible_rect().size
		if event.pressed and event.position.y>s.y*0.13:
			if event.position.x<s.x*0.5 and move_id==-1:
				move_id=event.index
				move_origin=event.position
			elif look_id==-1:
				look_id=event.index
		elif not event.pressed:
			if event.index==move_id:
				move_id=-1
				movement=Vector2.ZERO
			if event.index==look_id:
				look_id=-1
	elif event is InputEventScreenDrag:
		if event.index==move_id:
			movement=((event.position-move_origin)/75.0).limit_length()
		if event.index==look_id:
			turn(event.relative)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		turn(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F:
			pending=true
		if event.physical_keycode==KEY_R:
			reset_pending=true

func turn(delta: Vector2) -> void:
	player.rotation.y-=delta.x*0.004
	pitch=clampf(pitch-delta.y*0.004,-1.25,1.25)
	camera.rotation.x=pitch

func _physics_process(dt: float) -> void:
	var move := movement
	if not OS.has_feature("mobile"):
		move+=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	move=move.limit_length()
	var direction := player.transform.basis*Vector3(move.x,0,move.y)
	player.velocity.x=move_toward(player.velocity.x,direction.x*5,dt*24)
	player.velocity.z=move_toward(player.velocity.z,direction.z*5,dt*24)
	if not player.is_on_floor():
		player.velocity.y-=9.8*dt
	else:
		player.velocity.y=-0.2
	player.move_and_slide()
	if pending:
		pending=false
		remove_at_crosshair()
	if reset_pending:
		reset_pending=false
		reset_world()
	if player.position.y < -5 or absf(player.position.x)>48 or absf(player.position.z)>48:
		player.position=Vector3(0,1.1,1)
		player.velocity=Vector3.ZERO

func remove_at_crosshair() -> void:
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start,start-camera.global_transform.basis.z*12.0,1)
	query.exclude=[player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider")!=grid:
		return
	var point: Vector3=hit["position"]
	var normal: Vector3=hit["normal"]
	var cell := grid.local_to_map(grid.to_local(point-normal*0.06))
	erase_patch(cell)

func erase_patch(center: Vector3i) -> void:
	# A fictional editor-like eraser, not a real weapon or structural damage model.
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				var cell := center+Vector3i(x,y,z)
				var item := grid.get_cell_item(cell)
				if item<0:
					continue
				grid.set_cell_item(cell,-1)
				removed+=1
				if debris.size()<MAX_DEBRIS:
					spawn_debris(grid.to_global(grid.map_to_local(cell)),item)
	status_update()

func spawn_debris(pos: Vector3,item: int) -> void:
	var b := RigidBody3D.new()
	b.mass=0.8
	b.collision_layer=4
	b.collision_mask=1|4
	b.linear_damp=0.4
	b.angular_damp=0.8
	var vis := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size=Vector3.ONE*CELL*0.78
	vis.mesh=cube
	vis.material_override=material(palette[item])
	b.add_child(vis)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=cube.size
	col.shape=shape
	b.add_child(col)
	add_child(b)
	b.position=pos
	b.linear_velocity=Vector3(rng.randf_range(-0.9,0.9),rng.randf_range(0.2,1.0),rng.randf_range(-0.9,0.9))
	debris.append(b)
	get_tree().create_timer(10).timeout.connect(func():
		if is_instance_valid(b):
			debris.erase(b)
			b.queue_free())

func reset_world() -> void:
	for cell in original:
		grid.set_cell_item(cell,original[cell])
	for b in debris:
		if is_instance_valid(b):
			b.queue_free()
	debris.clear()
	removed=0
	status_update()

func smoke_test() -> void:
	await get_tree().physics_frame
	var before := grid.get_used_cells().size()
	erase_patch(Vector3i(-6,2,-13))
	await get_tree().physics_frame
	if removed<=0 or grid.get_used_cells().size()>=before or debris.is_empty():
		push_error("Voxel removal test failed")
		get_tree().quit(1)
		return
	reset_world()
	if grid.get_used_cells().size()!=before:
		push_error("Voxel restore test failed")
		get_tree().quit(1)
		return
	print("R280 voxel removal and restore smoke test complete")
	get_tree().quit()

func previews() -> void:
	var folder := ProjectSettings.globalize_path("res://build/previews")
	DirAccess.make_dir_recursive_absolute(folder)
	player.position=Vector3(-2,1.1,1)
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("voxel-before.png"))
	erase_patch(Vector3i(-4,3,-13))
	erase_patch(Vector3i(-3,5,-13))
	await get_tree().create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("voxel-after.png"))
	get_tree().quit()
