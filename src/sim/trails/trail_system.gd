extends RefCounted
## Explicit route investment and bounded aggregate transit.

const Route = preload("res://src/sim/trails/trail_route_state.gd")
const Segment = preload("res://src/sim/trails/trail_segment_state.gd")
const Cohort = preload("res://src/sim/trails/transit_cohort.gd")
const Detour = preload("res://src/sim/trails/trail_detour.gd")
const Pathfinder = preload("res://src/sim/scouting/scout_pathfinder.gd")
const CONFIG = preload("res://data/trails/default_trails.tres")
const PREDATOR_CONFIG = preload("res://data/ecology/backyard_predator.tres")
const SCOUT_CONFIG = preload("res://data/scouting/default_scouts.tres")
var last_error: String = ""
var _run: RunState
var _predator: PredatorSystem


func _init(run_state: RunState, predator_system: PredatorSystem = null) -> void:
	_run = run_state
	_predator = predator_system if predator_system != null else PredatorSystem.new(run_state)


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
	segment.exposure = Segment.exposure_for(_run.world, segment.start, segment.end)
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
	var expected: int = route.allocated_workers + _run.trails.pending_losses(route.id)
	if requested == route.desired_workers and requested <= expected:
		last_error = ""
		return true
	if requested > expected:
		var needed: int = requested - expected
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
		if pile.workers.count(commitment) >= 0:
			var retired: bool = pile.workers.retire_commitment(commitment)
			assert(retired)
		route.status = "inactive"
		route.departure_cooldown_ticks = 0
	else:
		route.status = "recalling" if requested == 0 else "depleted" if route.reported_depleted else "active"
	if route.status != "active":
		route.energy_limited = false
	last_error = ""
	return true


func recheck(route_id: String) -> bool:
	if not _run.trails.routes.has(route_id):
		return _reject("Unknown trail")
	var route: TrailRouteState = _run.trails.routes[route_id]
	if route.status != "depleted" or not route.reported_depleted or route.desired_workers <= 0 or route.allocated_workers <= 0:
		return _reject("Trail is not ready to recheck")
	if route.active_workers > 0:
		return _reject("Wait for travelling workers")
	var pile: PileState = _run.colony.piles[route.origin_pile]
	if pile.workers.count("trail:" + route.id) != route.allocated_workers:
		return _reject("Trail labor is unavailable")
	# This changes colony intent only; hidden source truth is checked at outbound arrival.
	route.reported_depleted = false
	route.status = "active"
	route.departure_cooldown_ticks = 0
	route.energy_limited = false
	last_error = ""
	return true


func tick(delta: float) -> void:
	# Every existing segment fades, including inactive and depleted routes.
	for segment: TrailSegmentState in _run.trails.segments.values():
		segment.pheromone_strength = snappedf(segment.pheromone_strength * pow(0.5, delta / CONFIG.pheromone_half_life_seconds), 0.0000000001)
		if segment.pheromone_strength < 0.0001:
			segment.pheromone_strength = 0.0
		segment.route_familiarity = snappedf(segment.route_familiarity * pow(0.5, delta / CONFIG.familiarity_half_life_seconds), 0.0000000001)
		if segment.route_familiarity < 0.0001:
			segment.route_familiarity = 0.0
	var ids: Array = _run.trails.routes.keys()
	ids.sort()
	for id: String in ids:
		var route: TrailRouteState = _run.trails.routes[id]
		route.departure_cooldown_ticks = maxi(0, route.departure_cooldown_ticks - 1)
	ids = _run.trails.cohorts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.trim_prefix("cohort_").to_int() < b.trim_prefix("cohort_").to_int())
	for id: String in ids:
		var cohort: TransitCohort = _run.trails.cohorts[id]
		var route: TrailRouteState = _run.trails.routes[cohort.route_id]
		if cohort.detour != null:
			if cohort.detour.tick(_run.world, _run.rng, _run.simulation_time):
				cohort.detour_report = cohort.detour.observation.detached_copy()
				cohort.detour = null
			continue
		_encounter(cohort, route)
		if cohort.worker_count > 0 and cohort.direction == "outbound" and _maybe_detour(cohort, route):
			continue
		cohort.remaining_ticks -= 1
		if cohort.remaining_ticks > 0:
			continue
		if cohort.direction == "outbound":
			if cohort.worker_count > 0:
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


