extends RefCounted

const TRACTOR := preload("res://art/fleet/tractor.glb")
const FREIGHT_BODY := [
	preload("res://art/fleet/trailer_curtain.glb"),
	preload("res://art/fleet/trailer_cold.glb"),
	preload("res://art/fleet/trailer_tank.glb"),
	preload("res://art/fleet/truck_box.glb")
]
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
	var cab := TRACTOR.instantiate() as Node3D
	root.add_child(cab)
	var paint: Color = [Color("#ddd8c7"),Color("#a25d44"),Color("#537786")][id%3]
	for panel in cab.find_children("*","MeshInstance3D",true,false):
		if String(panel.name).ends_with("_TruckPaint"):
			panel.material_override = road.mat(paint)
	box_shape(root,Vector3(0,1.75,1.4),Vector3(2.43,2.43,2.3))
	var carrier := root
	if not rigid:
		rear = AnimatableBody3D.new()
		parent.add_child(rear)
		rear.set_meta("freight",self)
		rear.set_meta("zone","load")
		carrier = rear
	cargo = Node3D.new()
	carrier.add_child(cargo)
	var model: PackedScene = FREIGHT_BODY[kind]
	cargo.add_child(model.instantiate())
	var z := -1.94 if rigid else -4.64
	var span := 4.25 if rigid else 9.24
	box_shape(carrier,Vector3(0,1.93,z),Vector3(2.4,2.1,span))
	for axle in [1.65,-1.30]:
		add_axle(root,axle)
	if rear:
		for axle in [-5.34,-6.59,-7.84]:
			add_axle(rear,axle)
	transform_at()
	var fuel := Vector3(0,2.6,z)
	smoke = emitter(cargo,fuel,false)
	flames = emitter(cargo,fuel,true)

func add_axle(parent: Node3D,z: float) -> void:
	for side in [-1.0,1.0]:
		var axle := Node3D.new()
		parent.add_child(axle)
		axle.position = Vector3(side*1.225,.47,z)
		var tire := preload("res://fleet.gd").tire(road,axle,side,.47,.32,false)
		tires.append(tire)

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
