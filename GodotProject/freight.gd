extends RefCounted

const DARK := Color("#2b3131")
const GLASS := Color("#42616a")
const RUBBER := Color("#222626")
var road: Node3D
var root: AnimatableBody3D
var rear: AnimatableBody3D
var cargo: Node3D
var tires: Array[Node3D] = []
var cabin_health := 1.0
var load_health := 1.0
var tire_health := 1.0
var distance := 0.0
var direction := 1.0
var lane := 0.0
var speed := 0.0
var alert := 0.0
var cruise := 13.0
var roll := 0.0
var mass := 18000.0
var priority := false
var rigid := false
var smoke: CPUParticles3D
var flames: CPUParticles3D
var motor: AudioStreamPlayer3D
var brake_sound: AudioStreamWAV

func build(terrain: Node3D,parent: Node3D,at: float,dir: float,kind: int,id: int,important: bool) -> void:
	road = terrain
	distance = at
	direction = dir
	lane = direction*terrain.LANE
	priority = important
	cruise = 14.0 if priority else 11.0+(id%4)*1.8
	rigid = kind == 3
	mass = [14700.0,19700.0,29400.0,9200.0][kind]
	root = AnimatableBody3D.new()
	parent.add_child(root)
	root.set_meta("freight",self)
	root.set_meta("zone","cab")
	var cab: Color = [Color("#d0cfc1"),Color("#a25d44"),Color("#537786")][id%3]
	road.block(root,Vector3(0,.7,0),Vector3(1.96,.36,5.78),DARK)
	box_shape(root,Vector3(0,1.75,1.4),Vector3(2.43,2.43,2.3))
	road.block(root,Vector3(0,1.75,1.4),Vector3(2.43,2.43,2.3),cab)
	road.block(root,Vector3(0,2.41,2.574),Vector3(2.12,.62,.045),GLASS)
	road.block(root,Vector3(0,1.24,2.57),Vector3(1.63,.45,.10),DARK)
	road.block(root,Vector3(0,.85,2.62),Vector3(2.47,.23,.17),Color("#9da49f"))
	for side in [-1,1]:
		road.block(root,Vector3(side*1.228,2.39,1.54),Vector3(.045,.60,1.36),GLASS)
		road.block(root,Vector3(side*1.39,2.42,2.36),Vector3(.16,.39,.17),DARK)
		road.block(root,Vector3(side*.95,1.13,2.589),Vector3(.37,.22,.10),Color("#e6d4a3"))
	var carrier := root
	if not rigid:
		rear = AnimatableBody3D.new()
		parent.add_child(rear)
		rear.set_meta("freight",self)
		rear.set_meta("zone","load")
		carrier = rear
	cargo = Node3D.new()
	carrier.add_child(cargo)
	var z := -1.94 if rigid else -4.64
	var span := 4.25 if rigid else 9.24
	if rigid:
		box_shape(root,Vector3(0,1.93,z),Vector3(2.4,2.05,span))
	else:
		box_shape(rear,Vector3(0,1.93,z),Vector3(2.4,2.10,span))
		road.block(rear,Vector3(0,.76,z),Vector3(2.39,.22,span),DARK)
	if kind == 2:
		var tank := wheel_mesh(1.10,span*.98,Color("#c0c0b5"))
		cargo.add_child(tank)
		tank.position = Vector3(0,1.95,z)
		tank.rotation.x = PI*.5
		for j in [-1,0,1]:
			var band := wheel_mesh(1.12,.12,Color("#656f70"))
			cargo.add_child(band)
			band.position = Vector3(0,1.95,z+j*2.86)
			band.rotation.x = PI*.5
	else:
		var color := Color("#718481") if kind == 0 else Color("#d6d9d0")
		road.block(cargo,Vector3(0,1.99,z),Vector3(2.45,2.20,span),color)
		road.block(cargo,Vector3(0,3.10,z),Vector3(2.49,.09,span),Color("#abb1a7"))
		road.block(cargo,Vector3(0,2,z-span*.5-.029),Vector3(.075,2.07,.055),DARK)
		for j in 7:
			for side in [-1,1]:
				road.block(cargo,Vector3(side*1.225,1.97,z+(j/7.0-.42)*span),Vector3(.049,2.03,.056),color.darkened(.13))
		if kind == 1:
			road.block(cargo,Vector3(0,2.65,z+span*.5),Vector3(1.04,.53,.26),DARK)
	for x in [-.99,.99]:
		road.block(cargo,Vector3(x,.91,z-span*.5-.035),Vector3(.24,.18,.12),Color("#b64130"))
	for axle in [1.65,-1.30]:
		add_axle(root,axle)
	if rear:
		for axle in [-6.42,-7.62]:
			add_axle(rear,axle)
	transform_at()
	var fuel := Vector3(0,2.6,z)
	smoke = emitter(cargo,fuel,false)
	flames = emitter(cargo,fuel,true)

