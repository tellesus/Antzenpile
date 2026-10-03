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
	return _dispatch(route_id,"investigate",CONFIG.investigation_workers)

func defend(route_id: String) -> bool:
	var report: Dictionary = _run.journey_response.reports.get(route_id,{})
	if report.get("finding","") not in ["ambush","mixed"]: return _reject("A returned ambusher survey is required")
	if _run.journey_response.defense.outcomes.get(route_id,{}).get("outcome","") == "secured": return _reject("Ambusher addressed; survey again if journey losses continue")
	return _dispatch(route_id,"defend",CONFIG.defense_workers)

func _dispatch(route_id: String, mode: String, count: int) -> bool:
	var state: JourneyResponseState = _run.journey_response
	if state.active() or not _run.trails.routes.has(route_id): return _reject("Another party is away or the journey is unknown")
	var route: TrailRouteState = _run.trails.routes[route_id]
	if route.purpose != "food" or route.reported_losses <= 0: return _reject("A returned journey loss is required")
	if mode == "defend" and route.origin_pile != "home": return _reject("Defensive parties currently depart from Home")
	var pile: PileState = _run.colony.piles[route.origin_pile]
	var commitment: String = "journey:" + pile.id
	var cost: float = _cost(route_id,count)
	if pile.workers_available < count or pile.resources.carbohydrate < cost: return _reject("Needs %d available workers and travel food" % count)
	if not pile.workers.create_commitment(commitment,"other",route_id): return _reject("Party commitment unavailable")
	var allocated: bool = pile.workers.allocate(commitment,count)
	var paid: bool = pile.consume_resources({"carbohydrate":cost})
	assert(allocated and paid)
	state.route_id = route_id; state.phase = "outbound"; state.workers = count; state.departed_at = _run.simulation_time
	state.defense.mode = mode; state.defense.sent = count
	last_error = ""; return true

func _cost(route_id: String, count: int) -> float:
	var segment: TrailSegmentState = _run.trails.segments[_run.trails.routes[route_id].segment_id]
	return TRAILS.round_trip_energy_cost(count,segment.start.distance_to(segment.end),TrailSegmentState.terrain_cost_for(_run.world,segment.start,segment.end))

func reinforce(route_id: String) -> bool:
	var state: JourneyResponseState = _run.journey_response
	var defense: JourneyDefenseState = state.defense
	if not state.active() or state.route_id != route_id or defense.mode != "defend" or defense.extra_workers > 0 or defense.sent + CONFIG.reinforcement_workers > CONFIG.dispatched_cap: return _reject("No further reinforcement can be dispatched")
	var pile: PileState = _run.colony.piles.home
	var cost: float = _cost(route_id,CONFIG.reinforcement_workers)
	if pile.workers_available < CONFIG.reinforcement_workers or pile.resources.carbohydrate < cost: return _reject("Reinforcement needs four workers and travel food")
	var allocated: bool = pile.workers.allocate("journey:home",CONFIG.reinforcement_workers)
	var paid: bool = pile.consume_resources({"carbohydrate":cost})
	assert(allocated and paid)
	defense.extra_workers = CONFIG.reinforcement_workers; defense.extra_ticks = 0; defense.sent += CONFIG.reinforcement_workers
	last_error = ""; return true

func recall() -> bool:
	var state: JourneyResponseState = _run.journey_response
	if not state.active(): return _reject("No party is away")
	if state.phase in ["outbound","fighting"]:
		if state.defense.mode == "defend":
			_return("withdrew")
			if state.elapsed_ticks >= _leg(): _meet_reinforcement(); _arrive()
			last_error = ""; return true
		state.elapsed_ticks = _leg() - state.elapsed_ticks
		state.phase = "inbound"
		if state.elapsed_ticks >= _leg(): _arrive()
	last_error = ""; return true

func tick() -> void:
	var state: JourneyResponseState = _run.journey_response
	if not state.active(): return
	_meet_reinforcement()
	if state.defense.mode == "defend":
		if state.phase == "fighting": _combat(); return
		if state.phase == "outbound" and _find_ambusher(): return
	elif state.phase == "outbound": _sample()
	state.elapsed_ticks += 1
	if state.elapsed_ticks < _leg(): return
	if state.phase == "outbound":
		if state.defense.mode == "defend":
			state.elapsed_ticks = _leg(); _return("not_found")
		else: state.phase = "inbound"; state.elapsed_ticks = 0
	else: _arrive()

func _meet_reinforcement() -> void:
	var state: JourneyResponseState = _run.journey_response
	var defense: JourneyDefenseState = state.defense
	if defense.extra_workers == 0: return
	defense.extra_ticks += 1
	var cursor: int = _leg() - state.elapsed_ticks if state.phase == "inbound" else state.elapsed_ticks
	if defense.extra_ticks >= cursor:
		state.workers += defense.extra_workers; defense.extra_workers = 0; defense.extra_ticks = 0

func _find_ambusher() -> bool:
	var state: JourneyResponseState = _run.journey_response
	var segment: TrailSegmentState = _run.trails.segments[_run.trails.routes[state.route_id].segment_id]
	var point: Vector2 = segment.start.lerp(segment.end,float(state.elapsed_ticks) / _leg())
	if _run.predator.defeated_at > 0 or _run.clock.tick_count < PREDATOR.first_tick or point.distance_to(PREDATOR.position) > PREDATOR.radius: return false
	state.phase = "fighting"; state.defense.round_ticks = CONFIG.round_ticks
	return true

