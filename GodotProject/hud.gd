extends Control

const GREEN := Color("#83f1a3")
const GOLD := Color("#eab970")
const WHITE := Color("#e4e9df")
const BLUE := Color("#69bef1")
var visible_reticle := false
var gun_reticle := false
var cross_y := 0.0
var left_stick := Vector2.ZERO
var right_stick := Vector2.ZERO
var controls_visible := false
var tablet := false
var role := ""
var map_points := PackedVector3Array()
var trucks := PackedVector3Array()
var hazards := PackedVector3Array()
var escort := Vector3.ZERO
var aircraft := Vector3.ZERO
var map_info := ""
var map_progress := ""

func _draw() -> void:
	var mid := size*.5
	if tablet:
		draw_tablet()
		return
	if visible_reticle:
		var p := mid+Vector2.UP*(-cross_y*76)
		draw_line(mid-Vector2(size.x*.34,0),mid-Vector2(56,0),GREEN,2,true)
		draw_line(mid+Vector2(56,0),mid+Vector2(size.x*.34,0),GREEN,2,true)
		draw_arc(p,19,0,TAU,40,GREEN,1.8,true)
		crosshair(p,9,GREEN)
	if gun_reticle:
		draw_arc(mid,14,0,TAU,32,GOLD,1.7,true)
		crosshair(mid,6,GOLD)
	if controls_visible:
		var a := Vector2(size.x*.13,size.y*.80)
		var b := Vector2(size.x*.67,size.y*.80)
		for point in [a,b]:
			draw_circle(point,53,Color("#10191c6b"),true,-1,true)
			draw_arc(point,53,0,TAU,44,Color("#cbdacc83"),1.5,true)
		draw_circle(a+left_stick*40,11,GREEN,true,-1,true)
		draw_circle(b+right_stick*40,11,GREEN,true,-1,true)
		var x := size.x*.85
		if role=="recon":
			control_mark(Rect2(x,size.y*.70,size.x*.13,40),"ВЫШЕ")
		control_mark(Rect2(x,size.y*.85,size.x*.13,40),"НИЖЕ" if role=="recon" else "ТОРМОЗ")

func control_mark(rect: Rect2,text: String) -> void:
	draw_rect(rect,Color("#142124d4"))
	draw_rect(rect,Color("#a5b7aa8f"),false,1)
	draw_string(ThemeDB.fallback_font,Vector2(rect.position.x,rect.get_center().y+5),text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,15,WHITE)

func crosshair(point: Vector2,radius: float,color: Color) -> void:
	draw_line(point-Vector2.RIGHT*radius,point+Vector2.RIGHT*radius,color,1.7,true)
	draw_line(point-Vector2.UP*radius,point+Vector2.UP*radius,color,1.7,true)

func map_point(point: Vector3,area: Rect2) -> Vector2:
	var x := clampf(inverse_lerp(-245,330,point.x),0,1)
	var z := clampf(inverse_lerp(-610,1210,point.z),0,1)
	return area.position+Vector2(x,1-z)*area.size

func draw_tablet() -> void:
	var box := Rect2(size.x*.14,66,size.x*.73,size.y-87)
	var map := Rect2(box.position+Vector2(17,42),Vector2(box.size.x*.60,box.size.y-58))
	draw_rect(box,Color("#152025f9"))
	draw_rect(map,Color("#253436"))
	for i in range(1,8):
		var a := map.position+map.size*float(i)/8
		draw_line(Vector2(a.x,map.position.y),Vector2(a.x,map.end.y),Color("#3a4c4a"))
		draw_line(Vector2(map.position.x,a.y),Vector2(map.end.x,a.y),Color("#3a4c4a"))
	var line := PackedVector2Array()
	for i in range(0,map_points.size(),3):
		line.append(map_point(map_points[i],map))
	if line.size()>1:
		draw_polyline(line,WHITE,2,true)
	for i in trucks.size():
		draw_circle(map_point(trucks[i],map),5.0 if i==0 else 2.8,GOLD if i==0 else WHITE)
	for p in hazards:
		draw_circle(map_point(p,map),4.3,Color("#ff865c"))
	if not trucks.is_empty():
		draw_circle(map_point(escort,map),4.0,BLUE)
	draw_circle(map_point(aircraft,map),4.5,GREEN)
	var font := ThemeDB.fallback_font
	draw_string(font,box.position+Vector2(17,28),"ПЛАНШЕТ   /   СЕВЕРНЫЙ УЧАСТОК",HORIZONTAL_ALIGNMENT_LEFT,-1,17,WHITE)
	var col := Vector2(map.end.x+18,map.position.y+21)
	draw_string(font,col,"ГРУЗОВАЯ МАШИНА",HORIZONTAL_ALIGNMENT_LEFT,-1,15,GOLD)
	for item in map_info.split("\n"):
		col.y += 27
		draw_string(font,col,item,HORIZONTAL_ALIGNMENT_LEFT,-1,15,WHITE)
	col.y += 38
	draw_string(font,col,map_progress,HORIZONTAL_ALIGNMENT_LEFT,-1,15,GOLD)
	if not trucks.is_empty():
		for i in 3:
			col.y += 26
			draw_circle(col+Vector2(4,-5),4,[GOLD,BLUE,GREEN][i])
			draw_string(font,col+Vector2(17,0),["Груз","МОГ","Hornet"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,15,WHITE)
