"""Original Roadline fleet props. Run with Blender in background mode."""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

output, source = map(Path, sys.argv[sys.argv.index("--") + 1:])
output.mkdir(parents=True, exist_ok=True)
source.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
current = None
fleet = []

def material(name, srgb, rough=.57, metal=0, emission=0):
    result=bpy.data.materials.new(name)
    color=tuple((int(srgb[i:i+2],16)/255)**2.2 for i in (0,2,4))+(1,)
    result.diffuse_color=color
    result.use_nodes=True
    p=result.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value=color
    p.inputs["Metallic"].default_value=metal
    p.inputs["Roughness"].default_value=rough
    if emission:
        p.inputs["Emission Color"].default_value=color
        p.inputs["Emission Strength"].default_value=emission
    return result

paint=material("Paint","8e9174",.33,.25)
vanpaint=material("VanPaint","8f9891",.44,.13)
truckpaint=material("TruckPaint","c8c5b4",.36,.19)
dark=material("Polymer","232729",.74)
black=material("Grille","141819",.58)
glass=material("TintedGlass","354e59",.20,.31)
steel=material("Steel","697575",.38,.61)
alum=material("Aluminium","b8bbb5",.32,.75)
chrome=material("Brightwork","c5c4b9",.29,.72)
red=material("TailLamps","a42f24",.27,.11,.19)
amber=material("Indicator","da8137",.31,0,.17)
lamps=material("Headlamps","f1dfaf",.24,.14,.18)
canvas=material("Canvas","536568",.86)
canvas_trim=material("CanvasStraps","313e40",.86)
cold=material("InsulatedPanels","c5cabd",.54,.10)
rubber=material("Rubber","2c3031",.84)
mount=material("MountPaint","585e55",.54,.25)
gunmetal=material("DisplayGunmetal","3d4647",.44,.37)

def world(p):
    x,h,z=p
    return (x,-z,h)

def collection(name):
    global current
    current=bpy.data.collections.new(name)
    scene.collection.children.link(current)
    fleet.append(current)

def store(obj,name,mat):
    obj.name=name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    current.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def normals(obj):
    for polygon in obj.data.polygons:
        polygon.use_smooth=True
    modifier=obj.modifiers.new("Panel normals","WEIGHTED_NORMAL")
    modifier.keep_sharp=True

def bevel(obj, amount, steps=1):
    if amount<=0: return
    b=obj.modifiers.new("Rolled edges","BEVEL")
    b.width=amount
    b.segments=steps
    b.limit_method='ANGLE'
    normals(obj)

def box(name,p,size,mat,edge=.017,steps=1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=world(p))
    obj=bpy.context.object
    # Assign the order explicitly because dimensions cannot take negative lengths.
    w,h,d=size
    obj.dimensions=(w,d,h)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    store(obj,name,mat)
    bevel(obj,edge,steps)
    return obj

