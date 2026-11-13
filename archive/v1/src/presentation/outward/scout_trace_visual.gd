class_name ScoutTraceVisual
extends RefCounted
## Abstract launch directions/coarse returned course, never remote scout positions.

const Art = preload("res://src/presentation/sensory_art.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Perception = preload("res://src/presentation/perception_model.gd")
const MAX_TRACES: int = 8
const DEPARTURE_SECONDS: float = 3.0


static func caption_at(center: Vector2, text_size: Vector2, blocked: Array[Rect2], bounds: Rect2, offsets: Array = [-13.0, 17.0, 35.0, -31.0, -49.0]) -> Variant:
	# Keep the marker/hit target fixed; only its secondary caption may move or hide.
	for offset: float in offsets:
		var baseline: Vector2 = center + Vector2(0, offset)
		var rect := Rect2(baseline - Vector2(text_size.x * 0.5, text_size.y), text_size + Vector2(0, 4))
		if bounds.encloses(rect) and not blocked.any(func(other: Rect2): return other.grow(3).intersects(rect)):
			return baseline
	return null


static func traces(missions: Array, facing: float, size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var groups: Dictionary = {}
	var home := Vector2(size.x * 0.5, size.y * 0.78 - 22.0)
	for mission: Dictionary in missions:
		var relative: Variant = Perception.relative_bearing(mission.bearing, facing)
		if relative == null or absf(relative) > Panorama.HALF_FIELD:
			continue
		var sector: int = roundi(float(relative) / (PI / 12.0))
		if groups.has(sector):
			groups[sector].missions.append(mission.duplicate(true))
			continue
		if result.size() >= MAX_TRACES:
			continue
		var finish := Vector2(size.x * 0.5 + float(relative) / Panorama.HALF_FIELD * (size.x * 0.5 - 72.0), size.y * 0.61)
		var points := PackedVector2Array()
		var stub: bool = mission.scent < 0.1
		for index: int in 33:
			var t: float = float(index) / 32.0 * (0.48 if stub else 1.0)
			var control: Vector2 = home + Vector2((finish.x - home.x) * 0.3, -40)
			var at: Vector2=home*(1.0-t)*(1.0-t)+control*2.0*t*(1.0-t)+finish*t*t
			var side: Vector2=(finish-home).normalized().orthogonal()
			at+=side*sin(t*PI)*sin(t*TAU+sector*0.63)*9.0
			points.append(at)
		var entry: Dictionary = {"missions": [mission.duplicate(true)], "points": points,
			"stub": stub, "center": points[-1], "scent": mission.scent}
		groups[sector] = entry
		result.append(entry)
	return result


static func pick(traces: Array[Dictionary], at: Vector2, selected: String) -> String:
	var nearest: float = INF
	var picked: Dictionary = {}
	for entry: Dictionary in traces:
		var distance: float = at.distance_to(entry.center)
		# Keep the shared home anchor out of selection; the outer stroke is tappable.
		var points: PackedVector2Array = entry.points
		for index: int in range(points.size() / 2, points.size() - 1):
			var edge: Vector2 = points[index + 1] - points[index]
			var t: float = clampf((at - points[index]).dot(edge) / maxf(edge.length_squared(), 0.001), 0.0, 1.0)
			distance = minf(distance, at.distance_to(points[index] + edge * t))
		if distance <= 44.0 and distance < nearest:
			nearest = distance
			picked = entry
	if picked.is_empty():
		return ""
	var records: Array = picked.missions
	for index: int in records.size():
		if "mission:" + records[index].id == selected:
			return "mission:" + records[(index + 1) % records.size()].id
	return "mission:" + records[0].id


static func departure(age: float, side: float, size: Vector2) -> Dictionary:
	if age < 0.0 or age >= DEPARTURE_SECONDS:
		return {}
	var home := Vector2(size.x * 0.5, size.y * 0.78)
	var t: float = age / DEPARTURE_SECONDS
	var first: Vector2 = home + Vector2(side * 76.0, 28.0)
	var middle: Vector2 = home + Vector2(side * 14.0, 12.0)
	var finish: Vector2 = home + Vector2(0, -22.0)
	return {"position": first.lerp(middle, t / 0.6) if t < 0.6 else middle.lerp(finish, (t - 0.6) / 0.4),
		"direction": middle - first if t < 0.6 else finish - middle}


static func draw_scent(view: Node2D, entry: Dictionary, time: float, selected: bool) -> void:
	# Decorative chemistry on a remembered launch direction, never a scout's
	# live position or progress. Motion does not depend on simulation time speed.
	var points: PackedVector2Array=entry.points
	var color:=Color("99e8bd")
	var strength: float=clampf(float(entry.scent),0.0,1.0)
	var opacity: float=(0.18+strength*0.32)*(1.25 if selected else 1.0)
	var width: float=18.0+strength*12.0
	Art.filament(view,points,Color(color,opacity*0.42),width*2.1,Art.FILAMENT,false)
	Art.filament(view,points,Color(color,opacity),width,Art.FILAMENT,false)
	# Two broken, flowing inner wisps keep the trace from reading as a wire.
	for layer: int in 2:
		var strand:=PackedVector2Array()
		for i: int in points.size():
			var t: float=float(i)/(points.size()-1)
			var tangent: Vector2=points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
			strand.append(points[i]+tangent.normalized().orthogonal()*sin(t*TAU*1.4-time*0.6+layer*PI)*sin(t*PI)*width*0.20)
		Art.filament(view,strand.slice(3+layer*8,points.size()-2-layer*3),Color(color.lightened(0.18),opacity*0.70),width*0.30,Art.FILAMENT,false)
	for i: int in 5:
		var index: int=5+i*5
		var at: Vector2=points[index]+Vector2(sin(time*0.3+i),cos(time*0.23+i))*3
		var extent:=Vector2(34,24)*(0.65+strength*0.5)
		view.draw_texture_rect(Art.CLOUD,Rect2(at-extent*0.5,extent),false,Color(color,opacity*0.20))
	var tip_size:=Vector2(30,24)*(0.6+strength*0.4)
	view.draw_texture_rect(Art.CLOUD,Rect2(entry.center-tip_size*0.5,tip_size),false,Color(color,opacity*0.55))
	if selected:
		var rim: PackedVector2Array=Art.membrane(entry.center,17,0.4,0.8)
		view.draw_polyline(rim.slice(3,11),Color(color,0.85),1.3,true)
		view.draw_polyline(rim.slice(19,27),Color(color,0.85),1.3,true)
