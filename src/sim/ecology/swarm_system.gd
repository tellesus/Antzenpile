class_name SwarmSystem
extends RefCounted
## One aggregate junction conflict. Participants stay in their existing ledgers.

const CONFIG = preload("res://data/ecology/default_swarm.tres")
const RIVAL = preload("res://data/ecology/backyard_rival.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
const Cohort = preload("res://src/sim/trails/transit_cohort.gd")
var _run: RunState
var _loss_command: Callable


func _init(run_state: RunState, loss_command: Callable) -> void:
	_run = run_state
	_loss_command = loss_command


func consider(cohort: TransitCohort, route: TrailRouteState) -> void:
	var state: SwarmState = _run.swarm
	# A routed foraging remnant is not a new attacking force.
	if not state.active() and _run.rival.workers.count("rival:trail") <= CONFIG.rival_retreat_count: return
	if cohort.worker_count <= 0 or not cohort.reports_source_outcome or route.desired_workers == 0 or _run.rival.workers.count("rival:trail") <= 0:
		return
	if state.active() and state.route_id != route.id:
		return
	if not state.active() and (route.foreign_reports < CONFIG.reports_to_escalate or _run.rival.pheromone < 0.1 or (state.last_finish_tick >= 0 and _run.clock.tick_count - state.last_finish_tick < CONFIG.cooldown_ticks)):
		return
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var intersection: Variant = Geometry2D.segment_intersects_segment(segment.start, segment.end, RIVAL.pile_position, _run.world.nodes[RIVAL.food_id].position)
	if intersection == null:
		return
	var leg: int = TRAILS.leg_ticks(segment.start.distance_to(segment.end))
	var t: float = 1.0 - float(cohort.remaining_ticks) / leg
	if cohort.direction == "inbound":
		t = 1.0 - t
	if segment.start.lerp(segment.end, t).distance_to(intersection) > RIVAL.contact_radius:
		return
	if not state.active():
		if state.serial >= WorkerLedger.MAX_COUNT:
			return
		state.serial += 1
		state.route_id = route.id
		state.position = intersection
		state.phase = "forming"
		state.rival_engaged = false
		state.round_ticks = 0
		state.rounds = 0; state.pressure_reports_sent = 1
		state.formation_ticks = TRAILS.leg_ticks(RIVAL.pile_position.distance_to(_run.world.nodes[RIVAL.food_id].position)) * 2 + 1
		if not _messenger(cohort, route):
			# The whole group returns when it cannot detach a courier/hold a front.
			_finish("withdrew")
			cohort.conflict_report = "withdrew"
			return
	cohort.swarm_engaged = true


func _messenger(cohort: TransitCohort, route: TrailRouteState, report: String = "contested") -> bool:
	var state: SwarmState = _run.swarm
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var count: int = 0
	for other: TransitCohort in _run.trails.cohorts.values():
		if other.route_id == route.id:
			count += 1
	if cohort.worker_count < 2 or count >= TRAILS.max_cohorts_per_route or _run.trails.next_cohort_id >= WorkerLedger.MAX_COUNT:
		# At capacity, the whole arriving group reports instead of creating a ninth batch.
		cohort.direction = "inbound"
		cohort.remaining_ticks = TRAILS.leg_ticks(segment.start.distance_to(state.position))
		cohort.reports_source_outcome = false
		cohort.conflict_report = report
		cohort.conflict_observed_at = _run.simulation_time
		cohort.conflict_serial = state.serial
		return false
	var messenger := Cohort.new()
	messenger.id = "cohort_%d" % _run.trails.next_cohort_id
	messenger.route_id = route.id
	messenger.worker_count = 1
	messenger.direction = "inbound"
	messenger.remaining_ticks = TRAILS.leg_ticks(segment.start.distance_to(state.position))
	messenger.energy_multiplier = cohort.energy_multiplier
	messenger.carry_multiplier = cohort.carry_multiplier
	messenger.chemistry_fraction = cohort.chemistry_fraction
	messenger.unpaid_energy_cost = roundf(cohort.unpaid_energy_cost / (cohort.worker_count + cohort.lost_workers) * 100000.0) / 100000.0
	cohort.unpaid_energy_cost = roundf((cohort.unpaid_energy_cost - messenger.unpaid_energy_cost) * 100000.0) / 100000.0
	messenger.payload = minf(cohort.payload, TRAILS.carry_per_worker * cohort.carry_multiplier)
	messenger.contaminant_mass = cohort.contaminant_mass * messenger.payload / cohort.payload if cohort.payload > 0.0 else 0.0
	cohort.contaminant_mass -= messenger.contaminant_mass
	cohort.payload -= messenger.payload
	messenger.resource_id = cohort.resource_id if messenger.payload > 0.0 else ""
	if cohort.payload == 0.0:
		cohort.resource_id = ""
	messenger.predator_encountered = cohort.predator_encountered
	messenger.foreign_contact = cohort.foreign_contact
	messenger.foreign_sampled = true
	cohort.foreign_contact = false
	cohort.foreign_sampled = true
	messenger.reports_source_outcome = false
	messenger.conflict_report = report
	messenger.conflict_observed_at = _run.simulation_time
	messenger.conflict_serial = state.serial
	cohort.worker_count -= 1
	_run.trails.cohorts[messenger.id] = messenger
	_run.trails.next_cohort_id += 1
	return true


func tick() -> void:
	var state: SwarmState = _run.swarm
	if not state.active():
		return
	var route: TrailRouteState = _run.trails.routes[state.route_id]
	if route.desired_workers == 0:
		_finish("withdrew")
		return
	var participants: Array[TransitCohort] = _participants()
	var player_count: int = 0
	for cohort: TransitCohort in participants:
		player_count += cohort.worker_count
	var rival_count: int = maxi(0, _run.rival.workers.count("rival:trail"))
	if _run.rival.reinforcement.phase == "engaged": rival_count += maxi(0,_run.rival.workers.count("rival:reinforcement"))
	if not state.rival_engaged:
		var food: Vector2 = _run.world.nodes[RIVAL.food_id].position
		var leg: int = TRAILS.leg_ticks(RIVAL.pile_position.distance_to(food))
		var t: float = 1.0 - float(_run.rival.remaining_ticks) / leg
		if _run.rival.direction == "inbound":
			t = 1.0 - t
		state.rival_engaged = RIVAL.pile_position.lerp(food, t).distance_to(state.position) <= RIVAL.contact_radius
	if state.phase == "forming":
		state.formation_ticks -= 1
		if state.rival_engaged and player_count > 0:
			state.phase = "fighting"
			state.round_ticks = CONFIG.round_ticks
			state.formation_ticks = 0
		elif state.formation_ticks == 0:
			_finish("dispersed")
		return
	_counter_recruit(player_count, rival_count)
	if rival_count <= CONFIG.rival_retreat_count:
		_finish("secured")
		return
	if player_count == 0 or float(player_count) / rival_count < CONFIG.retreat_ratio:
		_finish("withdrew")
		return
	state.round_ticks -= 1
	if state.round_ticks > 0:
		return
	state.rounds += 1
	if _run.rng.randf() < float(player_count) / (player_count + rival_count):
		var regulars: int = maxi(0,_run.rival.workers.count("rival:trail"))
		var commitment: String = "rival:trail" if regulars == rival_count or _run.rng.randi_range(0,rival_count-1) < regulars else "rival:reinforcement"
		var removed: bool = _run.rival.workers.remove_living_workers(commitment, 1, "Junction conflict")
		assert(removed)
		state.rival_losses += 1
		_run.rival.cargo = minf(_run.rival.cargo, maxi(0,_run.rival.workers.count("rival:trail")) * TRAILS.carry_per_worker)
	else:
		var selected: int = _run.rng.randi_range(0, player_count - 1)
		for cohort: TransitCohort in participants:
			if selected < cohort.worker_count:
				_loss_command.call(cohort, route, "rival")
				state.player_losses += 1
				break
			selected -= cohort.worker_count
	state.round_ticks = CONFIG.round_ticks
	# Finish before a zero-participant intermediate state could be saved.
	var survivors: int = 0
	for cohort: TransitCohort in _participants():
		survivors += cohort.worker_count
	var enemies: int = maxi(0,_run.rival.workers.count("rival:trail")) + (maxi(0,_run.rival.workers.count("rival:reinforcement")) if _run.rival.reinforcement.phase == "engaged" else 0)
	if enemies <= CONFIG.rival_retreat_count:
		_finish("secured")
	elif survivors == 0 or float(survivors) / maxi(1, enemies) < CONFIG.retreat_ratio:
		_finish("withdrew")
	elif state.rounds % CONFIG.pressure_every_rounds == 2 and state.pressure_reports_sent < CONFIG.max_pressure_reports:
		var report: String = "reinforced" if _run.rival.reinforcement.phase == "engaged" else "holding" if survivors >= enemies else "resisted"
		var cohorts: Array[TransitCohort] = _participants()
		var route_cohorts: int = 0
		for cohort: TransitCohort in _run.trails.cohorts.values():
			if cohort.route_id == route.id: route_cohorts += 1
		if cohorts[0].worker_count >= 2 and route_cohorts < TRAILS.max_cohorts_per_route:
			_messenger(cohorts[0],route,report)
			state.pressure_reports_sent += 1

func _counter_recruit(player_count: int, rival_count: int) -> void:
	var rival: RivalState = _run.rival
	var group: RivalReinforcementState = rival.reinforcement
	var state: SwarmState = _run.swarm
	if group.phase != "idle" or group.swarm_serial == state.serial or group.mobilizations >= CONFIG.max_rival_mobilizations or rival.workers.available < CONFIG.rival_reinforcement_workers: return
	if player_count <= rival_count and rival.workers.count("rival:trail") >= RIVAL.trail_workers - 1: return
	var length: float = RIVAL.pile_position.distance_to(state.position)
	var cost: float = TRAILS.round_trip_energy_cost(CONFIG.rival_reinforcement_workers,length,TrailSegmentState.terrain_cost_for(_run.world,RIVAL.pile_position,state.position))
	if rival.stored_carbohydrate < cost: return
	var allocated: bool = rival.workers.create_commitment("rival:reinforcement","other","rival_swarm") and rival.workers.allocate("rival:reinforcement",CONFIG.rival_reinforcement_workers)
	assert(allocated)
	rival.stored_carbohydrate = roundf((rival.stored_carbohydrate-cost)*100000.0)/100000.0
	group.phase = "outbound"; group.travel_ticks = TRAILS.leg_ticks(length); group.remaining_ticks = group.travel_ticks
	group.mobilizations += 1; group.swarm_serial = state.serial


func _participants() -> Array[TransitCohort]:
	var result: Array[TransitCohort] = []
	for cohort: TransitCohort in _run.trails.cohorts.values():
		if cohort.swarm_engaged and cohort.worker_count > 0:
			result.append(cohort)
	result.sort_custom(func(a: TransitCohort, b: TransitCohort) -> bool: return a.id.trim_prefix("cohort_").to_int() < b.id.trim_prefix("cohort_").to_int())
	return result


func _finish(outcome: String) -> void:
	var state: SwarmState = _run.swarm
	for cohort: TransitCohort in _run.trails.cohorts.values():
		if cohort.swarm_engaged:
			cohort.swarm_engaged = false
			if cohort.worker_count > 0:
				cohort.conflict_report = outcome
				cohort.conflict_observed_at = _run.simulation_time
				cohort.conflict_serial = state.serial
				if outcome == "withdrew":
					var segment: TrailSegmentState = _run.trails.segments[_run.trails.routes[cohort.route_id].segment_id]
					cohort.direction = "inbound"
					cohort.remaining_ticks = TRAILS.leg_ticks(segment.start.distance_to(state.position))
					cohort.reports_source_outcome = false
	state.phase = "finished"
	state.round_ticks = 0
	state.formation_ticks = 0
	state.rival_engaged = false
	state.last_finish_tick = _run.clock.tick_count
	var group: RivalReinforcementState = _run.rival.reinforcement
	if group.phase in ["outbound", "engaged"]:
		group.remaining_ticks = maxi(1,group.travel_ticks-group.remaining_ticks) if group.phase == "outbound" else group.travel_ticks
		group.phase = "inbound"
