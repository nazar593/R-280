extends RefCounted

const PICKUP := preload("res://art/pickup.glb")
const TRACK_HALF := 1.16
const TIRE_RADIUS := .405
const HORNET := preload("res://art/hornet.glb")
const OLIVE := Color("#646b4d")
const DARK := Color("#242b2a")
const GLASS := Color("#466372")
const STEEL := Color("#a3a89e")

static func hull(terrain: Node3D,parent: Node3D,van: bool,profile: int) -> Node3D:
	if van:
		for part in [
			[Vector3(0,.61,0),Vector3(1.90,.33,4.42),DARK],
			[Vector3(0,1.08,1.04),Vector3(1.89,.86,2.35),OLIVE],
			[Vector3(0,1.71,1.04),Vector3(1.93,.68,1.9),OLIVE],
			[Vector3(0,1.68,2.004),Vector3(1.66,.43,.045),GLASS],
			[Vector3(0,1.69,2.04),Vector3(.055,.46,.045),DARK],
			[Vector3(0,1.06,2.24),Vector3(.69,.29,.06),DARK],
			[Vector3(0,.94,-1.12),Vector3(1.93,.2,2.10),OLIVE]]:
			terrain.block(parent,part[0],part[1],part[2])
		for side in [-1,1]:
			terrain.block(parent,Vector3(side*.91,1.1,-1.12),Vector3(.14,.34,2.14),OLIVE)
			terrain.block(parent,Vector3(side*.972,1.68,1.20),Vector3(.05,.43,1.20),GLASS)
			terrain.block(parent,Vector3(side*.68,1.13,2.24),Vector3(.24,.23,.045),Color("#e4d9ae"))
	else:
		var pickup := PICKUP.instantiate() as Node3D
		parent.add_child(pickup)
		for part in pickup.find_children("*","MeshInstance3D",true,false):
			if "chassis" in String(part.name).to_lower():
				part.material_override = terrain.mat(OLIVE)
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = Vector3(0,1.16,-1.04)
	terrain.block(pivot,Vector3(0,.41,0),Vector3(.21,.81,.22),STEEL)
	var count := 2 if profile == 0 else 1
	for i in count:
		var x := (i-.5)*.23 if count == 2 else 0.0
		terrain.block(pivot,Vector3(x,.83,0),Vector3(.22,.22,.50),DARK)
		terrain.block(pivot,Vector3(x,.84,.58),Vector3(.075,.075,1.13+profile*.22),DARK)
	return pivot

static func cylinder(parent: Node3D,radius: float,width: float,axis_x: float,material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 24
	mesh.rings = 1
	var surface := MeshInstance3D.new()
	surface.mesh = mesh
	surface.material_override = material
	parent.add_child(surface)
	surface.position.x = axis_x
	surface.rotation.z = PI*.5

static func tire(terrain: Node3D,parent: Node3D,side: float,radius: float,width: float,detailed := true) -> Node3D:
	var wheel := Node3D.new()
	wheel.name = "VisibleTire"
	parent.add_child(wheel)
	var rubber: Material = terrain.mat(Color("#222527"))
	var face: Material = terrain.mat(Color("#353839"))
	var steel: Material = terrain.mat(Color("#7c8589"))
	var cap: Material = terrain.mat(Color("#464c51"))
	if not detailed:
		cylinder(wheel,radius,width,0,rubber)
		cylinder(wheel,radius*.56,.045,side*width*.49,steel)
		return wheel
	cylinder(wheel,radius*.974,width*.72,0,rubber)
	cylinder(wheel,radius,width*.54,0,rubber)
	cylinder(wheel,radius*.923,width*.96,0,face)
	cylinder(wheel,radius*.62,.027,side*width*.50,steel)
	cylinder(wheel,radius*.34,.048,side*(width*.50+.012),cap)
	for i in 5:
		var angle := TAU*i/5.0
		var center := Vector3(side*(width*.50+.03),cos(angle)*radius*.46,sin(angle)*radius*.46)
		terrain.block(wheel,center,Vector3(.035,.046,.046),Color("#343a3e"))
	return wheel

static func wheel_arch(terrain: Node3D,body: Node3D,side: float,z: float) -> void:
	var radius := .49
	for i in 9:
		var angle := lerpf(.07,PI-.07,i/8.0)
		var position := Vector3(side*1.025,.245+sin(angle)*radius,z+cos(angle)*radius)
		var segment: MeshInstance3D = terrain.block(body,position,Vector3(.30,.077,.19),DARK)
		segment.rotation.x = angle-PI*.5

static func player(terrain: Node3D,parent: Node3D,spawn: Transform3D,van: bool,profile: int) -> Dictionary:
	var car := VehicleBody3D.new()
	parent.add_child(car)
	car.transform = spawn.translated_local(Vector3(0,.78,0))
	car.contact_monitor = true
	car.max_contacts_reported = 5
	var chassis := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8,1.04,4.36)
	chassis.shape = shape
	chassis.position.y = .23
	car.add_child(chassis)
	var body := Node3D.new()
	car.add_child(body)
	body.position.y = -.66
	var gun := hull(terrain,body,van,profile)
	for i in range(4):
		var wheel := VehicleWheel3D.new()
		var side := -1.0 if i%2==0 else 1.0
		wheel.name = ["FrontLeft","FrontRight","RearLeft","RearRight"][i]
		wheel.position = Vector3(side*TRACK_HALF,-.26,1.55 if i<2 else -1.51)
		wheel.use_as_steering = i<2
		wheel.use_as_traction = true
		# Godot registers the suspension connection at tree entry.
		car.add_child(wheel)
		tire(terrain,wheel,side,TIRE_RADIUS,.27)
		wheel_arch(terrain,body,side,wheel.position.z)
	for i in 2:
		var beam: MeshInstance3D = terrain.block(car,Vector3.ZERO,Vector3.ONE,DARK)
		beam.name = "VisibleAxle%d" % i
	return {"body":car,"gun":gun}

static func aircraft(parent: Node3D) -> Dictionary:
	var root := CharacterBody3D.new()
	root.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	parent.add_child(root)
	var model := HORNET.instantiate() as Node3D
	root.add_child(model)
	var prop := model.find_child("propeller",true,false) as Node3D
	var hub := Node3D.new()
	model.add_child(hub)
	hub.position.z = -38.205/27.0
	if prop:
		prop.reparent(hub,true)
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .33
	collider.shape = sphere
	root.add_child(collider)
	return {"body":root,"visual":model,"hub":hub}
