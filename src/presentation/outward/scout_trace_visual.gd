class_name ScoutTraceVisual
extends RefCounted
## Abstract launch directions/coarse returned course, never remote scout positions.

const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Perception = preload("res://src/presentation/perception_model.gd")
const MAX_TRACES: int = 8
const DEPARTURE_SECONDS: float = 3.0


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
		for index: int in 13:
			var t: float = float(index) / 12.0 * (0.48 if stub else 1.0)
			var control: Vector2 = home + Vector2((finish.x - home.x) * 0.3, -40)
			points.append(home * (1.0 - t) * (1.0 - t) + control * 2.0 * t * (1.0 - t) + finish * t * t)
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