func add_axle(parent: Node3D,z: float) -> void:
	for x in [-1.08,1.08]:
		var axle := Node3D.new()
		parent.add_child(axle)
		axle.position = Vector3(x,.47,z)
		var tire := wheel_mesh(.47,.29,RUBBER)
		axle.add_child(tire)
		tire.rotation.z = PI*.5
		var hub := wheel_mesh(.248,.33,Color("#a1a8a1"))
		axle.add_child(hub)
		hub.rotation.z = PI*.5
		tires.append(axle)

func wheel_mesh(radius: float,width: float,color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 14
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = road.mat(color)
	return node

func box_shape(parent: CollisionObject3D,center: Vector3,dimensions: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	collider.position = center
	parent.add_child(collider)

func emitter(parent: Node3D,p: Vector3,fire: bool) -> CPUParticles3D:
	var effect := CPUParticles3D.new()
	var shape := SphereMesh.new()
	shape.radial_segments = 5
	shape.rings = 3
	shape.radius = .34 if fire else .78
	shape.height = shape.radius*2
	effect.mesh = shape
	effect.material_override = road.mat(Color("#ee7a31") if fire else Color("#484844"))
	effect.amount = 18
	effect.lifetime = .62 if fire else 2.5
	effect.direction = Vector3.UP
	effect.gravity = Vector3(.50,.31,0)
	effect.initial_velocity_min = 1.3
	effect.initial_velocity_max = 3.0
	effect.spread = 25
	effect.scale_amount_min = .4
	effect.scale_amount_max = 1.4
	effect.emitting = false
	parent.add_child(effect)
	effect.position = p
	return effect

func damage(zone: String,value: float) -> void:
	match zone:
		"load": load_health = clampf(load_health-value,0,1)
		"tire": tire_health = clampf(tire_health-value,0,1)
		_: cabin_health = clampf(cabin_health-value,0,1)
	alert = 3.0
	if minf(cabin_health,load_health)<.40:
		smoke.emitting = true
		flames.emitting = true

func lost() -> bool:
	return minf(cabin_health,load_health) <= 0.0

func gap_to(other) -> float:
	if other == self or direction != other.direction or absf(lane-other.lane)>1.2:
		return INF
	var gap: float = (other.distance-distance)*direction
	return gap if gap>=0.0 else INF

func transform_at() -> void:
	var t: Transform3D = road.pose(distance,lane,direction)
	root.transform = t
	if rear:
		var hitch := t*Vector3(0,0,-1.85)
		var rear_heading: Vector3 = hitch-road.at(distance-direction*8.6,lane)
		var direction_z := rear_heading.normalized() if rear_heading.length()>.4 else t.basis.z
		var x := Vector3.UP.cross(direction_z).normalized()
		var tire_basis := Basis(x,direction_z.cross(x),direction_z)
		rear.transform = Transform3D(tire_basis,hitch)
	cargo.rotation.z = roll

func step(dt: float,gap: float,wet: bool) -> void:
	alert = maxf(0.0,alert-dt)
	var pace := cruise
	var lane_target: float = road.LANE*direction
	if alert>0 or tire_health<.45 or lost():
		pace *= .27 if tire_health<.45 else .52
		lane_target = direction*4.62
	if lost():
		pace = 0.0
	elif gap<31:
		pace = minf(pace,maxf(0.0,(gap-12.0)*.52))
	elif gap<50 and alert<=0 and not priority:
		lane_target += direction*.60
	var previous_speed := speed
	speed = move_toward(speed,pace,dt*((2.8 if wet else 4.0) if speed>pace else 1.55*16000/mass))
	if motor:
		motor.pitch_scale = .62+speed*.032
		motor.volume_db = lerpf(-23,-12,clampf(speed/15.0,0,1))
		if brake_sound and previous_speed>8.0 and speed<8.0 and speed-previous_speed<-.03:
			var hiss := AudioStreamPlayer3D.new()
			hiss.stream = brake_sound
			hiss.volume_db = -15
			root.add_child(hiss)
			hiss.finished.connect(hiss.queue_free)
			hiss.play()
	lane = move_toward(lane,lane_target,dt*(.53 if wet else .83))
	distance += speed*direction*dt
	if not priority and (distance<19 or distance>road.length-19):
		distance = 25 if direction>0 else road.length-25
	var a: Vector3 = road.pose(distance-9).basis.z
	var b: Vector3 = road.pose(distance+9).basis.z
	var shift := clampf(a.cross(b).y*speed*.52,-.16,.16)*mass/29400.0
	roll = lerpf(roll,shift,1-exp(-dt*2))
	transform_at()
	for tire in tires:
		tire.rotate_x(speed*dt/.47)
