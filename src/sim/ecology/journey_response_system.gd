class_name JourneyResponseSystem
extends RefCounted
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
const PREDATOR = preload("res://data/ecology/backyard_predator.tres")
const RIVAL = preload("res://data/ecology/backyard_rival.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
const PATHFINDER = preload("res://src/sim/scouting/scout_pathfinder.gd")
var _run: RunState
var last_error: String = ""
func _init(run_state: RunState): _run = run_state

func investigate(route_id: String) -> bool:
	return _dispatch(route_id,"investigate",CONFIG.investigation_workers)

func investigate_approach(route_id: String) -> bool:
	if not _run.trails.routes.has(route_id): return _reject("Unknown journey")
	var route: TrailRouteState = _run.trails.routes[route_id]
	if route.allocated_workers > 0 or route.desired_workers > 0 or _run.journey_response.active() or _run.swarm.active() and _run.swarm.route_id == route_id: return _reject("Recall gatherers and wait for their return first")
	if _run.journey_response.orders.targets.get(route_id,0) > 0: return _reject("Cancel the waiting force order first")
	var base: TrailSegmentState = _run.trails.segments[route.segment_id]
	var candidate := TrailSegmentState.new()
	candidate.id = base.id; candidate.route_id = base.route_id; candidate.start = base.start; candidate.end = base.end
	var perpendicular: Vector2 = (base.end - base.start).normalized().orthogonal() * CONFIG.bypass_offset
	var first_side: int = -1 if not base.waypoints.is_empty() and (base.waypoints[0]-base.start.lerp(base.end,0.3)).dot(perpendicular) > 0 else 1
	for side: int in [first_side,-first_side]:
		candidate.waypoints = [base.start.lerp(base.end,0.3) + perpendicular * side, base.start.lerp(base.end,0.7) + perpendicular * side]
		if _run.world.bounds.has_point(candidate.waypoints[0]) and _run.world.bounds.has_point(candidate.waypoints[1]): break
	for index: int in candidate.waypoints.size():
		candidate.waypoints[index] = candidate.waypoints[index].clamp(_run.world.bounds.position + Vector2.ONE * 0.01, _run.world.bounds.end - Vector2.ONE * 0.01)
	# Outside/blocked ground is learned by the paid survey, never pre-reported by UI.
	var cost: float = maxf(_cost(route_id,CONFIG.investigation_workers), TRAILS.round_trip_energy_cost(CONFIG.investigation_workers,candidate.length(),candidate.terrain_cost(_run.world)))
	var pile: PileState = _run.colony.piles[route.origin_pile]
	if pile.resources.carbohydrate < cost: return _reject("Needs three workers and longer-approach travel food")
	if not _dispatch(route_id,"investigate",CONFIG.investigation_workers): return false
	var old_cost: float = _cost(route_id,CONFIG.investigation_workers)
	if cost > old_cost: assert(pile.consume_resources({"carbohydrate":cost-old_cost}))
	_run.journey_response.approach.candidate = candidate
	return true

func defend(route_id: String, count: int = CONFIG.defense_workers) -> bool:
	if not JourneyOrders.valid_target(count) or count == 0: return _reject("Choose 12–24 workers in groups of four")
	var report: Dictionary = _run.journey_response.reports.get(route_id,{})
	if _surface_warning(route_id): return _reject("Surface impacts cannot be fought; withdraw or test another approach")
	if report.get("finding","") not in ["ambush","mixed"]: return _reject("A returned ambusher survey is required")
	if _run.journey_response.defense.outcomes.get(route_id,{}).get("outcome","") == "secured": return _reject("Ambusher addressed; survey again if journey losses continue")
	return _dispatch(route_id,"defend",count)

func set_force(route_id: String, target: int) -> bool:
	if not _run.trails.routes.has(route_id) or not JourneyOrders.valid_target(target): return _reject("Unknown journey or invalid force budget")
	var state: JourneyResponseState = _run.journey_response
	if target > 0:
		if _surface_warning(route_id): return _reject("Surface impacts cannot be fought; withdraw or test another approach")
		if state.active() and state.route_id == route_id and state.defense.mode != "defend": return _reject("Survey away; wait for its return or recall it")
		if state.reports.get(route_id, {}).get("finding", "") not in ["ambush", "mixed"]: return _reject("Return a predator survey first")
		if state.defense.outcomes.get(route_id, {}).get("outcome", "") == "secured": return _reject("This predator was already addressed")
	state.orders.targets[route_id] = target
	if target == 0 and state.active() and state.route_id == route_id: recall()
	else: _fund_orders()
	last_error = ""
	return true

func set_goal(route_id: String, goal: String) -> bool:
	var state: JourneyResponseState = _run.journey_response
	if _surface_warning(route_id): return _reject("A surface impact leaves nothing to fight or harvest")
	if goal not in ["clear", "hunt"] or not _run.trails.routes.has(route_id) or state.reports.get(route_id, {}).get("finding", "") not in ["ambush", "mixed"]: return _reject("A returned predator survey is required")
	if state.active() and state.route_id == route_id: return _reject("Goal locked for the dispatched party; recall before changing it")
	state.orders.goals[route_id] = goal; last_error = ""; return true

func _fund_orders() -> void:
	var state: JourneyResponseState = _run.journey_response
	if state.active():
		var target: int = state.orders.targets.get(state.route_id, 0)
		if state.defense.mode == "defend" and target > state.defense.sent and not _reinforcement_pending(): reinforce(state.route_id)
		return
	var ids: Array = state.orders.targets.keys(); ids.sort()
	for id: String in ids:
		if state.orders.targets[id] > 0 and defend(id, state.orders.targets[id]): return

func _dispatch(route_id: String, mode: String, count: int) -> bool:
	var state: JourneyResponseState = _run.journey_response
	if state.active() or not _run.trails.routes.has(route_id): return _reject("Another party is away or the journey is unknown")
	var route: TrailRouteState = _run.trails.routes[route_id]
	if route.purpose != "food" or route.reported_losses <= 0: return _reject("A returned journey loss is required")
	var pile: PileState = _run.colony.piles[route.origin_pile]
	var commitment: String = "journey:" + pile.id
	var cost: float = _cost(route_id,count)
	if pile.workers_assignable < count or pile.resources.carbohydrate < cost: return _reject("Needs %d available workers and travel food" % count)
	if not pile.workers.create_commitment(commitment,"other",route_id): return _reject("Party commitment unavailable")
	var allocated: bool = pile.allocate_workers(commitment,count)
	var paid: bool = pile.consume_resources({"carbohydrate":cost})
	assert(allocated and paid)
	state.route_id = route_id; state.phase = "outbound"; state.workers = count; state.departed_at = _run.simulation_time
	state.defense.mode = mode; state.defense.sent = count; state.defense.initial_sent = count
	state.defense.goal = state.orders.goals.get(route_id, "clear") if mode == "defend" else "clear"
	last_error = ""; return true

func _cost(route_id: String, count: int) -> float:
	var segment: TrailSegmentState = _run.trails.segments[_run.trails.routes[route_id].segment_id]
	return TRAILS.round_trip_energy_cost(count,segment.length(),segment.terrain_cost(_run.world))

func reinforce(route_id: String) -> bool:
	var state: JourneyResponseState = _run.journey_response
	var defense: JourneyDefenseState = state.defense
	if not state.active() or state.route_id != route_id or defense.mode != "defend" or defense.extra_workers > 0 or defense.sent + CONFIG.reinforcement_workers > CONFIG.dispatched_cap: return _reject("No further reinforcement can be dispatched")
	if _reinforcement_pending(): return _reject("Reinforcements already sent; await a returning messenger")
	var pile: PileState = _run.colony.piles[state.origin_id(_run.trails)]
	var cost: float = _cost(route_id,CONFIG.reinforcement_workers)
	if pile.workers_assignable < CONFIG.reinforcement_workers or pile.resources.carbohydrate < cost: return _reject("Reinforcement needs four workers and travel food")
	var allocated: bool = pile.allocate_workers("journey:"+pile.id,CONFIG.reinforcement_workers)
	var paid: bool = pile.consume_resources({"carbohydrate":cost})
	assert(allocated and paid)
	defense.extra_workers = CONFIG.reinforcement_workers; defense.extra_ticks = 0; defense.sent += CONFIG.reinforcement_workers
	last_error = ""; return true

func recall() -> bool:
	var state: JourneyResponseState = _run.journey_response
	if not state.active(): return _reject("No party is away")
	state.orders.targets[state.route_id] = 0
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
	_fund_orders()
	var state: JourneyResponseState = _run.journey_response
	if not state.active(): return
	_tick_messenger()
	_meet_reinforcement()
	if state.defense.mode == "defend":
		if state.phase == "fighting": _combat(); return
		if state.phase == "outbound" and _find_ambusher(): return
	elif state.phase == "outbound":
		if state.approach.candidate != null:
			var point: Vector2 = _segment().point_at(float(state.elapsed_ticks) / _leg())
			if not _run.world.bounds.has_point(point) or not is_finite(PATHFINDER.travel_cost(_run.world,point)):
				state.approach.blocked = true; recall(); return
		_sample()
	state.elapsed_ticks += 1
	if state.elapsed_ticks < _leg(): return
	if state.phase == "outbound":
		if state.defense.mode == "defend":
			state.elapsed_ticks = _leg(); _return("not_found")
		else:
			if state.approach.candidate != null: state.approach.reached = true
			state.phase = "inbound"; state.elapsed_ticks = 0
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
	var point: Vector2 = segment.point_at(float(state.elapsed_ticks) / _leg())
	if _run.predator.defeated_at > 0 or _run.clock.tick_count < PREDATOR.first_tick or point.distance_to(PREDATOR.position) > PREDATOR.radius: return false
	state.phase = "fighting"; state.defense.round_ticks = CONFIG.round_ticks
	return true

func _combat() -> void:
	var state: JourneyResponseState = _run.journey_response
	var defense: JourneyDefenseState = state.defense
	defense.round_ticks -= 1
	if defense.round_ticks > 0: return
	defense.rounds += 1
	var front: int = state.workers - state.pressure.messengers
	var resistance: int = maxi(_run.predator.resistance, CONFIG.hunt_resistance if defense.goal == "hunt" else 0)
	if _run.rng.randf() < float(front) / (front + resistance):
		if _run.predator.resistance > 0: _run.predator.resistance -= 1
		elif defense.goal == "hunt": _run.predator.health -= 1
	else:
		var pile: PileState = _run.colony.piles[state.origin_id(_run.trails)]
		var adapted: int = 1 if _run.rng.randf() < pile.adaptation_fraction() else 0
		var profile: String = pile.genetics.loss_profile(adapted == 1,pile.adaptation_repertoire,pile.workers_total,_run.rng)
		var removed: bool = pile.lose_workers("journey:"+pile.id,1,adapted,"defensive ambusher swarm",profile)
		assert(removed)
		state.workers -= 1; defense.lost += 1; defense.adapted_lost += adapted; _run.predator.defense_losses += 1
		if profile != "": defense.lost_profiles[profile] = defense.lost_profiles.get(profile,0) + 1
	if _run.predator.resistance == 0 and (defense.goal == "clear" or _run.predator.health == 0):
		if defense.goal == "hunt":
			_run.predator.killed = true
			PredatorCarcass.create(_run)
		_run.predator.defeated_at = _run.simulation_time; _return("secured")
	elif state.workers - state.pressure.messengers <= CONFIG.retreat_workers or defense.rounds >= CONFIG.max_rounds: _return("withdrew")
	else:
		defense.round_ticks = CONFIG.round_ticks
		if defense.rounds % CONFIG.pressure_every_rounds == 1: _send_messenger()

func _send_messenger() -> void:
	var state: JourneyResponseState = _run.journey_response
	var pressure: JourneyPressureState = state.pressure
	if pressure.remaining_ticks > 0 or pressure.messengers >= CONFIG.max_messengers or state.workers - pressure.messengers <= CONFIG.retreat_workers + 1: return
	pressure.messengers += 1
	pressure.remaining_ticks = maxi(1, state.elapsed_ticks)
	pressure.travel_ticks = pressure.remaining_ticks
	var front: int = state.workers - pressure.messengers
	pressure.pending = {"pressure": "resisted" if state.defense.lost >= 2 or front < _run.predator.resistance * 2 else "holding", "observed_at": _run.simulation_time, "acknowledged_sent": state.defense.sent - state.defense.extra_workers}

func _tick_messenger() -> void:
	var state: JourneyResponseState = _run.journey_response
	if state.pressure.remaining_ticks == 0: return
	state.pressure.remaining_ticks -= 1
	if state.pressure.remaining_ticks > 0: return
	var report: Dictionary = state.pressure.pending.duplicate(true)
	report.received_at = _run.simulation_time
	state.pressure.reports[state.route_id] = report
	state.pressure.pending.clear()
	state.pressure.travel_ticks = 0

func _reinforcement_pending() -> bool:
	var state: JourneyResponseState = _run.journey_response
	var reported: Dictionary = state.pressure.reports.get(state.route_id, {})
	var acknowledged: int = int(reported.acknowledged_sent) if reported.get("observed_at", 0.0) >= state.departed_at else state.defense.initial_sent
	return state.defense.sent > acknowledged

func _return(outcome: String) -> void:
	var state: JourneyResponseState = _run.journey_response
	state.defense.outcome = outcome; state.defense.observed_at = _run.simulation_time; state.defense.round_ticks = 0
	state.elapsed_ticks = _leg() - state.elapsed_ticks; state.phase = "inbound"

func _leg() -> int:
	var segment: TrailSegmentState = _segment()
	return TRAILS.leg_ticks(segment.length())

func _segment() -> TrailSegmentState:
	var state: JourneyResponseState = _run.journey_response
	return state.approach.candidate if state.approach.candidate != null else _run.trails.segments[_run.trails.routes[state.route_id].segment_id]

func _sample() -> void:
	var state: JourneyResponseState = _run.journey_response
	var segment: TrailSegmentState = _segment()
	var fraction: float = float(state.elapsed_ticks) / _leg()
	var point: Vector2 = segment.point_at(fraction)
	if state.impact_fraction < 0 and _run.surface_impact.disturbed(point):
		state.impact_fraction = snappedf(fraction, 0.05); state.sampled_at = _run.simulation_time
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
	state.orders.targets[state.route_id] = 0
	var finding: String = "surface" if state.impact_fraction >= 0 else "mixed" if state.ambush_fraction >= 0 and state.foreign_seen else "ambush" if state.ambush_fraction >= 0 else "foreign" if state.foreign_seen else "inconclusive"
	if state.defense.mode == "defend":
		state.defense.outcomes[state.route_id] = {"outcome":state.defense.outcome,"lost":state.defense.lost,"sent":state.defense.sent,"observed_at":state.defense.observed_at,"received_at":_run.simulation_time}
		if state.defense.goal == "hunt":
			state.defense.outcomes[state.route_id].goal = "hunt"
			if state.defense.outcome == "secured": PredatorCarcass.report(_run, state.origin_id(_run.trails), state.defense.observed_at)
		state.defense.reported_losses += state.defense.lost
		var owner: String = state.origin_id(_run.trails)
		if state.defense.lost > 0: state.defense.reported_by_pile[owner] = state.defense.reported_for_pile(owner) + state.defense.lost
	elif state.approach.candidate != null:
		var found: bool = state.approach.reached and not state.approach.blocked and finding == "inconclusive"
		state.approach.reports[state.route_id] = {"outcome":"found" if found else "danger" if finding != "inconclusive" else "unconfirmed","received_at":_run.simulation_time,"length":roundf(state.approach.candidate.length()*100)/100}
		if found:
			state.approach.established_at[state.route_id] = _run.simulation_time
			var candidate: TrailSegmentState = state.approach.candidate
			candidate.exposure = snappedf(candidate.path_exposure(_run.world),0.0000000001)
			_run.trails.segments[candidate.id] = candidate
	else:
		state.reports[state.route_id] = {"finding":finding,"fraction":state.impact_fraction if finding == "surface" else state.ambush_fraction,"observed_at":state.sampled_at,"received_at":_run.simulation_time}
		if finding == "surface" or state.ambush_fraction >= 0 and not _segment().waypoints.is_empty():
			var estimate: Vector2 = _segment().point_at(state.impact_fraction if finding == "surface" else state.ambush_fraction)
			if finding == "surface": estimate = estimate.round()
			state.reports[state.route_id].estimated_position = [estimate.x,estimate.y]
		if state.foreign_seen:
			var route: TrailRouteState = _run.trails.routes[state.route_id]
			route.foreign_reports += 1; route.last_foreign_time = _run.simulation_time
	var origin: String = _run.trails.routes[state.route_id].origin_pile
	var ledger: WorkerLedger = _run.colony.piles[origin].workers
	var commitment: String = "journey:" + origin
	var released: bool = ledger.release(commitment,state.workers); var retired: bool = ledger.retire_commitment(commitment)
	assert(released and retired)
	state.route_id = ""; state.phase = "idle"; state.workers = 0; state.elapsed_ticks = 0; state.departed_at = 0; state.impact_fraction = -1; state.ambush_fraction = -1; state.foreign_seen = false; state.sampled_at = 0
	state.defense.reset_party()
	state.pressure.reset_party()
	state.approach.reset_party()

func summary(origin_id: String = "home") -> Dictionary:
	var state: JourneyResponseState = _run.journey_response
	var own_party: bool = state.active() and _run.trails.routes[state.route_id].origin_pile == origin_id
	var reports: Dictionary = {}; var outcomes: Dictionary = {}; var pressure_reports: Dictionary = {}; var orders: Dictionary = {}; var goals: Dictionary = {}; var approaches: Dictionary = {}
	for id: String in state.approach.reports:
		if _run.trails.routes[id].origin_pile == origin_id: approaches[id] = state.approach.reports[id].duplicate(true)
	for id: String in state.orders.goals:
		if _run.trails.routes[id].origin_pile == origin_id: goals[id] = state.orders.goals[id]
	for id: String in state.orders.targets:
		if _run.trails.routes[id].origin_pile == origin_id: orders[id] = state.orders.targets[id]
	for id: String in state.reports:
		if _run.trails.routes[id].origin_pile == origin_id: reports[id] = state.reports[id].duplicate(true)
	for id: String in state.defense.outcomes:
		if _run.trails.routes[id].origin_pile == origin_id: outcomes[id] = state.defense.outcomes[id].duplicate(true)
	for id: String in state.pressure.reports:
		if _run.trails.routes[id].origin_pile == origin_id: pressure_reports[id] = state.pressure.reports[id].duplicate(true)
	var other: String = _run.trails.routes[state.route_id].origin_pile if state.active() and not own_party else ""
	return {"away":own_party,"route_id":state.route_id if own_party else "","mode":state.defense.mode if own_party else "investigate",
		"workers":state.workers + state.defense.extra_workers + state.defense.lost if own_party else 0,
		"age":_run.simulation_time - state.departed_at if own_party else 0.0,"reports":reports,"outcomes":outcomes,"force_orders":orders,"goals":goals,"goal":state.defense.goal if own_party else "",
		"reported_losses":state.defense.reported_for_pile(origin_id),"approach_reports":approaches,"testing_approach":own_party and state.approach.candidate != null,
		"other_party":"Home" if other == "home" else "Daughter" if other != "" else "",
		"pressure_reports": pressure_reports, "reinforcement_pending": own_party and state.defense.mode == "defend" and _reinforcement_pending(),
		"reinforcement_available":own_party and state.defense.mode == "defend" and not _reinforcement_pending() and state.defense.sent + CONFIG.reinforcement_workers <= CONFIG.dispatched_cap}

func _surface_warning(route_id: String) -> bool:
	if not _run.trails.routes.has(route_id): return false
	var route: TrailRouteState = _run.trails.routes[route_id]
	var report: Dictionary = _run.journey_response.reports.get(route_id, {})
	return report.get("finding", "") == "surface" or route.impact_report.get("received_at", 0.0) >= report.get("received_at", 0.0) and not route.impact_report.is_empty()

func _reject(reason: String) -> bool: last_error = reason; return false
