class_name TrailSegmentState
extends RefCounted
## Distinct estimated infrastructure; chemical fields are separate from familiarity.

var id: String
var route_id: String
var start: Vector2
var end: Vector2
var pheromone_strength: float = 0.0
var route_familiarity: float = 0.0
var traffic: int = 0


func to_dict() -> Dictionary:
	return {"id": id, "route_id": route_id,
		"start": [start.x, start.y], "end": [end.x, end.y],
		"pheromone_strength": pheromone_strength,
		"route_familiarity": route_familiarity, "traffic": traffic}


func restore(data: Dictionary, bounds: Rect2) -> bool:
	if not data.has_all(["id", "route_id", "start", "end", "pheromone_strength", "route_familiarity", "traffic"]):
		return false
	if not data.id is String or data.id.is_empty() or not data.route_id is String or data.route_id.is_empty():
		return false
	for key: String in ["start", "end"]:
		if not data[key] is Array or data[key].size() != 2:
			return false
		for value: Variant in data[key]:
			if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
				return false
	var origin := Vector2(data.start[0], data.start[1])
	var destination := Vector2(data.end[0], data.end[1])
	if not bounds.has_point(origin) or not bounds.has_point(destination) or origin == destination:
		return false
	if not typeof(data.pheromone_strength) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.pheromone_strength)) or data.pheromone_strength < 0.0 or data.pheromone_strength > 1.0:
		return false
	if not typeof(data.route_familiarity) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.route_familiarity)) or data.route_familiarity < 0.0 or data.route_familiarity > 1.0:
		return false
	if not WorkerLedger.valid_count(data.traffic):
		return false
	id = data.id
	route_id = data.route_id
	start = origin
	end = destination
	pheromone_strength = float(data.pheromone_strength)
	route_familiarity = float(data.route_familiarity)
	traffic = int(data.traffic)
	return true
