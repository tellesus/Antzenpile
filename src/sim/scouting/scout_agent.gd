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
var standing: bool = false
var need_weights: Dictionary[String, float] = {}
var search_memory: Dictionary[String, float] = {}
var known_sources: Array[String] = []
var trunk_route_id: String = ""
var trunk_path: Array[Vector2] = []
var observations: Dictionary[String, Observation] = {}
var predator_encountered: bool = false
var lost: bool = false
var lost_profile: String = ""
var expected_tick: int = 0


func pending_trait(trait_id: String) -> int:
	return 1 if lost and trait_id in GeneticRepertoire.traits_for(lost_profile) else 0


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
		"investigation_source_id": investigation_source_id, "standing": standing, "observations": evidence,
		"need_weights": need_weights.duplicate(), "search_memory": search_memory.duplicate(), "known_sources": known_sources.duplicate(),
		"trunk_route_id": trunk_route_id, "trunk_path": _points(trunk_path),
		"survival": {"encountered": predator_encountered, "lost": lost,
			"profile": lost_profile, "expected_tick": expected_tick}}


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
	if not data.phase in ["departing", "following_trail", "blocked_following_trail", "exploring", "returning", "blocked_exploring", "blocked_returning"] or not _point(data.position, world.bounds):
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
	var survival: Variant = data.get("survival", {"encountered": false, "lost": false, "profile": "", "expected_tick": 0})
	if not survival is Dictionary or survival.size() != 4 or not survival.has_all(["encountered", "lost", "profile", "expected_tick"]):
		return false
	if not survival.encountered is bool or not survival.lost is bool or not survival.profile is String or not WorkerLedger.valid_count(survival.expected_tick):
		return false
	if not data.observations is Array:
		return false
	if survival.lost:
		if not survival.encountered or survival.expected_tick <= floori(time / SimulationClock.TICK_INTERVAL) or not data.observations.is_empty():
			return false
		var pile: PileState = colony.piles[data.origin_pile]
		if survival.profile != "" and pile.genetics.lost.get(survival.profile, 0) < 1:
			return false
	elif survival.profile != "":
		return false
	if not commitments.has(data.id) or commitments[data.id] != {"kind": "scout", "owner_id": data.id, "count": 0 if survival.lost else 1}:
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
	if not data.get("standing", false) is bool or data.get("standing", false) and data.origin_pile != "home":
		return false
	var needs: Variant = data.get("need_weights", {})
	var memory: Variant = data.get("search_memory", {})
	var familiar: Variant = data.get("known_sources", [])
	if not familiar is Array:
		return false
	var restored_familiar: Array[String] = []
	for key: Variant in familiar:
		if not key is String or not world.nodes.has(key) or key in restored_familiar or not data.get("standing", false):
			return false
		restored_familiar.append(key)
	if not needs is Dictionary or not memory is Dictionary or not data.get("standing", false) and (not needs.is_empty() or not memory.is_empty()):
		return false
	var restored_needs: Dictionary[String, float] = {}
	for key: Variant in needs:
		if key not in PileState.RESOURCE_IDS or not typeof(needs[key]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(needs[key])) or needs[key] < 1 or needs[key] > 1 + load("res://data/scouting/default_scouts.tres").need_weight:
			return false
		restored_needs[key] = roundf(float(needs[key]) * 1e8) / 1e8
	var memory_check := ExplorationState.new()
	if not memory_check.restore({"target": 0, "bias": null, "cooldown_ticks": 0, "coverage": memory}, world, time):
		return false
	var trunk_id: Variant = data.get("trunk_route_id", "")
	var trunk: Variant = data.get("trunk_path", [])
	if not trunk_id is String or not trunk is Array or trunk_id.is_empty() != trunk.is_empty():
		return false
	var restored_trunk: Array[Vector2] = []
	if not trunk.is_empty():
		if not data.get("standing", false) or not data.get("investigation_source_id", "").is_empty() or trunk.size() < 2:
			return false
		for point: Variant in trunk:
			if not _point(point, world.bounds):
				return false
			var step := Vector2(point[0], point[1])
			if step != step.round() or step in restored_trunk or not restored_trunk.is_empty() and absf((step - restored_trunk.back()).abs().x + (step - restored_trunk.back()).abs().y - 1.0) > 0.0001:
				return false
			restored_trunk.append(step)
		if restored_trunk[0] != home:
			return false
	if data.phase in ["following_trail", "blocked_following_trail"] or data.phase == "departing" and not restored_trunk.is_empty():
		if restored_trunk.is_empty() or restored_path != restored_trunk or data.elapsed != 0 or restored_return != restored_trunk.slice(0, restored_return.size()):
			return false
	var restored_evidence: Dictionary[String, Observation] = {}
	for value: Variant in data.observations:
		var evidence := Evidence.new()
		if not value is Dictionary or not evidence.restore(value, world, colony, time):
			return false
		if data.get("standing", false) and not evidence.collective_search:
			# Pre-065 private standing samples were rounded by sensing but did
			# not acquire collective provenance until delivery. Keep their precision.
			var rounded_radius: float = roundf(evidence.uncertainty_radius * 1e8) / 1e8
			if absf(rounded_radius - evidence.uncertainty_radius) <= 1e-15:
				evidence.uncertainty_radius = rounded_radius
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
	standing = data.get("standing", false)
	need_weights = restored_needs
	search_memory = memory_check.coverage
	known_sources = restored_familiar
	trunk_route_id = trunk_id
	trunk_path = restored_trunk
	observations = restored_evidence
	predator_encountered = survival.encountered
	lost = survival.lost
	lost_profile = survival.profile
	expected_tick = int(survival.expected_tick)
	return true


static func _point(value: Variant, bounds: Rect2) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for component: Variant in value:
		if not typeof(component) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
			return false
	return bounds.has_point(Vector2(value[0], value[1]))
