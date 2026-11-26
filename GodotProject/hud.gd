extends Control

var visible_reticle := false
var cross_y := 0.0
var left_stick := Vector2.ZERO
var right_stick := Vector2.ZERO
var controls_visible := false
var drive_info := ""

func _draw() -> void:
	var g := Color(0.32, 1.0, 0.46, 0.86)
	var s := size
	if visible_reticle:
		var c := s * 0.5
		draw_line(c + Vector2(-s.x * 0.31, 0), c + Vector2(-48, 0), g, 2)
		draw_line(c + Vector2(48, 0), c + Vector2(s.x * 0.31, 0), g, 2)
		draw_arc(c, 38, 0, TAU, 64, g, 2, true)
		var p := c + Vector2(0, cross_y * 90)
		draw_line(p - Vector2(13, 0), p + Vector2(13, 0), g, 2)
		draw_line(p - Vector2(0, 13), p + Vector2(0, 13), g, 2)
	if controls_visible and not drive_info.is_empty():
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size(drive_info,HORIZONTAL_ALIGNMENT_LEFT,-1,18)
		var pos := Vector2((s.x-text_size.x)*0.5,s.y-42)
		draw_rect(Rect2(pos-Vector2(12,21),Vector2(text_size.x+24,31)),Color(0.02,0.04,0.05,0.76))
		draw_string(font,pos,drive_info,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
	if controls_visible:
		var a := Vector2(115, s.y - 100)
		var b := Vector2(s.x - 115, s.y - 100)
		for p in [a, b]:
			draw_circle(p, 68, Color(0.05, 0.08, 0.09, 0.40))
			draw_arc(p, 68, 0, TAU, 48, Color(0.65, 0.75, 0.78, 0.4), 2, true)
		draw_circle(a + left_stick * 48, 13, g)
		draw_circle(b + right_stick * 48, 13, g)