def polygon_mesh(name,verts,faces,mat,edge=0):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([world(p) for p in verts],[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    current.objects.link(obj)
    mesh.materials.append(mat)
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)
    bevel(obj,edge)
    return obj

def panel(name,verts,mat):
    return polygon_mesh(name,verts,[(0,1,2,3)],mat)

def loft(name,rows,mat,edge=.034):
    # z, lower half-width, upper half-width, sill, roof, roof shoulder
    vertices=[]
    for z,w,u,y0,y1,h in rows:
        vertices.extend([(-w*.90,y0,z),(w*.90,y0,z),(w,y0+.09,z),(w,y1-h,z),
                         (u,y1,z),(-u,y1,z),(-w,y1-h,z),(-w,y0+.09,z)])
    faces=[tuple(range(7,-1,-1))]
    for i in range(len(rows)-1):
        for j in range(8):
            k=(j+1)%8
            a=i*8
            faces.append((a+j,a+k,a+8+k,a+8+j))
    faces.append(tuple(range(len(vertices)-8,len(vertices))))
    return polygon_mesh(name,vertices,faces,mat,edge)

def tube(name,a,b,r,mat,r2=None,count=12):
    p=Vector(world(a)); q=Vector(world(b)); d=q-p
    bpy.ops.mesh.primitive_cone_add(vertices=count,radius1=r,radius2=r if r2 is None else r2,
                                     depth=d.length,location=(p+q)/2)
    obj=bpy.context.object
    obj.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    for face in obj.data.polygons:
        if len(face.vertices)==4: face.use_smooth=True
    return store(obj,name,mat)

def bar(name,a,b,w,mat,thick=None):
    p=Vector(world(a)); q=Vector(world(b)); d=q-p
    mid=tuple((a[i]+b[i])/2 for i in range(3))
    obj=box(name,mid,(w,d.length,w if thick is None else thick),mat,0)
    obj.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return obj

def door(side,z,top,bottom,half_depth,mat):
    s=side
    # Flush seam strips and a recessed handle are readable even at driving distance.
    for dz in [-half_depth,half_depth]:
        box("Shut line",(s*top,1.04,z+dz),(.012,.59,.016),dark,.003)
    box("Window sill",(s*top,1.36,z),(.028,.04,2*half_depth),dark,.006)
    box("Door handle",(s*(top+.018),1.29,z-.26),(.045,.063,.17),mat,.012)
    box("Side step",(s*(bottom+.05),.67,z),(.18,.10,1.52),dark,.014)

def bed(rear,front,width,sill,rail,mat):
    center=(rear+front)/2
    span=front-rear
    box("Bed pressed floor",(0,sill,center),(width,.14,span),dark,.026)
    box("Tailgate",(0,(sill+rail)/2,rear-.03),(width,.43,.15),mat,.036,2)
    box("Top tailgate cap",(0,rail+.02,rear-.056),(width*.95,.065,.18),dark,.012)
    box("Forward bed bulkhead",(0,sill+.17,front),(width,.39,.12),mat,.021)
    for x in [-1,1]:
        for idx in range(4):
            box("Cargo floor ribs",(x*(.10+idx*.16),sill+.078,center),(.048,.016,span*.93),steel,.003)
        box("Stamped bed shoulder",(x*width*.47,(sill+rail)/2,center),(.16,rail-sill+.09,span),mat,.033)
        box("Bed rail cap",(x*width*.482,rail+.017,center),(.15,.054,span),dark,.011)
        box("Tail lamp rubber gasket",(x*width*.46,sill+.17,rear-.12),(.19,.35,.04),dark,.024)
        box("Brake lens",(x*width*.46,sill+.208,rear-.15),(.14,.23,.05),red,.017)
        box("Reverse lens",(x*width*.46,sill+.066,rear-.15),(.13,.045,.05),lamps,.009)
    box("Tailgate relief",(0,sill+.18,rear-.111),(width*.66,.24,.018),mat,.016)
    box("Tailgate handle",(0,rail-.10,rear-.132),(.25,.055,.038),dark,.007)
    box("Rear bumper",(0,sill-.17,rear-.10),(width*1.005,.20,.30),dark,.041,2)
    box("Plate",(0,sill-.15,rear-.26),(.40,.12,.024),alum,.004)

def pickup():
    collection("Hilux Pickup")
    for x in [-.56,.56]:
        box("Frame rail",(x,.56,.05),(.17,.20,4.54),dark,.026)
    loft("Pressed cab and fenders",[
        (-.58,.93,.81,.65,1.39,.16),(.21,.94,.82,.65,1.40,.16),
        (1.14,.97,.88,.63,1.37,.17),(1.88,.93,.81,.62,1.29,.12),
        (2.31,.83,.73,.66,1.24,.12)],paint,.039)
    loft("Sloping crew cab",[
        (-.61,.80,.70,1.24,1.83,.13),(-.34,.86,.73,1.24,1.945,.096),
        (.44,.86,.72,1.25,1.93,.11),(.96,.82,.71,1.26,1.67,.072),
        (1.16,.79,.69,1.25,1.43,.06)],paint,.026)
    panel("Vehicle windshield",[(-.72,1.458,1.17),(.72,1.458,1.17),(.65,1.94,.49),(-.65,1.94,.49)],glass)
    panel("Rear window",[(-.65,1.49,-.607),(.65,1.49,-.607),(.57,1.77,-.535),(-.57,1.77,-.535)],glass)
    for side in [-1,1]:
        sideglass=[(side*.866,1.43,-.40),(side*.867,1.43,.84),
                   (side*.765,1.80,.59),(side*.768,1.81,-.28)]
        panel("Cab side glass",sideglass,glass)
        bar("Door pillar",(side*.865,1.42,.22),(side*.78,1.82,.17),.054,dark)
        door(side,.15,.95,.88,.68,dark)
        bar("Mirror arm",(side*.91,1.45,.83),(side*1.095,1.49,.87),.061,dark)
        box("Mirror shell",(side*1.116,1.505,.88),(.25,.145,.14),dark,.025,2)
        box("Mirror glass",(side*1.12,1.507,.796),(.195,.104,.016),glass,.009)
        box("Headlamp recess",(side*.65,1.122,2.302),(.51,.24,.079),black,.039,2)
        box("Optic",(side*.67,1.136,2.35),(.39,.137,.073),lamps,.028,2)
        box("DRL strip",(side*.65,1.211,2.367),(.43,.033,.032),chrome,.010)
        box("Front marker",(side*.89,1.092,2.23),(.066,.105,.15),amber,.009)
        bar("Hood pressing",(side*.418,1.394,1.10),(side*.478,1.286,2.17),.024,paint)
    box("Bumper",(0,.78,2.31),(1.82,.25,.27),dark,.054,2)
    box("Skid panel",(0,.637,2.29),(.84,.093,.25),steel,.019)
    box("Grille surround",(0,1.077,2.355),(.93,.303,.06),chrome,.045,2)
    box("Upper grille matrix",(0,1.075,2.39),(.82,.227,.071),black,.029)
    for i in range(3): box("Grille slat",(0,1.01+i*.062,2.431),(.74,.023,.028),steel,.006)
    bed(-2.34,-.58,1.87,.92,1.37,paint)

def van():
    collection("Bukhanka Utility")
    for x in [-.55,.55]:
        box("Utility frame",(x,.53,0),(.20,.24,4.41),dark,.029)
    loft("Rounded split-window cab",[
        (-.36,.96,.82,.66,2.04,.19),(.02,.99,.82,.66,2.12,.20),
        (1.37,.99,.84,.64,2.11,.25),(2.03,.92,.80,.65,2.04,.19),
        (2.20,.79,.71,.70,1.86,.15)],vanpaint,.047)
    for s in [-1,1]:
        panel("Split windshield",[(s*.065,1.57,2.209),(s*.70,1.58,2.196),
                                  (s*.60,1.92,2.205),(s*.05,1.941,2.218)],glass)
        panel("Van door window",[(s*.993,1.48,.25),(s*.994,1.48,1.70),
                                 (s*.917,1.92,1.52),(s*.923,1.91,.27)],glass)
        door(s,.93,.994,.93,.65,dark)
        bar("Van drip rail",(s*.895,2.035,.03),(s*.888,2.00,1.85),.044,vanpaint)
        ring=(s*.65,1.165,2.199); face=(s*.65,1.165,2.273)
        tube("Round lamp surround",ring,face,.168,chrome,count=20)
        tube("Round lens",face,(s*.65,1.165,2.31),.132,lamps,count=20)
        tube("Turn indicator",(s*.841,.932,2.17),(s*.841,.932,2.236),.068,amber,count=12)
        bar("Mirror stalk",(s*.93,1.64,1.80),(s*1.11,1.56,1.92),.045,steel)
        box("Mirror",(s*1.136,1.62,1.94),(.14,.25,.10),dark,.023)
    box("Center nose grille",(0,1.079,2.226),(.74,.276,.067),dark,.050,2)
    for i in range(4):
        box("Pressed grille slot",(0,.987+i*.061,2.27),(.59,.025,.028),steel,.009)
    box("Utility bumper",(0,.673,2.226),(1.84,.16,.21),dark,.030)
    bed(-2.18,-.37,1.94,.91,1.34,vanpaint)

def tractor():
    collection("High Cab Tractor")
    for x in [-.65,.65]:
        box("Longitudinal rail",(x,.70,-.04),(.24,.31,5.70),dark,.032)
    loft("High cab coachwork",[
        (.27,1.12,.93,.86,3.16,.23),(.51,1.20,.97,.87,3.24,.23),
        (1.83,1.21,.94,.84,3.22,.25),(2.38,1.11,.89,.86,3.08,.22),
        (2.55,1.01,.80,.89,2.88,.25)],truckpaint,.047)
    panel("Swept main windshield",[(-.97,2.05,2.585),(.97,2.05,2.585),
                                   (.82,2.74,2.557),(-.82,2.74,2.557)],glass)
    box("Sunshade",(0,2.81,2.516),(1.93,.134,.225),dark,.033)
    box("Radiator grille",(0,1.49,2.564),(1.61,.66,.089),black,.062,2)
    for i in range(5):
        box("Dark radiator slat",(0,1.23+.113*i,2.614),(1.46,.067,.04),steel,.013)
    box("Bumper front",(0,.942,2.57),(2.21,.267,.211),truckpaint,.044,2)
    box("Plate recess",(0,.959,2.688),(.45,.148,.026),dark,.01)
    for s in [-1,1]:
        panel("Wraparound door window",[(s*1.218,2.04,.71),(s*1.218,2.06,2.274),
                                        (s*1.103,2.66,2.142),(s*1.132,2.66,.75)],glass)
        box("Door shut seam",(s*1.208,1.64,1.04),(.014,.76,.022),dark,.004)
        box("Door pull",(s*1.229,1.87,1.08),(.06,.084,.23),dark,.015)
        bar("Mirror bracket",(s*1.16,2.53,2.31),(s*1.352,2.51,2.43),.055,dark)
        box("Mirror pod",(s*1.389,2.49,2.44),(.18,.38,.16),dark,.039)
        box("Lower lens",(s*.882,1.01,2.676),(.344,.128,.061),lamps,.027)
        box("Cab marker",(s*1.04,1.02,2.597),(.102,.086,.115),amber,.013)
        box("Access steps",(s*1.03,.91,1.5),(.33,.17,.87),dark,.032)
        box("Lower fender",(s*1.17,1.05,-1.39),(.32,.21,1.06),dark,.073)
        tube("Fuel tank",(s*.83,.72,-.94),(s*.83,.72,.43),.34,alum,count=16)
        for z in [-.69,.19]:
            tube("Tank strap",(s*.83,.72,z-.047),(s*.83,.72,z+.047),.354,dark,count=16)
        box("Rear lamp",(s*1.01,.79,-2.913),(.32,.171,.046),red,.015)
    tube("Fifth-wheel base",(0,.80,-1.25),(0,.97,-1.25),.57,dark,count=16)
    tube("Fifth-wheel contact",(0,.97,-1.25),(0,1.025,-1.25),.68,steel,count=16)

def trailer(kind):
    name={"curtain":"Curtain Semi-trailer","cold":"Refrigerated Semi-trailer","tank":"Tanker Semi-trailer","rigid":"Rigid Box Body"}[kind]
    collection(name)
    rigid=kind=="rigid"; center=-1.94 if rigid else -4.64
    span=4.25 if rigid else 9.24
    front=center+span*.5; rear=center-span*.5
    for s in [-1,1]:
        box("Trailer longitudinal beam",(s*.70,.75,center),(.22,.30,span*.955),dark,.025)
        box("Side underrun rail",(s*1.14,.72,center+span*.12),(.112,.22,span*.43),alum,.022)
        for z in [center-.17*span,center+.23*span]:
            box("Underrun upright",(s*1.14,.83,z),(.11,.37,.13),steel,.011)
    box("Deck and trim",(0,.941,center),(2.42,.20,span),alum,.045)
    if kind=="tank":
        tank_y=2.117
        rows=[(rear+.10,.61),(rear+.22,.91),(rear+.52,1.055),(front-.53,1.055),(front-.23,.91),(front-.09,.61)]
        verts=[]; N=24
        for z,r in rows:
            verts.extend([(math.cos(TAU*i/N)*r,tank_y+math.sin(TAU*i/N)*r,z) for i in range(N)])
        faces=[tuple(range(N-1,-1,-1))]
        for k in range(len(rows)-1):
            for j in range(N):
                v=(j+1)%N; a=k*N
                faces.append((a+j,a+v,a+N+v,a+N+j))
        faces.append(tuple(range(len(verts)-N,len(verts))))
        barrel=polygon_mesh("Polished rounded tank",verts,faces,alum)
        normals(barrel)
        for z in [center-span*.27,center,center+span*.28]:
            tube("Support band",(0,tank_y,z-.046),(0,tank_y,z+.046),1.07,steel,count=24)
            box("Tank saddle",(0,1.11,z),(1.67,.35,.34),steel,.034)
        box("Walkway",(0,3.197,center),(.69,.071,span*.68),steel,.013)
        tube("Tank cap",(0,3.20,center-.66),(0,3.36,center-.66),.27,alum,count=16)
        for x in [.53,.87]: bar("Ladder upright",(x,1.13,rear+.04),(x,2.95,rear+.10),.045,steel)
        for i in range(6): bar("Ladder step",(.53,1.23+i*.29,rear+.04),(.87,1.23+i*.29,rear+.04),.05,alum)
    else:
        skin=canvas if kind=="curtain" else cold
        box("Main cargo shell",(0,2.051,center),(2.435,2.151,span-.06),skin,.059,2)
        box("Roof edging",(0,3.139,center),(2.454,.113,span),alum,.025)
        for s in [-1,1]:
            for y in [1.005,3.078]:
                box("Long protective trim",(s*1.216,y,center),(.085,.098,span),alum,.018)
            for i in range(10 if not rigid else 5):
                z=rear+.38+(span-.75)*i/(9 if not rigid else 4)
                if kind=="curtain":
                    box("Tensioner webbing",(s*1.227,1.68,z),(.023,1.40,.081),canvas_trim,.008)
                    box("Tensioner buckle",(s*1.245,1.142,z),(.052,.148,.108),steel,.012)
                else:
                    box("Side panel seam",(s*1.227,2.07,z),(.021,1.97,.019),alum,.005)
            box("Rear cargo door",(s*.584,2.034,rear-.048),(1.119,1.998,.092),cold,.042)
            tube("Rear door locking bar",(s*.55,1.129,rear-.10),(s*.55,2.954,rear-.10),.022,steel)
            box("Door latch handle",(s*.448,1.712,rear-.12),(.26,.054,.057),steel,.008)
        if kind=="cold":
            box("Refrigeration unit",(0,2.659,front-.018),(1.25,.65,.217),cold,.059,2)
            box("Cooling intake",(0,2.689,front+.106),(.91,.32,.026),black,.018)
            for i in range(5): box("Cooling louvre",(0,2.566+i*.059,front+.128),(.78,.018,.024),steel,.005)
    box("Rear underride bumper",(0,.677,rear-.062),(2.34,.15,.18),dark,.028)
    for s in [-1,1]:
        box("Rear lamp housing",(s*.888,.872,rear-.138),(.431,.196,.085),black,.025)
        box("Rear red lens",(s*.945,.876,rear-.186),(.23,.106,.042),red,.013)
        box("Rear amber lens",(s*.758,.876,rear-.186),(.092,.102,.042),amber,.009)
        for z in [rear+.21,center,front-.16]:
            box("Side clearance marker",(s*1.223,1.020,z),(.036,.054,.118),amber,.009)

def display_mount(index):
    collection(("Twin Mount", "Single Mount", "Heavy Mount")[index])
    tube("Swivel base",(0,0,0),(0,.091,0),.366,mount,count=20)
    tube("Pivot collar",(0,.092,0),(0,.24,0),.19,steel,count=14)
    loft("Mount casting",[(-.20,.127,.109,.09,.74,.10),(-.12,.158,.132,.09,.81,.12),
                          (.15,.149,.126,.09,.82,.12)],mount,.025)
    for s in [-1,1]:
        bar("External bracing",(s*.221,.13,-.10),(s*.095,.66,.02),.076,steel)
        box("Side receiver cap",(s*.246,.772,-.14),(.072,.235,.44),mount,.031)
    lanes=[-.145,.145] if index==0 else [0]
    for x in lanes:
        box("Fictional receiver shell",(x,.825,-.090),(.237,.232,.49),gunmetal,.027,2)
        box("Receiver top plate",(x,.958,-.121),(.171,.064,.381),steel,.018)
        tip=1.135+index*.105
        tube("Exterior barrel",(x,.84,.119),(x,.84,tip),.039+index*.014,gunmetal,r2=.025+index*.010,count=12)
        tube("Exterior collar",(x,.84,tip-.173),(x,.84,tip-.063),.059+index*.012,steel,count=12)
        tube("Exterior tip silhouette",(x,.84,tip-.054),(x,.84,tip+.025),.043+index*.011,dark,count=12)
        bar("Rear handle",(x,.78,-.28),(x,.66,-.48),.052,steel)

TAU=math.tau
pickup(); van(); tractor()
for kind in ['curtain','cold','tank','rigid']: trailer(kind)
for i in range(3): display_mount(i)

files=['hilux','bukhanka','tractor','trailer_curtain','trailer_cold','trailer_tank','truck_box','mount_twin','mount_single','mount_heavy']
for coll,key in zip(fleet,files):
    # Godot uses one drawable surface per material here; keep the individual panels
    # and details in the .blend file, and export a compact merged copy.
    copies=[]
    for part in list(coll.objects):
        obj=part.copy();obj.data=part.data.copy();scene.collection.objects.link(obj);copies.append(obj)
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True);bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    groups={}
    for obj in copies: groups.setdefault(obj.data.materials[0].name,[]).append(obj)
    outputs=[]
    for name,group in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in group: obj.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        if len(group)>1: bpy.ops.object.join()
        merged=bpy.context.object
        merged.name=key+"_"+name
        outputs.append(merged)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in outputs: obj.select_set(True)
    bpy.context.view_layer.objects.active=outputs[0]
    bpy.ops.export_scene.gltf(filepath=str(output/f"{key}.glb"),use_selection=True,
                              export_format='GLB',export_yup=True,export_extras=False,
                              export_texcoords=False,export_normals=True,export_materials='EXPORT')
    for obj in outputs:bpy.data.objects.remove(obj,do_unlink=True)

# Separate the editable assets into a studio-style layout when someone opens the source.
placements=[(-5.4,0,0),(-1.9,0,0),(2.2,0,0),(6.5,3.4,0),(10.0,3.4,0),
            (13.5,3.4,0),(16.8,1.2,0),(-5.4,-4.3,.10),(-3.8,-4.3,.10),(-2.2,-4.3,.10)]
for coll,where in zip(fleet,placements):
    root=bpy.data.objects.new(coll.name+" | assembly",None)
    coll.objects.link(root)
    for obj in list(coll.objects):
        if obj!=root:obj.parent=root
    root.location=where
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            view=area.spaces.active
            view.region_3d.view_location=(5,2,1)
            view.region_3d.view_distance=28
            view.shading.color_type="MATERIAL"
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
