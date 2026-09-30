class_name ScoutAgent
extends RefCounted

const Evidence = preload("res://src/sim/scouting/observation.gd")

var id: String
var origin_pile: String
var position: Vector2
var phase: String = "departing"
var elapsed: float = 0.0
var path: Array[Vector2] = []
var cursor: int = 1
var return_path: Array[Vector2] = []
var mission_target: Vector2
var investigating: String = ""
var investigation_source_id: String = ""
var observations: Dictionary[String, Observation] = {}


func to_dict() -> Dictionary:
	var evidence: Array[Dictionary] = []
	var ids: Array = observations.keys()
	ids.sort()
	for key: String in ids:
		evidence.append(observations[key].to_dict())
	return {"id": id, "mission_id": id, "origin_pile": origin_pile,
		"position": [position.x, position.y], "phase": phase, "elapsed": elapsed,
		"path": _points(path), "cursor": cursor, "return_path": _points(return_path),
		"mission_target": [mission_target.x, mission_target.y], "investigating": investigating,
		"investigation_source_id": investigation_source_id, "observations": evidence}


static func _points(points: Array[Vector2]) -> Array:
	var result: Array = []
	for point: Vector2 in points:
		result.append([point.x, point.y])
	return result


func restore(data: Dictionary, world: WorldState, colony: ColonyState, time: float) -> bool:
	if not data.has_all(["id", "mission_id", "origin_pile", "position", "phase", "elapsed", "path", "cursor", "return_path", "mission_target", "investigating", "observations"]):
		return false
	if not data.id is String or not data.id.begins_with("scout_") or data.mission_id != data.id or not data.origin_pile is String or not colony.piles.has(data.origin_pile):
		return false
	if not data.phase in ["departing", "exploring", "returning", "blocked_exploring", "blocked_returning"] or not _point(data.position, world.bounds):
		return false
	if not typeof(data.elapsed) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.elapsed)) or data.elapsed < 0 or not WorkerLedger.valid_count(data.cursor):
		return false
	if not data.path is Array or not data.return_path is Array or data.path.is_empty() or data.return_path.is_empty() or data.cursor > data.path.size():
		return false
	var restored_path: Array[Vector2] = []
	var restored_return: Array[Vector2] = []
	for pair: Array in [[data.path, restored_path], [data.return_path, restored_return]]:
		for point: Variant in pair[0]:
			if not _point(point, world.bounds):
				return false
			pair[1].append(Vector2(point[0], point[1]))
	var commitments: Dictionary = colony.piles[data.origin_pile].workers.to_dict().commitments
	if not commitments.has(data.id) or commitments[data.id] != {"kind": "scout", "owner_id": data.id, "count": 1}:
		return false
	if restored_return[0] != colony.piles[data.origin_pile].position:
		return false
	for points: Array[Vector2] in [restored_path, restored_return]:
		for index: int in range(1, points.size()):
			var step: Vector2 = (points[index] - points[index - 1]).abs()
			if not is_equal_approx(step.x + step.y, 1.0) or not is_zero_approx(step.x * step.y):
				return false
	var is_returning: bool = data.phase in ["returning", "blocked_returning"]
	var home: Vector2 = colony.piles[data.origin_pile].position
	if (is_returning and restored_path.back() != home) or (not is_returning and (not restored_return.has(restored_path[0]) or data.cursor < 1)):
		return false
	var at := Vector2(data.position[0], data.position[1])
	var cursor_index: int = int(data.cursor)
	if cursor_index == restored_path.size():
		if at != restored_path.back():
			return false
	elif cursor_index > 0:
		var from: Vector2 = restored_path[cursor_index - 1]
		var target: Vector2 = restored_path[cursor_index]
		if absf(at.distance_to(from) + at.distance_to(target) - from.distance_to(target)) > 0.0001:
			return false
	elif at.distance_to(restored_path[0]) > 1.0001:
		return false
	if data.phase == "departing" and (at != home or data.elapsed != 0 or data.cursor != 1):
		return false
	if not _point(data.mission_target, world.bounds) or not data.investigating is String or not data.observations is Array:
		return false
	if not data.get("investigation_source_id", "") is String or (not data.get("investigation_source_id", "").is_empty() and not world.nodes.has(data.investigation_source_id)):
		return false
	var restored_evidence: Dictionary[String, Observation] = {}
	for value: Variant in data.observations:
		var evidence := Evidence.new()
		if not value is Dictionary or not evidence.restore(value, world, colony, time):
			return false
		if evidence.scout_id != data.id or evidence.origin_pile != data.origin_pile or restored_evidence.has(evidence.source_node_id):
			return false
		restored_evidence[evidence.source_node_id] = evidence
	if not data.investigating.is_empty() and not restored_evidence.has(data.investigating):
		return false
	id = data.id
	origin_pile = data.origin_pile
	position = Vector2(data.position[0], data.position[1])
	phase = data.phase
	elapsed = float(data.elapsed)
	path = restored_path
	return_path = restored_return
	cursor = int(data.cursor)
	mission_target = Vector2(data.mission_target[0], data.mission_target[1])
	investigating = data.investigating
	investigation_source_id = data.get("investigation_source_id", "")
	observations = restored_evidence
	return true


static func _point(value: Variant, bounds: Rect2) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for component: Variant in value:
		if not typeof(component) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
			return false
	return bounds.has_point(Vector2(value[0], value[1]))