func _encounter(cohort: TransitCohort, route: TrailRouteState) -> void:
	if cohort.worker_count == 0 or cohort.predator_encountered or _run.clock.tick_count < PREDATOR_CONFIG.first_tick:
		return
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var progress: float = 1.0 - float(cohort.remaining_ticks) / _leg_ticks(route)
	if cohort.direction == "inbound":
		progress = 1.0 - progress
	var point: Vector2 = segment.start.lerp(segment.end, progress)
	if point.distance_to(PREDATOR_CONFIG.position) > PREDATOR_CONFIG.radius:
		return
	# Saturated encounters still consume this journey's one opportunity.
	cohort.predator_encountered = true
	if not _predator.encounter(point):
		return
	var pile: PileState = _run.colony.piles[route.origin_pile]
	var adapted: int = 1 if _run.rng.randf() < pile.adaptation_fraction() else 0
	var removed: bool = pile.lose_workers("trail:" + route.id, 1, adapted, "ambush")
	assert(removed)
	route.allocated_workers -= 1
	route.active_workers -= 1
	cohort.worker_count -= 1
	cohort.lost_workers = 1
	cohort.adapted_lost_workers = adapted
	cohort.payload = minf(cohort.payload, cohort.worker_count * CONFIG.carry_per_worker * cohort.carry_multiplier)
	if cohort.payload == 0.0:
		cohort.resource_id = ""
	if cohort.worker_count == 0:
		cohort.detour_report = null
	if route.allocated_workers == 0:
		var retired: bool = pile.workers.retire_commitment("trail:" + route.id)
		assert(retired)
		route.status = "inactive"
		route.energy_limited = false
		route.departure_cooldown_ticks = 0


func _maybe_detour(cohort: TransitCohort, route: TrailRouteState) -> bool:
	if cohort.detour_attempted or _run.active_scout_count() >= SCOUT_CONFIG.active_cap or _run.next_scout_id >= WorkerLedger.MAX_COUNT:
		return false
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var progress: float = 1.0 - float(cohort.remaining_ticks) / float(_leg_ticks(route))
	var join: Vector2 = segment.start.lerp(segment.end, progress).round()
	if not _run.world.bounds.has_point(join) or not is_finite(Pathfinder.travel_cost(_run.world, join)):
		return false
	var ids: Array = _run.world.nodes.keys()
	ids.sort()
	for source_id: String in ids:
		var node: WorldNodeState = _run.world.nodes[source_id]
		if not node.active or node.quantity <= 0.0 or _run.knowledge.nodes.has("known:" + source_id) or join.distance_to(node.position) > SCOUT_CONFIG.sense_radius or _pending_detour(route.id, source_id):
			continue
		cohort.detour_attempted = true
		if _run.rng.randf() >= CONFIG.side_scout_chance:
			return false
		var detour := Detour.new()
		detour.id = "scout_%d" % _run.next_scout_id
		detour.source_id = source_id
		detour.origin_pile = route.origin_pile
		detour.position = join
		detour.sample(_run.world, _run.rng, _run.simulation_time)
		if detour.observation == null:
			return false
		var target: Vector2 = detour.observation.estimated_position.round()
		var path: Array[Vector2] = Pathfinder.new(_run.world).path(join, target)
		if path.size() < 2 or path.size() > CONFIG.side_scout_max_steps + 1:
			return false
		detour.path = path
		cohort.detour = detour
		_run.next_scout_id += 1
		return true
	return false


func _pending_detour(route_id: String, source_id: String) -> bool:
	for other: TransitCohort in _run.trails.cohorts.values():
		if other.route_id == route_id and ((other.detour != null and other.detour.source_id == source_id) or (other.detour_report != null and other.detour_report.source_node_id == source_id)):
			return true
	return false


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
	var worker_count: int = mini(idle, CONFIG.workers_per_cohort)
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var length: float = segment.start.distance_to(segment.end)
	var terrain_cost: float = Segment.terrain_cost_for(_run.world, segment.start, segment.end)
	var pile: PileState = _run.colony.piles[route.origin_pile]
	var fraction: float = pile.adaptation_fraction()
	# Quantize captured phenotype to the same stable decimal precision used for resource debits.
	var energy_multiplier: float = roundf(AdaptationRules.energy_multiplier(pile.adaptation_repertoire, fraction) * 100000.0) / 100000.0
	var carry_multiplier: float = roundf(AdaptationRules.carry_multiplier(pile.adaptation_repertoire, fraction) * 100000.0) / 100000.0
	var energy_cost: float = CONFIG.round_trip_energy_cost(worker_count, length, terrain_cost) * energy_multiplier
	var unpaid_energy_cost: float = 0.0
	if pile.resources.carbohydrate < energy_cost:
		# A carbohydrate trip can replenish an exhausted pile. Pay the available reserve
		# now and settle the remainder against its cargo; other routes must wait.
		if _run.knowledge.nodes[route.destination_knowledge_id].definition_id != "carbohydrate":
			route.energy_limited = true
			return
		var available: float = pile.resources.carbohydrate
		unpaid_energy_cost = roundf((energy_cost - available) * 100000.0) / 100000.0
		if not pile.consume_resources({"carbohydrate": available}):
			return
	elif not pile.consume_resources({"carbohydrate": energy_cost}):
		return
	var cohort := Cohort.new()
	cohort.id = "cohort_%d" % _run.trails.next_cohort_id
	cohort.route_id = route.id
	cohort.worker_count = worker_count
	cohort.unpaid_energy_cost = unpaid_energy_cost
	cohort.energy_multiplier = energy_multiplier
	cohort.carry_multiplier = carry_multiplier
	cohort.remaining_ticks = _leg_ticks(route)
	_run.trails.cohorts[cohort.id] = cohort
	_run.trails.next_cohort_id += 1
	route.active_workers += cohort.worker_count
	route.departure_cooldown_ticks = CONFIG.departure_interval_ticks
	route.energy_limited = false


