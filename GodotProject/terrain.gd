extends Node3D

const LANE := 2.08
const DATA := preload("res://route_data.gd")
var plan: Dictionary
var curve := Curve3D.new()
var length := 0.0
var points := PackedVector3Array()
var materials := {}

func build() -> void:
	plan = DATA.PLAN
	var nodes: Array = plan.nodes
	for i in nodes.size():
		var a := location(nodes[maxi(0,i-1)])
		var b := location(nodes[i])
		var c := location(nodes[mini(i+1,nodes.size()-1)])
		var tangent := (c-a)/6.0
		curve.add_point(b,-tangent,tangent)
	curve.bake_interval = 3.0
	length = curve.get_baked_length()
	points = curve.get_baked_points()
	ground()
	ribbon("Асфальт", -4.15,4.15,0.0, Color("#3f4344"),true)
	ribbon("Гравий слева",-5.5,-4.15,-0.03,Color("#877e63"),true)
	ribbon("Гравий справа",4.15,5.5,-0.03,Color("#877e63"),true)
	for side in [-1.0,1.0]:
		ribbon("Краевая линия",side*3.88-0.06,side*3.88+0.06,0.014,Color("#ddd6bd"),false)
	roadside()

func location(data: Dictionary) -> Vector3:
	return Vector3(data.x,data.elevation,data.z)

func at(s: float, side := 0.0) -> Vector3:
	return pose(s,side).origin

func pose(s: float, side := 0.0, direction := 1.0) -> Transform3D:
	var d := clampf(s,0.0,length)
	var p := curve.sample_baked(d)
	var forward := (curve.sample_baked(minf(length,d+2.0))-curve.sample_baked(maxf(0.0,d-2.0))).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var basis := Basis(right,forward.cross(right).normalized(),forward)
	if direction < 0:
		basis = basis.rotated(basis.y,PI)
	return Transform3D(basis,p-right*side)

func nearest(p: Vector3) -> float:
	var flat := Vector2(p.x,p.z)
	var best := 0
	var distance := INF
	for i in points.size():
		var near_point := Vector2(points[i].x,points[i].z)
		var delta := near_point.distance_squared_to(flat)
		if delta < distance:
			best = i
			distance = delta
	return float(best)/maxf(1,points.size()-1)*length

func surface_at(x: float,z: float) -> String:
	var point := Vector3(x,0,z)
	var road := at(nearest(point))
	var gap := Vector2(x-road.x,z-road.z).length()
	if gap < 4.25:
		return "ASPHALT"
	return "GRAVEL" if gap < 6.3 else "GRASS"

