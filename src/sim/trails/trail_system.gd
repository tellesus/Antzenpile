extends RefCounted
## Explicit route investment and bounded aggregate transit.

const Route = preload("res://src/sim/trails/trail_route_state.gd")
const Segment = preload("res://src/sim/trails/trail_segment_state.gd")
const Cohort = preload("res://src/sim/trails/transit_cohort.gd")
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
		if existing.status in ["inactive", "recalling"]:
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
		route.allocated_workers += needed
	else:
		var releasable: int = mini(route.allocated_workers - requested, route.allocated_workers - route.active_workers)
		if releasable > 0:
			if not pile.workers.release(commitment, releasable):
				return _reject("Could not release workers")
			route.allocated_workers -= releasable
	if route.status == "inactive" and requested > 0:
		route.reported_depleted = false
	route.desired_workers = requested
	if route.allocated_workers == 0:
		var retired: bool = pile.workers.retire_commitment(commitment)
		assert(retired)
		route.status = "inactive"
		route.departure_cooldown_ticks = 0
	else:
		route.status = "recalling" if requested == 0 else "depleted" if route.reported_depleted else "active"
	last_error = ""
	return true


func tick(delta: float) -> void:
	# Every existing segment fades, including inactive and depleted routes.
	for segment: TrailSegmentState in _run.trails.segments.values():
		segment.pheromone_strength *= pow(0.5, delta / CONFIG.pheromone_half_life_seconds)
		if segment.pheromone_strength < 0.0001:
			segment.pheromone_strength = 0.0
	var ids: Array = _run.trails.routes.keys()
	ids.sort()
	for id: String in ids:
		var route: TrailRouteState = _run.trails.routes[id]
		route.departure_cooldown_ticks = maxi(0, route.departure_cooldown_ticks - 1)
	ids = _run.trails.cohorts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.trim_prefix("cohort_").to_int() < b.trim_prefix("cohort_").to_int())
	for id: String in ids:
		var cohort: TransitCohort = _run.trails.cohorts[id]
		cohort.remaining_ticks -= 1
		if cohort.remaining_ticks > 0:
			continue
		var route: TrailRouteState = _run.trails.routes[cohort.route_id]
		if cohort.direction == "outbound":
			_collect(cohort, route)
			cohort.direction = "inbound"
			cohort.remaining_ticks = _leg_ticks(route)
		else:
			_arrive_home(cohort, route)
			_run.trails.cohorts.erase(id)
	ids = _run.trails.routes.keys()
	ids.sort()
	for id: String in ids:
		var route: TrailRouteState = _run.trails.routes[id]
		if route.status == "active" and route.departure_cooldown_ticks == 0:
			_depart(route)


func _depart(route: TrailRouteState) -> void:
	var idle: int = route.allocated_workers - route.active_workers
	if idle <= 0 or _run.trails.next_cohort_id >= WorkerLedger.MAX_COUNT:
		return
	var count: int = 0
	for cohort: TransitCohort in _run.trails.cohorts.values():
		if cohort.route_id == route.id:
			count += 1
	if count >= CONFIG.max_cohorts_per_route:
		return
	var cohort := Cohort.new()
	cohort.id = "cohort_%d" % _run.trails.next_cohort_id
	cohort.route_id = route.id
	cohort.worker_count = mini(idle, CONFIG.workers_per_cohort)
	cohort.remaining_ticks = _leg_ticks(route)
	_run.trails.cohorts[cohort.id] = cohort
	_run.trails.next_cohort_id += 1
	route.active_workers += cohort.worker_count
	route.departure_cooldown_ticks = CONFIG.departure_interval_ticks


func _collect(cohort: TransitCohort, route: TrailRouteState) -> void:
	var source_id: String = _run.knowledge.nodes[route.destination_knowledge_id].source_node_id
	if not _run.world.nodes.has(source_id):
		return
	var node: WorldNodeState = _run.world.nodes[source_id]
	if not node.active or node.quantity <= 0.0 or node.position.distance_to(route.estimated_destination) > CONFIG.interaction_radius:
		return
	var amount: float = minf(node.quantity, cohort.worker_count * CONFIG.carry_per_worker)
	node.quantity = maxf(0.0, node.quantity - amount)
	if node.quantity == 0.0:
		node.active = false
	cohort.payload = amount
	cohort.resource_id = node.definition_id


func _arrive_home(cohort: TransitCohort, route: TrailRouteState) -> void:
	var pile: PileState = _run.colony.piles[route.origin_pile]
	if cohort.payload > 0.0:
		var deposited: bool = pile.deposit_resource(cohort.resource_id, cohort.payload)
		assert(deposited)
		route.delivered_total += cohort.payload
		var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
		segment.pheromone_strength = clampf(segment.pheromone_strength + cohort.worker_count * CONFIG.pheromone_per_returning_worker, 0.0, 1.0)
		segment.traffic += mini(cohort.worker_count, WorkerLedger.MAX_COUNT - segment.traffic)
	else:
		route.reported_depleted = true
	route.active_workers -= cohort.worker_count
	var release_count: int = mini(route.allocated_workers - route.desired_workers, route.allocated_workers - route.active_workers)
	if release_count > 0:
		var released: bool = pile.workers.release("trail:" + route.id, release_count)
		assert(released)
		route.allocated_workers -= release_count
	if route.allocated_workers == 0:
		var retired: bool = pile.workers.retire_commitment("trail:" + route.id)
		assert(retired)
		route.status = "inactive"
		route.departure_cooldown_ticks = 0
	else:
		route.status = "recalling" if route.desired_workers == 0 else "depleted" if route.reported_depleted else "active"


func _leg_ticks(route: TrailRouteState) -> int:
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	return CONFIG.leg_ticks(segment.start.distance_to(segment.end))


func _reject(reason: String) -> bool:
	last_error = reason
	return false
