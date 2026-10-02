class_name JourneyResponseSystem
extends RefCounted
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
const PREDATOR = preload("res://data/ecology/backyard_predator.tres")
const RIVAL = preload("res://data/ecology/backyard_rival.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
var _run: RunState
var last_error: String = ""
func _init(run_state: RunState): _run = run_state

func investigate(route_id: String) -> bool:
	var state: JourneyResponseState = _run.journey_response
	if state.active() or not _run.trails.routes.has(route_id): return _reject("Another party is away or the journey is unknown")
	var route: TrailRouteState = _run.trails.routes[route_id]
	if route.origin_pile != "home" or route.reported_losses <= 0: return _reject("A returned journey loss is required")
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var pile: PileState = _run.colony.piles.home
	var cost: float = TRAILS.round_trip_energy_cost(CONFIG.investigation_workers,segment.start.distance_to(segment.end),TrailSegmentState.terrain_cost_for(_run.world,segment.start,segment.end))
	if pile.workers_available < CONFIG.investigation_workers or pile.resources.carbohydrate < cost: return _reject("Needs three available workers and travel food")
	if not pile.workers.create_commitment("journey:home","other",route_id): return _reject("Party commitment unavailable")
	var allocated: bool = pile.workers.allocate("journey:home",CONFIG.investigation_workers)
	var paid: bool = pile.consume_resources({"carbohydrate":cost})
	assert(allocated and paid)
	state.route_id = route_id; state.phase = "outbound"; state.workers = CONFIG.investigation_workers; state.departed_at = _run.simulation_time
	last_error = ""; return true

func recall() -> bool:
	var state: JourneyResponseState = _run.journey_response
	if not state.active(): return _reject("No party is away")
	if state.phase == "outbound":
		state.elapsed_ticks = _leg() - state.elapsed_ticks
		state.phase = "inbound"
		if state.elapsed_ticks >= _leg(): _arrive()
	last_error = ""; return true

func tick() -> void:
	var state: JourneyResponseState = _run.journey_response
	if not state.active(): return
	if state.phase == "outbound": _sample()
	state.elapsed_ticks += 1
	if state.elapsed_ticks < _leg(): return
	if state.phase == "outbound": state.phase = "inbound"; state.elapsed_ticks = 0
	else: _arrive()

func _leg() -> int:
	var segment: TrailSegmentState = _run.trails.segments[_run.trails.routes[_run.journey_response.route_id].segment_id]
	return TRAILS.leg_ticks(segment.start.distance_to(segment.end))

func _sample() -> void:
	var state: JourneyResponseState = _run.journey_response
	var segment: TrailSegmentState = _run.trails.segments[_run.trails.routes[state.route_id].segment_id]
	var fraction: float = float(state.elapsed_ticks) / _leg()
	var point: Vector2 = segment.start.lerp(segment.end,fraction)
	# Cautious survey senses nearby danger without using its position as a navigation target.
	if state.ambush_fraction < 0 and _run.clock.tick_count >= PREDATOR.first_tick and point.distance_to(PREDATOR.position) <= PREDATOR.radius + CONFIG.survey_radius:
		state.ambush_fraction = snappedf(fraction,0.05); state.sampled_at = _run.simulation_time
	if not state.foreign_seen and _run.rival.pheromone >= 0.1 and _run.world.nodes.has(RIVAL.food_id):
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point,RIVAL.pile_position,_run.world.nodes[RIVAL.food_id].position)
		if point.distance_to(nearest) <= RIVAL.contact_radius:
			state.foreign_seen = true; state.sampled_at = _run.simulation_time

func _arrive() -> void:
	var state: JourneyResponseState = _run.journey_response
	var finding: String = "mixed" if state.ambush_fraction >= 0 and state.foreign_seen else "ambush" if state.ambush_fraction >= 0 else "foreign" if state.foreign_seen else "inconclusive"
	state.reports[state.route_id] = {"finding":finding,"fraction":state.ambush_fraction,"observed_at":state.sampled_at,"received_at":_run.simulation_time}
	var ledger: WorkerLedger = _run.colony.piles.home.workers
	var released: bool = ledger.release("journey:home",state.workers); var retired: bool = ledger.retire_commitment("journey:home")
	assert(released and retired)
	state.route_id = ""; state.phase = "idle"; state.workers = 0; state.elapsed_ticks = 0; state.departed_at = 0; state.ambush_fraction = -1; state.foreign_seen = false; state.sampled_at = 0

func summary() -> Dictionary:
	var state: JourneyResponseState = _run.journey_response
	return {"away":state.active(),"route_id":state.route_id,"workers":state.workers,"age":_run.simulation_time - state.departed_at if state.active() else 0.0,"reports":state.reports.duplicate(true)}

func _reject(reason: String) -> bool: last_error = reason; return false