func _collect(cohort: TransitCohort, route: TrailRouteState) -> void:
	var source_id: String = _run.knowledge.nodes[route.destination_knowledge_id].source_node_id
	if not _run.world.nodes.has(source_id):
		return
	var node: WorldNodeState = _run.world.nodes[source_id]
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	if not node.active or node.quantity <= 0.0 or node.position.distance_to(route.estimated_destination) > CONFIG.interaction_radius * (1.0 + 0.5 * reliability(segment)):
		return
	var amount: float = minf(node.quantity, cohort.worker_count * CONFIG.carry_per_worker * cohort.carry_multiplier)
	node.quantity = maxf(0.0, node.quantity - amount)
	if node.quantity == 0.0:
		node.active = false
	cohort.payload = amount
	cohort.resource_id = node.definition_id


func _arrive_home(cohort: TransitCohort, route: TrailRouteState) -> void:
	var pile: PileState = _run.colony.piles[route.origin_pile]
	if cohort.detour_report != null:
		assert(not _run.delivered_observations.has(cohort.detour_report.id))
		_run.delivered_observations[cohort.detour_report.id] = cohort.detour_report.detached_copy()
	if cohort.lost_workers > 0:
		route.reported_losses += cohort.lost_workers
		route.last_loss_time = _run.simulation_time
	var source_id: String = _run.knowledge.nodes[route.destination_knowledge_id].source_node_id
	if cohort.worker_count > 0:
		var recorded: bool = _run.knowledge.record_outcome(source_id, cohort.payload > 0.0, _run.simulation_time, "trail")
		assert(recorded)
	if cohort.payload > 0.0:
		var net_payload: float = maxf(0.0, cohort.payload - cohort.unpaid_energy_cost)
		var deposited: bool = pile.deposit_resource(cohort.resource_id, net_payload)
		assert(deposited)
		route.delivered_total += net_payload
		var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
		segment.pheromone_strength = snappedf(clampf(segment.pheromone_strength + cohort.worker_count * CONFIG.pheromone_per_returning_worker, 0.0, 1.0), 0.0000000001)
		segment.route_familiarity = snappedf(clampf(segment.route_familiarity + cohort.worker_count * CONFIG.familiarity_per_returning_worker, 0.0, 1.0), 0.0000000001)
		segment.traffic += mini(cohort.worker_count, WorkerLedger.MAX_COUNT - segment.traffic)
	elif cohort.worker_count > 0:
		route.reported_depleted = true
		route.energy_limited = false
	route.active_workers -= cohort.worker_count
	var release_count: int = mini(route.allocated_workers - route.desired_workers, route.allocated_workers - route.active_workers)
	if release_count > 0:
		var released: bool = pile.workers.release("trail:" + route.id, release_count)
		assert(released)
		route.allocated_workers -= release_count
	if route.allocated_workers == 0:
		if pile.workers.count("trail:" + route.id) >= 0:
			var retired: bool = pile.workers.retire_commitment("trail:" + route.id)
			assert(retired)
		route.status = "inactive"
		route.departure_cooldown_ticks = 0
	else:
		route.status = "recalling" if route.desired_workers == 0 else "depleted" if route.reported_depleted else "active"


func _leg_ticks(route: TrailRouteState) -> int:
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	return CONFIG.leg_ticks(segment.start.distance_to(segment.end))


static func reliability(segment: TrailSegmentState) -> float:
	return clampf(0.5 * segment.pheromone_strength + 0.5 * segment.route_familiarity, 0.0, 1.0)


func _reject(reason: String) -> bool:
	last_error = reason
	return false
