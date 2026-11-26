extends Node3D

const HALF := 500.0
const STEP := 5.0
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()

func build() -> void:
	noise.seed = 280
	noise.frequency = 0.007
	detail.seed = 281
	detail.frequency = 0.045
	make_land()
	road_strip(0, 9, true, Color("#42474a"))
	road_strip(80, 7, false, Color("#45494a"))
	road_strip(50, 6, true, Color("#a08b69"))
	make_markings()
	make_trees()
	make_village()
	make_field_rows()

func road_distance(x: float,z: float) -> float:
	return minf(minf(absf(x),absf(z-80)),absf(x-50))

func elevation(x: float,z: float) -> float:
	var factor := smoothstep(7.0,32.0,road_distance(x,z))
	var rolling := noise.get_noise_2d(x,z)*19.0 + detail.get_noise_2d(x,z)*2.4
	return rolling*factor

func surface_at(x: float,z: float) -> String:
	if absf(x)<4.5 or absf(z-80)<3.5:
		return "ASPHALT"
	if absf(x-50)<3:
		return "GRAVEL"
	if x>100 and z<-70 and z>-340:
		return "SOIL"
	if x<-110 and z>140:
		return "SNOW"
	if x>120 and z>170 and z<350:
		return "MUD"
	return "GRASS"

func ground_color(x: float,z: float) -> Color:
	var c := Color("#73824e")
	match surface_at(x,z):
		"SOIL": c=Color("#947b58")
		"SNOW": c=Color("#d7dce0")
		"MUD": c=Color("#685342")
		"GRAVEL": c=Color("#948064")
		"ASPHALT": c=Color("#74736b")
	if surface_at(x,z)=="GRASS":
		c=c.lerp(Color("#a1a16b"),0.5+noise.get_noise_2d(x+150,z)*0.5)
	var grain := detail.get_noise_2d(x,z)*0.11
	return Color(clampf(c.r+grain,0,1),clampf(c.g+grain,0,1),clampf(c.b+grain,0,1))

func material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=0.93
	return m

func vertex(st: SurfaceTool,x: float,z: float) -> void:
	st.set_color(ground_color(x,z))
	st.add_vertex(Vector3(x,elevation(x,z),z))

func make_land() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(200):
		var z := -HALF+iz*STEP
		for ix in range(200):
			var x := -HALF+ix*STEP
			vertex(st,x,z)
			vertex(st,x+STEP,z)
			vertex(st,x,z+STEP)
			vertex(st,x+STEP,z)
			vertex(st,x+STEP,z+STEP)
			vertex(st,x,z+STEP)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	var vis := MeshInstance3D.new()
	vis.mesh=mesh
	var m := material(Color.WHITE)
	m.vertex_color_use_as_albedo=true
	vis.material_override=m
	add_child(vis)
	vis.create_trimesh_collision()

