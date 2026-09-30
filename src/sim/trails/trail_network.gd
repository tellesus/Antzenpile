class_name TrailNetwork
extends RefCounted

const Route = preload("res://src/sim/trails/trail_route_state.gd")
const Segment = preload("res://src/sim/trails/trail_segment_state.gd")
var routes: Dictionary[String, TrailRouteState] = {}
var segments: Dictionary[String, TrailSegmentState] = {}
var next_route_id: int = 1


func find_route(origin_id: String, knowledge_id: String) -> TrailRouteState:
	for route: TrailRouteState in routes.values():
		if route.origin_pile == origin_id and route.destination_knowledge_id == knowledge_id:
			return route
	return null


func to_dict() -> Dictionary:
	var route_records: Array[Dictionary] = []
	var segment_records: Array[Dictionary] = []
	var ids: Array = routes.keys()
	ids.sort()
	for id: String in ids:
		route_records.append(routes[id].to_dict())
	ids = segments.keys()
	ids.sort()
	for id: String in ids:
		segment_records.append(segments[id].to_dict())
	return {"next_route_id": next_route_id, "routes": route_records, "segments": segment_records}


func restore(data: Dictionary, colony: ColonyState, knowledge: KnowledgeBase, bounds: Rect2) -> bool:
	if not data.has_all(["next_route_id", "routes", "segments"]) or not WorkerLedger.valid_count(data.next_route_id) or data.next_route_id < 1 or not data.routes is Array or not data.segments is Array:
		return false
	var restored_routes: Dictionary[String, TrailRouteState] = {}
	var restored_segments: Dictionary[String, TrailSegmentState] = {}
	var pairs: Dictionary[String, bool] = {}
	for record: Variant in data.routes:
		var route := Route.new()
		if not record is Dictionary or not route.restore(record, colony, knowledge, bounds) or restored_routes.has(route.id):
			return false
		var suffix: String = route.id.trim_prefix("route_")
		if route.id != "route_" + suffix or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_route_id or route.segment_id != "segment_" + suffix:
			return false
		var pair: String = route.origin_pile + ":" + route.destination_knowledge_id
		if pairs.has(pair):
			return false
		pairs[pair] = true
		restored_routes[route.id] = route
	for record: Variant in data.segments:
		var segment := Segment.new()
		if not record is Dictionary or not segment.restore(record, bounds) or restored_segments.has(segment.id):
			return false
		restored_segments[segment.id] = segment
	if restored_routes.size() != restored_segments.size():
		return false
	var used_segments: Dictionary[String, bool] = {}
	for route: TrailRouteState in restored_routes.values():
		if not restored_segments.has(route.segment_id) or used_segments.has(route.segment_id):
			return false
		used_segments[route.segment_id] = true
		var segment: TrailSegmentState = restored_segments[route.segment_id]
		if segment.route_id != route.id or segment.start != colony.piles[route.origin_pile].position or segment.end != route.estimated_destination:
			return false
		var commitment: String = "trail:" + route.id
		var ledger: WorkerLedger = colony.piles[route.origin_pile].workers
		if route.status == "active":
			var record: Dictionary = ledger.to_dict().commitments.get(commitment, {})
			if record.get("kind") != "trail" or record.get("owner_id") != route.id or record.get("count") != route.allocated_workers:
				return false
		elif ledger.count(commitment) != -1:
			return false
	for pile: PileState in colony.piles.values():
		for id: String in pile.workers.to_dict().commitments:
			var entry: Dictionary = pile.workers.to_dict().commitments[id]
			if entry.kind == "trail" or id.begins_with("trail:"):
				var route_id: String = id.trim_prefix("trail:")
				if id != "trail:" + route_id or not restored_routes.has(route_id) or restored_routes[route_id].origin_pile != pile.id or restored_routes[route_id].status != "active" or entry.kind != "trail" or entry.owner_id != route_id:
					return false
	routes = restored_routes
	segments = restored_segments
	next_route_id = int(data.next_route_id)
	return true