func mat(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var value := StandardMaterial3D.new()
		value.albedo_color = color
		value.roughness = 0.86
		materials[color] = value
	return materials[color]

func block(parent: Node3D, p: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = dimensions
	var visual := MeshInstance3D.new()
	visual.mesh = geometry
	visual.material_override = mat(color)
	parent.add_child(visual)
	visual.position = p
	return visual

func solid(p: Vector3, dimensions: Vector3, color: Color, facing := Basis.IDENTITY) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.transform = Transform3D(facing,p)
	block(body,Vector3.ZERO,dimensions,color)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)

func ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 280
	noise.frequency = 0.012
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for z in range(-670,1300,20):
		for x in range(-420,460,20):
			for offset in [Vector2i.ZERO,Vector2i(20,0),Vector2i(0,20),Vector2i(20,0),Vector2i(20,20),Vector2i(0,20)]:
				var p := Vector3(x+offset.x,0,z+offset.y)
				var center := at(nearest(p))
				var dist := Vector2(p.x-center.x,p.z-center.z).length()
				var edge := smoothstep(15,67,dist)
				p.y = 0.02 + edge*(noise.get_noise_2d(p.x,p.z)*11.0-4.0)
				var shade := 0.5+noise.get_noise_2d(p.x+45,p.z+20)*0.5
				st.set_color(Color("#73744e").lerp(Color("#535941"),shade))
				st.add_vertex(p)
	st.index()
	st.generate_normals()
	var land := MeshInstance3D.new()
	land.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	land.material_override = m
	add_child(land)
	land.create_trimesh_collision()

func ribbon(label: String,left: float,right: float,lift: float,color: Color,collide: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := ceili(length / 4.0)
	for i in segs:
		var a := pose(i*length/segs)
		var b := pose((i+1)*length/segs)
		var p1 := a*Vector3(left,lift,0)
		var p2 := a*Vector3(right,lift,0)
		var p3 := b*Vector3(left,lift,0)
		var p4 := b*Vector3(right,lift,0)
		for p in [p1,p2,p3,p2,p4,p3]:
			st.add_vertex(p)
	st.index()
	st.generate_normals()
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = st.commit()
	piece.material_override = mat(color)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	if collide:
		piece.create_trimesh_collision()

func batch(mesh: Mesh, transforms: Array[Transform3D], color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i,transforms[i])
	var instances := MultiMeshInstance3D.new()
	instances.multimesh = mm
	instances.material_override = mat(color)
	add_child(instances)

func roadside() -> void:
	var marks: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 280
	for d in range(15,floori(length)-10,13):
		var road := pose(d)
		marks.append(road.translated_local(Vector3(0,0.016,0)))
		for side in [-1,1]:
			var p := at(d,side*rng.randf_range(16,35))
			var h := rng.randf_range(3.8,7.5)
			trunks.append(Transform3D(Basis.from_scale(Vector3(0.26,h*0.60,0.26)),Vector3(p.x,h*0.26-0.3,p.z)))
			crowns.append(Transform3D(Basis.from_scale(Vector3(h*0.52,h*0.76,h*0.63)),Vector3(p.x,h*0.68-0.2,p.z)))
		if road.origin.y>1.6:
			var p := road.origin
			if d%3 == 0:
				solid(Vector3(p.x,p.y*0.48,p.z),Vector3(5.8,p.y,0.85),Color("#999283"),road.basis)
			for side in [-1,1]:
				solid(road*Vector3(side*4.45,0.55,0),Vector3(0.24,0.46,13.2),Color("#a4a39b"),road.basis)
	var dash := BoxMesh.new()
	dash.size = Vector3(0.13,0.015,5.25)
	batch(dash,marks,Color("#dfd8be"))
	batch(BoxMesh.new(),trunks,Color("#504434"))
	var crown := SphereMesh.new()
	crown.radial_segments = 7
	crown.rings = 4
	batch(crown,crowns,Color("#455938"))
	for landmark: Dictionary in plan.landmarks:
		var t := pose(landmark.distance)
		var side: float = landmark.side
		match landmark.kind:
			"junction","bridge":
				var ramp := t.basis.rotated(Vector3.UP,side*(PI*0.50 if landmark.kind=="bridge" else PI*0.31))
				var p: Vector3 = t.origin+ramp.z*side*(37.0 if landmark.kind=="junction" else 0.0)
				p.y = 0.12
				solid(p,Vector3(6.2,0.16,76),Color("#51524e"),ramp)
			"village":
				for n in range(9):
					var p := t * Vector3(side*(21.0+n%3*12),1.35,(n-4)*10.2)
					solid(p,Vector3(7.5,2.9,6.2),Color("#b6ab91"),t.basis)
					solid(p+Vector3.UP*1.62,Vector3(8.0,0.52,6.55),Color("#7a4e3c"),t.basis)
			"gate":
				solid(t*Vector3(side*6.8,1.33,0),Vector3(2.3,2.65,3.0),Color("#6a8582"),t.basis)
				for x in [-5.0,5.0]:
					solid(t*Vector3(x,2.55,0),Vector3(0.23,5.1,0.23),Color("#666e6c"),t.basis)
				solid(t*Vector3(0,5.15,0),Vector3(10.4,0.20,0.22),Color("#777d75"),t.basis)
				solid(t*Vector3(0,4.95,0),Vector3(3.9,0.73,0.13),Color("#435b56"),t.basis)