func block(pos: Vector3,dim: Vector3,c: Color,collide:=false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=dim
	var vis := MeshInstance3D.new()
	vis.mesh=mesh
	vis.material_override=material(c)
	add_child(vis)
	vis.position=pos
	if collide:
		var body := StaticBody3D.new()
		vis.add_child(body)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=dim
		col.shape=shape
		body.add_child(col)
	return vis

func road_strip(center: float,width: float,along_z: bool,c: Color) -> void:
	var y := 0.045 if along_z else 0.06
	var dims := Vector3(width,0.025,990) if along_z else Vector3(990,0.025,width)
	var pos := Vector3(center,y,0) if along_z else Vector3(0,y,center)
	block(pos,dims,c,true)
	if center==50:
		return
	for side in [-1,1]:
		var edge := center+side*(width*0.5+0.35)
		var edge_pos := Vector3(edge,0.025,0) if along_z else Vector3(0,0.035,edge)
		var edge_dim := Vector3(0.7,0.018,990) if along_z else Vector3(990,0.018,0.7)
		block(edge_pos,edge_dim,Color("#918a72"))

func batch(mesh: Mesh,transforms: Array[Transform3D],c: Color) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=mesh
	mm.instance_count=transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i,transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh=mm
	inst.material_override=material(c)
	add_child(inst)

func make_markings() -> void:
	var mesh := BoxMesh.new()
	mesh.size=Vector3(0.12,0.012,4.5)
	var marks: Array[Transform3D]=[]
	for i in range(-39,40):
		var t := float(i)*12
		if absf(t-80)>9:
			marks.append(Transform3D(Basis.IDENTITY,Vector3(0,0.07,t)))
		if absf(t)>9 and absf(t-50)>6:
			marks.append(Transform3D(Basis(Vector3.UP,PI/2),Vector3(t,0.08,80)))
	batch(mesh,marks,Color("#ddd8bf"))

func make_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=280
	var trunks: Array[Transform3D]=[]
	var leaves: Array[Transform3D]=[]
	var leaves2: Array[Transform3D]=[]
	for i in range(330):
		var z := rng.randf_range(-475,475)
		var x := -23.0+rng.randf_range(-5,5) if i<115 else rng.randf_range(-440,-155)
		if absf(z-80)<14 or (i>=115 and z>100):
			continue
		var h := rng.randf_range(3.4,6.0)
		var y := elevation(x,z)
		trunks.append(Transform3D(Basis.from_scale(Vector3(0.32,h,0.32)),Vector3(x,y+h*0.5,z)))
		var crown_scale := Vector3(h*0.68,h*0.88,h*0.68)
		var t := Transform3D(Basis.from_scale(crown_scale),Vector3(x,y+h*0.83,z))
		if i%3==0:
			leaves2.append(t)
		else:
			leaves.append(t)
		if i<115 and i%3==0:
			var tree_body := StaticBody3D.new()
			add_child(tree_body)
			tree_body.position=Vector3(x,y+h*0.5,z)
			var col := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius=0.19
			shape.height=h
			col.shape=shape
			tree_body.add_child(col)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius=0.5
	trunk_mesh.bottom_radius=0.5
	trunk_mesh.height=1
	trunk_mesh.radial_segments=6
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius=0.5
	crown_mesh.height=1
	crown_mesh.radial_segments=8
	crown_mesh.rings=4
	batch(trunk_mesh,trunks,Color("#64503d"))
	batch(crown_mesh,leaves,Color("#526b3e"))
	batch(crown_mesh,leaves2,Color("#6a7c48"))

func make_village() -> void:
	for side in [-1,1]:
		for i in range(5):
			var x := 73.0+i*22.0
			var z := 80.0+side*17
			var y := elevation(x,z)
			var wall := Color("#c3b69e") if i%2==0 else Color("#a28f79")
			block(Vector3(x,y+1.7,z),Vector3(8,3.4,6),wall,true)
			for slope in [-1,1]:
				var roof := block(Vector3(x+slope*2.03,y+4.1,z),Vector3(4.8,0.23,6.8),Color("#63544c"))
				roof.rotation.z=-slope*0.43
			for window in [-1,1]:
				block(Vector3(x+window*2.2,y+2.0,z-side*3.015),Vector3(1.05,1.05,0.045),Color("#52666b"))
			block(Vector3(x,y+1.05,z-side*3.02),Vector3(1.05,2.1,0.05),Color("#655b4e"))
			block(Vector3(x,y+4.8,z+1.7),Vector3(0.65,1.25,0.65),Color("#766a5d"))

func make_field_rows() -> void:
	var transforms: Array[Transform3D]=[]
	var mesh := BoxMesh.new()
	mesh.size=Vector3(0.45,0.045,4.8)
	for ix in range(18):
		var x := 110.0+ix*5
		for iz in range(44):
			var z := -90.0-iz*5
			var h := elevation(x,z)
			transforms.append(Transform3D(Basis.IDENTITY,Vector3(x,h+0.08,z)))
	batch(mesh,transforms,Color("#806945"))
