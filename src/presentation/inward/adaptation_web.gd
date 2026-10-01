class_name AdaptationWeb
extends RefCounted
## Knowledge-derived attention graph, not a physical network or a hidden tech tree.

const Art = preload("res://src/presentation/sensory_art.gd")

static func positions(size: Vector2) -> Dictionary:
	var width: float = minf(size.x * 0.65, size.x - 340.0)
	var height: float = maxf(0.0, size.y - 310.0)
	var origin := Vector2(24, 170)
	return {"foraging": origin + Vector2(width * 0.50, height * 0.25),
		"lean": origin + Vector2(width * 0.27, height * 0.50),
		"load": origin + Vector2(width * 0.73, height * 0.50),
		"honeydew": origin + Vector2(width * 0.50, height * 0.80)}

static func visible_nodes(status: Dictionary) -> Array[String]:
	var result: Array[String] = ["foraging", "lean", "load"]
	if not status.get("honeydew", {}).is_empty():
		result.append("honeydew")
	return result

static func node_at(at: Vector2, size: Vector2, status: Dictionary) -> String:
	var centers: Dictionary = positions(size)
	for id: String in visible_nodes(status):
		if at.distance_to(centers[id]) <= 44.0:
			return id
	return ""

static func trait_state(status: Dictionary, id: String) -> String:
	if status.get("adaptation_trial", {}).get("adaptation_id", "") == id:
		return "Growing trial brood"
	if status.get("adaptation_repertoire", "") == id:
		return "Inherited · %d expressed" % status.get("adapted_workers", 0)
	if status.get("adaptation_repertoire", "") != "" or not status.get("adaptation_trial", {}).is_empty():
		return "Alternative"
	return "Brood trial available"

static func draw_graph(view: Node2D, size: Vector2, status: Dictionary, selected: String, phase: float) -> void:
	var centers: Dictionary = positions(size)
	for id: String in visible_nodes(status):
		var ecological: bool = id == "honeydew"
		var color: Color = Color("99b59c") if ecological else Color("bba6c8")
		var state: String = trait_state(status, id) if id in ["lean", "load"] else ""
		if state == "Alternative":
			color = Color("776e80")
		if id != "foraging":
			if ecological:
				view.draw_line(centers.foraging + Vector2(0, 84), centers[id] - Vector2(0, 36), Color(color, 0.24), 1.0, true)
			else:
				var direction: float = -1.0 if id == "lean" else 1.0
				var start: Vector2 = centers.foraging + Vector2(direction * 34, 0)
				var control: Vector2 = centers.foraging + Vector2(direction * 160, 10)
				var finish: Vector2 = centers[id] - Vector2(0, 34)
				var points := PackedVector2Array()
				for step: int in 17:
					var t: float = float(step) / 16.0
					points.append(start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + finish * t * t)
				view.draw_polyline(points, Color(color, 0.24), 1.0, true)
		var at: Vector2 = centers[id]
		var boundary: PackedVector2Array = Art.membrane(at, 28, phase * 0.18 + at.x * 0.01, 0.72 if ecological else 1.0)
		view.draw_colored_polygon(boundary, Color(color, 0.07))
		view.draw_polyline(boundary.slice(1, 27), Color(color, 0.48), 1.2, true)
		if state.begins_with("Inherited"):
			view.draw_circle(at, 18.0, Color(color, 0.15))
		elif state == "Growing trial brood":
			view.draw_arc(at, 33.0, -PI * 0.5, PI * 0.8, 24, Color(color, 0.72), 1.5, true)
		if ecological:
			for offset: int in [-1, 1]:
				view.draw_arc(at + Vector2(offset * 7, 0), 7, 0.1, 4.6, 18, Color(color, 0.6), 1.0, true)
		else:
			view.draw_circle(at + Vector2(-4, -4), 3.0, Color(color, 0.65))
			view.draw_circle(at + Vector2(4, 4), 3.0, Color(color, 0.40))
			view.draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), Color(color, 0.4), 1.0, true)
		if id == selected:
			view.draw_arc(at, 39, 0.0, 0.65, 12, Color("dce5d9"), 1.0, true)
			view.draw_arc(at, 39, PI, PI + 0.65, 12, Color("dce5d9"), 1.0, true)
		var title: String = "Colony repertoire" if id == "foraging" else "Lean Foragers" if id == "lean" else "Load Bearers" if id == "load" else "Honeydew relationship"
		view._label(at + Vector2(0, 45), title, color, 15, HORIZONTAL_ALIGNMENT_CENTER)
		var subtitle: String = "Genes and ecological experience" if id == "foraging" else trait_state(status, id) if not ecological else "Ecological · protection active" if status.honeydew.relationship == "tended" else "Ecological · harvested" if status.honeydew.relationship == "exploited" else "Ecological · source observed"
		view._label(at + Vector2(0, 64), subtitle, Color(color, 0.75), 12, HORIZONTAL_ALIGNMENT_CENTER)
