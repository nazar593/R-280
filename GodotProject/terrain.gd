extends Node3D

const LANE := 2.08
const DATA := preload("res://route_data.gd")
var plan: Dictionary
var curve := Curve3D.new()
var length := 0.0
var points := PackedVector3Array()
var arc_lengths := PackedFloat32Array()
var ground_noise := FastNoiseLite.new()
var asphalt_material: StandardMaterial3D
var verge_materials: Array[StandardMaterial3D] = []
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
	arc_lengths.resize(points.size())
	for i in range(1,points.size()):
		arc_lengths[i] = arc_lengths[i-1]+points[i-1].distance_to(points[i])
	ground_noise.seed = 280
	ground_noise.frequency = .012
	ground()
	ribbon("Асфальт", -4.15,4.15,0.0, Color("#a5a5a0"),true)
	ribbon("Гравий слева",-5.5,-4.15,-0.03,Color("#ae9c78"),true)
	ribbon("Гравий справа",4.15,5.5,-0.03,Color("#ae9c78"),true)
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
	var nearest_length := arc_lengths[best]
	for start in range(maxi(0,best-1),mini(points.size()-1,best+1)):
		var a := Vector2(points[start].x,points[start].z)
		var b := Vector2(points[start+1].x,points[start+1].z)
		var span := b-a
		var fraction := clampf((flat-a).dot(span)/maxf(.0001,span.length_squared()),0,1)
		var segment_distance := flat.distance_squared_to(a+fraction*span)
		if segment_distance <= distance:
			distance = segment_distance
			nearest_length = lerpf(arc_lengths[start],arc_lengths[start+1],fraction)
	return nearest_length

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

func height_sample(x: float,z: float) -> float:
	var center := at(nearest(Vector3(x,0,z)))
	var dist := Vector2(x-center.x,z-center.z).length()
	return .02+smoothstep(15,67,dist)*(ground_noise.get_noise_2d(x,z)*11-4)

func terrain_height(x: float,z: float) -> float:
	var x0 := floorf((x+420)/20)*20-420
	var z0 := floorf((z+670)/20)*20-670
	var u := (x-x0)/20
	var v := (z-z0)/20
	var right := height_sample(x0+20,z0)
	var top := height_sample(x0,z0+20)
	if u+v<=1:
		return height_sample(x0,z0)*(1-u-v)+right*u+top*v
	return height_sample(x0+20,z0+20)*(u+v-1)+right*(1-v)+top*(1-u)

func ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for z in range(-670,1300,20):
		for x in range(-420,460,20):
			for offset in [Vector2i.ZERO,Vector2i(20,0),Vector2i(0,20),Vector2i(20,0),Vector2i(20,20),Vector2i(0,20)]:
				var p := Vector3(x+offset.x,0,z+offset.y)
				p.y = height_sample(p.x,p.z)
				var shade := 0.5+ground_noise.get_noise_2d(p.x+45,p.z+20)*0.5
				st.set_uv(Vector2(p.x,p.z)*.073)
				st.set_color(Color("#c3c2a1").lerp(Color("#87927b"),shade))
				st.add_vertex(p)
	st.index()
	st.generate_normals()
	var land := MeshInstance3D.new()
	land.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = preload("res://art/grass.jpg")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
			st.set_uv(Vector2(p.x,p.z)*.285)
			st.add_vertex(p)
	st.index()
	st.generate_normals()
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = st.commit()
	var surface := mat(color).duplicate() as StandardMaterial3D
	if label=="Асфальт":
		asphalt_material = surface
		surface.albedo_texture = preload("res://art/asphalt.jpg")
	elif label.begins_with("Гравий"):
		verge_materials.append(surface)
		surface.albedo_texture = preload("res://art/gravel.jpg")
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	piece.material_override = surface
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
	var posts: Array[Transform3D] = []
	var reflectors: Array[Transform3D] = []
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
			p.y = terrain_height(p.x,p.z)
			trunks.append(Transform3D(Basis.from_scale(Vector3(0.26,h*0.60,0.26)),p+Vector3.UP*(h*0.28)))
			crowns.append(Transform3D(Basis.from_scale(Vector3(h*0.52,h*0.76,h*0.63)),p+Vector3.UP*(h*0.68)))
		if d%4==3 and road.origin.y<.7:
			for side in [-1,1]:
				var p := at(d,side*5.81)
				p.y = terrain_height(p.x,p.z)
				posts.append(Transform3D(road.basis,p+Vector3.UP*.39))
				reflectors.append(Transform3D(road.basis,p+Vector3.UP*.74))
		if road.origin.y>1.6:
			var p := road.origin
			if d%3 == 0:
				solid(Vector3(p.x,p.y*0.48,p.z),Vector3(5.8,p.y,0.85),Color("#999283"),road.basis)
			for side in [-1,1]:
				solid(road*Vector3(side*4.45,0.55,0),Vector3(0.24,0.46,13.2),Color("#a4a39b"),road.basis)
	var dash := BoxMesh.new()
	dash.size = Vector3(0.13,0.015,5.25)
	batch(dash,marks,Color("#dfd8be"))
	var bollard := BoxMesh.new()
	bollard.size = Vector3(.13,.78,.12)
	batch(bollard,posts,Color("#e5dfce"))
	var reflector := BoxMesh.new()
	reflector.size = Vector3(.14,.11,.13)
	batch(reflector,reflectors,Color("#5f3635"))
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

func set_wet(wet: bool) -> void:
	if asphalt_material:
		asphalt_material.albedo_color = Color("#686d72") if wet else Color("#a5a5a0")
		asphalt_material.roughness = .34 if wet else .91
		asphalt_material.metallic_specular = .7 if wet else .38
	for material in verge_materials:
		material.albedo_color = Color("#82785e") if wet else Color("#ae9c78")