func _combat() -> void:
	var state: JourneyResponseState = _run.journey_response
	var defense: JourneyDefenseState = state.defense
	defense.round_ticks -= 1
	if defense.round_ticks > 0: return
	defense.rounds += 1
	if _run.rng.randf() < float(state.workers) / (state.workers + _run.predator.resistance):
		_run.predator.resistance -= 1
	else:
		var pile: PileState = _run.colony.piles.home
		var adapted: int = 1 if _run.rng.randf() < pile.adaptation_fraction() else 0
		var profile: String = pile.genetics.loss_profile(adapted == 1,pile.adaptation_repertoire,pile.workers_total,_run.rng)
		var removed: bool = pile.lose_workers("journey:home",1,adapted,"defensive ambusher swarm",profile)
		assert(removed)
		state.workers -= 1; defense.lost += 1; defense.adapted_lost += adapted; _run.predator.defense_losses += 1
		if profile != "": defense.lost_profiles[profile] = defense.lost_profiles.get(profile,0) + 1
	if _run.predator.resistance == 0:
		_run.predator.defeated_at = _run.simulation_time; _return("secured")
	elif state.workers <= CONFIG.retreat_workers or defense.rounds >= CONFIG.max_rounds: _return("withdrew")
	else: defense.round_ticks = CONFIG.round_ticks

func _return(outcome: String) -> void:
	var state: JourneyResponseState = _run.journey_response
	state.defense.outcome = outcome; state.defense.observed_at = _run.simulation_time; state.defense.round_ticks = 0
	state.elapsed_ticks = _leg() - state.elapsed_ticks; state.phase = "inbound"

func _leg() -> int:
	var segment: TrailSegmentState = _run.trails.segments[_run.trails.routes[_run.journey_response.route_id].segment_id]
	return TRAILS.leg_ticks(segment.start.distance_to(segment.end))

func _sample() -> void:
	var state: JourneyResponseState = _run.journey_response
	var segment: TrailSegmentState = _run.trails.segments[_run.trails.routes[state.route_id].segment_id]
	var fraction: float = float(state.elapsed_ticks) / _leg()
	var point: Vector2 = segment.start.lerp(segment.end,fraction)
	# Cautious survey senses nearby danger without using its position as a navigation target.
	if state.ambush_fraction < 0 and _run.predator.defeated_at == 0 and _run.clock.tick_count >= PREDATOR.first_tick and point.distance_to(PREDATOR.position) <= PREDATOR.radius + CONFIG.survey_radius:
		state.ambush_fraction = snappedf(fraction,0.05); state.sampled_at = _run.simulation_time
	if not state.foreign_seen and _run.rival.contacts_total < WorkerLedger.MAX_COUNT and _run.rival.pheromone >= 0.1 and _run.world.nodes.has(RIVAL.food_id):
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point,RIVAL.pile_position,_run.world.nodes[RIVAL.food_id].position)
		if point.distance_to(nearest) <= RIVAL.contact_radius:
			state.foreign_seen = true; state.sampled_at = _run.simulation_time
			_run.rival.contacts_total += 1

func _arrive() -> void:
	var state: JourneyResponseState = _run.journey_response
	var finding: String = "mixed" if state.ambush_fraction >= 0 and state.foreign_seen else "ambush" if state.ambush_fraction >= 0 else "foreign" if state.foreign_seen else "inconclusive"
	if state.defense.mode == "defend":
		state.defense.outcomes[state.route_id] = {"outcome":state.defense.outcome,"lost":state.defense.lost,"sent":state.defense.sent,"observed_at":state.defense.observed_at,"received_at":_run.simulation_time}
		state.defense.reported_losses += state.defense.lost
	else:
		state.reports[state.route_id] = {"finding":finding,"fraction":state.ambush_fraction,"observed_at":state.sampled_at,"received_at":_run.simulation_time}
		if state.foreign_seen:
			var route: TrailRouteState = _run.trails.routes[state.route_id]
			route.foreign_reports += 1; route.last_foreign_time = _run.simulation_time
	var origin: String = _run.trails.routes[state.route_id].origin_pile
	var ledger: WorkerLedger = _run.colony.piles[origin].workers
	var commitment: String = "journey:" + origin
	var released: bool = ledger.release(commitment,state.workers); var retired: bool = ledger.retire_commitment(commitment)
	assert(released and retired)
	state.route_id = ""; state.phase = "idle"; state.workers = 0; state.elapsed_ticks = 0; state.departed_at = 0; state.ambush_fraction = -1; state.foreign_seen = false; state.sampled_at = 0
	state.defense.reset_party()

func summary(origin_id: String = "home") -> Dictionary:
	var state: JourneyResponseState = _run.journey_response
	var own_party: bool = state.active() and _run.trails.routes[state.route_id].origin_pile == origin_id
	var reports: Dictionary = {}; var outcomes: Dictionary = {}
	for id: String in state.reports:
		if _run.trails.routes[id].origin_pile == origin_id: reports[id] = state.reports[id].duplicate(true)
	for id: String in state.defense.outcomes:
		if _run.trails.routes[id].origin_pile == origin_id: outcomes[id] = state.defense.outcomes[id].duplicate(true)
	var other: String = _run.trails.routes[state.route_id].origin_pile if state.active() and not own_party else ""
	return {"away":own_party,"route_id":state.route_id if own_party else "","mode":state.defense.mode if own_party else "investigate",
		"workers":state.workers + state.defense.extra_workers + state.defense.lost if own_party else 0,
		"age":_run.simulation_time - state.departed_at if own_party else 0.0,"reports":reports,"outcomes":outcomes,
		"reported_losses":state.defense.reported_losses if origin_id == "home" else 0,
		"other_party":"Home" if other == "home" else "Daughter" if other != "" else "",
		"reinforcement_available":own_party and state.defense.mode == "defend" and state.defense.sent + CONFIG.reinforcement_workers <= CONFIG.dispatched_cap}

func _reject(reason: String) -> bool: last_error = reason; return false
