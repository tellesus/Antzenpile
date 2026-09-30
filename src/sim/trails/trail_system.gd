extends RefCounted
## Explicit route investment; no travelers or resource delivery yet.

const Route = preload("res://src/sim/trails/trail_route_state.gd")
const Segment = preload("res://src/sim/trails/trail_segment_state.gd")
const CONFIG = preload("res://data/trails/default_trails.tres")
var last_error: String = ""
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state


func create_route(origin_id: String, knowledge_id: String) -> bool:
	if not _run.colony.piles.has(origin_id) or not _run.knowledge.nodes.has(knowledge_id):
		return _reject("Destination is not known to this colony")
	var existing: TrailRouteState = _run.trails.find_route(origin_id, knowledge_id)
	if existing != null:
		if existing.status == "inactive":
			return set_workers(existing.id, CONFIG.initial_workers)
		return _reject("A route to this destination already exists")
	var pile: PileState = _run.colony.piles[origin_id]
	var estimate: Vector2 = _run.knowledge.nodes[knowledge_id].estimated_position
	if not estimate.is_finite() or estimate == pile.position:
		return _reject("Destination has no usable direction")
	if _run.trails.next_route_id >= WorkerLedger.MAX_COUNT:
		return _reject("Route ID unavailable")
	if pile.workers_available < CONFIG.initial_workers:
		return _reject("Not enough available workers")
	var id: String = "route_%d" % _run.trails.next_route_id
	var commitment: String = "trail:" + id
	if pile.workers.count(commitment) >= 0 or not pile.workers.create_commitment(commitment, "trail", id):
		return _reject("Trail commitment unavailable")
	if not pile.workers.allocate(commitment, CONFIG.initial_workers):
		pile.workers.retire_commitment(commitment)
		return _reject("Not enough available workers")
	var route := Route.new()
	route.id = id
	route.origin_pile = origin_id
	route.destination_knowledge_id = knowledge_id
	route.estimated_destination = estimate
	route.segment_id = "segment_%d" % _run.trails.next_route_id
	route.desired_workers = CONFIG.initial_workers
	route.allocated_workers = CONFIG.initial_workers
	route.status = "active"
	var segment := Segment.new()
	segment.id = route.segment_id
	segment.route_id = route.id
	segment.start = pile.position
	segment.end = estimate
	_run.trails.routes[id] = route
	_run.trails.segments[segment.id] = segment
	_run.trails.next_route_id += 1
	last_error = ""
	return true


func set_workers(route_id: String, target: Variant) -> bool:
	if not _run.trails.routes.has(route_id) or typeof(target) != TYPE_INT or not WorkerLedger.valid_count(target):
		return _reject("Unknown route or invalid worker target")
	var route: TrailRouteState = _run.trails.routes[route_id]
	var pile: PileState = _run.colony.piles[route.origin_pile]
	var commitment: String = "trail:" + route.id
	var requested: int = int(target)
	if requested == route.desired_workers:
		last_error = ""
		return true
	if requested > route.allocated_workers:
		var needed: int = requested - route.allocated_workers
		if pile.workers_available < needed:
			return _reject("Not enough available workers")
		if route.status == "inactive" and not pile.workers.create_commitment(commitment, "trail", route.id):
			return _reject("Trail commitment unavailable")
		if not pile.workers.allocate(commitment, needed):
			if route.status == "inactive":
				pile.workers.retire_commitment(commitment)
			return _reject("Could not allocate workers")
	else:
		if not pile.workers.release(commitment, route.allocated_workers - requested):
			return _reject("Could not release workers")
		if requested == 0:
			assert(pile.workers.retire_commitment(commitment))
	route.desired_workers = requested
	route.allocated_workers = requested
	route.status = "inactive" if requested == 0 else "active"
	last_error = ""
	return true


func _reject(reason: String) -> bool:
	last_error = reason
	return false
