class_name OrganicUI
extends RefCounted
## Chitin surfaces and mineral seams. Cached geometry; input stays with owners.
static var _contours: Dictionary = {}
static var _heading_font: SystemFont
const INK := Color("101510")
const GOLD := Color("dfb76e")
const TEXT := Color("f3ecd9")

static func heading(canvas: CanvasItem, at: Vector2, title: String, place: String) -> void:
	if _heading_font == null:
		_heading_font = SystemFont.new()
		_heading_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "sans-serif"])
		_heading_font.font_weight = 600
	canvas.draw_string(_heading_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TEXT)
	var width: float = _heading_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	canvas.draw_circle(at+Vector2(width+20,-10),2.5,GOLD)
	canvas.draw_string(ThemeDB.fallback_font, at+Vector2(width+35,-3), place.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,-1,13,GOLD)

static func contour(size: Vector2) -> PackedVector2Array:
	if _contours.has(size): return _contours[size]
	var points := PackedVector2Array()
	var power: float=0.28 if size.y>80 else 0.55
	for step: int in 128:
		var angle: float=TAU*step/128.0
		var x: float=cos(angle)
		var y: float=sin(angle)
		var relief: float=0.982+0.009*sin(angle*5.0)+0.006*cos(angle*9.0)
		points.append(size*0.5+Vector2(signf(x)*pow(absf(x),power)*size.x*0.5,signf(y)*pow(absf(y),power)*size.y*0.5)*relief)
	points.append(points[0])
	if _contours.size()>256: _contours.clear()
	_contours[size]=points
	return points

static func surface(canvas: CanvasItem, rect: Rect2, tint: Color, outline: bool = false) -> void:
	if rect.size.x<=0 or rect.size.y<=0:return
	var hover: bool = rect.size.y<=80 and rect.size.x<=360 and rect.has_point(canvas.get_local_mouse_position())
	var accent: Color = GOLD.lerp(tint.lightened(0.3),0.22)
	var points: PackedVector2Array=contour(rect.size).duplicate()
	for i: int in points.size():points[i]+=rect.position
	if not outline:
		canvas.draw_colored_polygon(points.slice(0,points.size()-1),INK.lerp(tint,0.13 if not hover else 0.28))
		canvas.draw_polyline(points,Color(accent,0.035),7.0,true)
	canvas.draw_polyline(points,Color(accent,0.70 if hover else 0.40 if outline else 0.23),1.0,true)
	canvas.draw_polyline(points.slice(51,66),Color(accent,0.8 if hover else 0.48),1.5,true)

static func circle_hit(rect: Rect2, at: Vector2) -> bool:
	return rect.get_center().distance_to(at)<=rect.size.x*0.5

static func orb(canvas: CanvasItem, rect: Rect2, accent: Color = GOLD, selected: bool = false) -> void:
	var center: Vector2=rect.get_center()
	var radius: float=rect.size.x*0.5
	var hovered: bool=circle_hit(rect,canvas.get_local_mouse_position())
	var points := PackedVector2Array()
	for i: int in 65:
		var a: float=TAU*i/64.0
		points.append(center+Vector2(cos(a),sin(a))*radius*(0.982+0.012*sin(a*5.0)+0.006*cos(a*9.0)))
	canvas.draw_circle(center,radius+4,Color(accent,0.035 if not hovered else 0.09))
	canvas.draw_colored_polygon(points.slice(0,points.size()-1),INK.lerp(accent,0.10 if not selected else 0.23))
	canvas.draw_polyline(points,Color(accent,0.85 if hovered or selected else 0.48),1.4,true)
	canvas.draw_polyline(points.slice(34,49),Color(accent.lightened(0.25),0.85),1.8,true)

static func tooltip(canvas: CanvasItem, anchor: Rect2, title: String, detail: String, size: Vector2) -> void:
	if not circle_hit(anchor,canvas.get_local_mouse_position()):return
	var box := Rect2(Vector2(clampf(anchor.get_center().x-154,16,size.x-324),maxf(96,anchor.position.y-76)),Vector2(308,64))
	surface(canvas,box,Color("46503a"))
	canvas.draw_string(ThemeDB.fallback_font,box.position+Vector2(14,24),title,HORIZONTAL_ALIGNMENT_LEFT,280,14,TEXT)
	canvas.draw_string(ThemeDB.fallback_font,box.position+Vector2(14,46),detail,HORIZONTAL_ALIGNMENT_LEFT,280,12,Color("b9c5ac"))

static func icon(canvas: CanvasItem, center: Vector2, kind: String, color: Color) -> void:
	match kind:
		"send", "retreat":
			var direction: float=-1 if kind=="retreat" else 1
			canvas.draw_line(center-Vector2(13*direction,0),center+Vector2(13*direction,0),color,2,true)
			canvas.draw_polyline(PackedVector2Array([center+Vector2(4*direction,-9),center+Vector2(14*direction,0),center+Vector2(4*direction,9)]),color,2,true)
		"survey", "source":
			canvas.draw_arc(center-Vector2(3,3),9,0,TAU,32,color,1.8,true)
			canvas.draw_line(center+Vector2(4,4),center+Vector2(14,14),color,2.4,true)
		"approach":
			canvas.draw_polyline(PackedVector2Array([center+Vector2(-13,10),center+Vector2(-5,3),center+Vector2(-5,-8),center+Vector2(11,-8)]),color,2,true)
			canvas.draw_polyline(PackedVector2Array([center+Vector2(4,-14),center+Vector2(12,-8),center+Vector2(4,-2)]),color,2,true)
		"reports":
			for i: int in 3:
				canvas.draw_line(center+Vector2(-9,-8+i*8),center+Vector2(12,-8+i*8),color,1.8,true)
				canvas.draw_circle(center+Vector2(-15,-8+i*8),1.5,color)
