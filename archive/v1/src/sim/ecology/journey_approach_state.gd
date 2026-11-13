class_name JourneyApproachState
extends RefCounted
## Candidate course stays private until a complete returning survey.
var candidate: TrailSegmentState
var reached: bool = false
var blocked: bool = false
var reports: Dictionary = {}
var established_at: Dictionary[String, float] = {}

func to_dict() -> Dictionary:
	return {"candidate":candidate.to_dict() if candidate != null else {},"reached":reached,"blocked":blocked,"reports":reports.duplicate(true),"established_at":established_at.duplicate()}

func reset_party() -> void:
	candidate = null; reached = false; blocked = false

func restore(data: Variant, party: Dictionary, trails: TrailNetwork, world: WorldState, time: float) -> bool:
	if not data is Dictionary or data.size() != 5 or not data.has_all(to_dict().keys()) or not data.candidate is Dictionary or not data.reached is bool or not data.blocked is bool or not data.reports is Dictionary or not data.established_at is Dictionary: return false
	if not data.candidate.is_empty():
		if party.phase == "idle" or not trails.routes.has(party.route_id) or party.defense.mode != "investigate": return false
		var restored := TrailSegmentState.new()
		var base: TrailSegmentState = trails.segments[trails.routes[party.route_id].segment_id]
		if not restored.restore(data.candidate,world.bounds) or restored.waypoints.size() != 2 or restored.id != base.id or restored.route_id != base.route_id or restored.start != base.start or restored.end != base.end or trails.routes[party.route_id].allocated_workers > 0: return false
		if data.reached and party.phase != "inbound": return false
		candidate = restored
	elif data.reached or data.blocked: return false
	for id: Variant in data.reports:
		var record: Variant = data.reports[id]
		if not id is String or not trails.routes.has(id) or trails.routes[id].purpose != "food" or not record is Dictionary or record.size() != 3 or not record.has_all(["outcome","received_at","length"]): return false
		if record.outcome not in ["found","danger","unconfirmed"]: return false
		for key: String in ["received_at","length"]:
			if not typeof(record[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record[key])) or record[key] <= 0: return false
		if record.received_at > time: return false
	for id: Variant in data.established_at:
		var value: Variant = data.established_at[id]
		if not id is String or not trails.routes.has(id) or not data.reports.has(id) or trails.segments[trails.routes[id].segment_id].waypoints.is_empty() or not typeof(value) in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or value <= 0 or value > data.reports[id].received_at: return false
		established_at[id] = float(value)
	for route: TrailRouteState in trails.routes.values():
		if not trails.segments[route.segment_id].waypoints.is_empty() and not established_at.has(route.id): return false
	reached = data.reached; blocked = data.blocked; reports = data.reports.duplicate(true)
	return true
