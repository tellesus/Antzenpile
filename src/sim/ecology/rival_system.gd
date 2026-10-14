class_name RivalSystem
extends RefCounted

const CONFIG = preload("res://data/ecology/backyard_rival.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state


func tick(delta: float) -> void:
	var state: RivalState = _run.rival
	if not _run.world.nodes.has(CONFIG.food_id) or _run.clock.tick_count < CONFIG.first_tick:
		return
	var food: WorldNodeState = _run.world.nodes[CONFIG.food_id]
	var leg: int = TRAILS.leg_ticks(CONFIG.pile_position.distance_to(food.position))
	if state.direction == "dormant":
		food.quantity = CONFIG.food_capacity
		food.active = true
	if (_run.clock.tick_count - CONFIG.first_tick) % CONFIG.renewal_ticks == 0:
		food.quantity = minf(CONFIG.food_capacity, food.quantity + CONFIG.renewal_amount)
		food.active = food.quantity > 0.0
	if state.direction == "dormant":
		var committed: bool = state.workers.create_commitment("rival:trail", "trail", "rival_route_1") and state.workers.allocate("rival:trail", CONFIG.trail_workers)
		assert(committed)
		state.direction = "outbound"
		state.remaining_ticks = leg
		return
	state.pheromone = snappedf(state.pheromone * pow(0.5, delta / TRAILS.pheromone_half_life_seconds), 0.0000000001)
	_tick_reinforcement()
	_tick_replacement()
	if state.direction=="resting":
		if state.workers.available>SwarmSystem.CONFIG.rival_retreat_count and _run.clock.tick_count>=state.continuity.rest_until_tick:
			assert(state.workers.create_commitment("rival:trail","trail","rival_route_1"))
			assert(state.workers.allocate("rival:trail",mini(CONFIG.trail_workers,state.workers.available)))
			state.direction="outbound";state.remaining_ticks=leg;state.continuity.rest_until_tick=0
		return
	if _run.swarm.active() and _run.swarm.rival_engaged:
		return
	state.remaining_ticks -= 1
	if state.remaining_ticks > 0:
		return
	if state.direction == "outbound":
		state.cargo = minf(food.quantity, maxi(0, state.workers.count("rival:trail")) * TRAILS.carry_per_worker) if food.active else 0.0
		food.quantity = maxf(0.0, food.quantity - state.cargo)
		food.active = food.quantity > 0.0
		state.direction = "inbound"
	else:
		state.stored_carbohydrate = roundf((state.stored_carbohydrate + state.cargo) * 100000.0) / 100000.0
		if state.cargo > 0.0:
			state.pheromone = snappedf(minf(1.0, state.pheromone + maxi(0, state.workers.count("rival:trail")) * TRAILS.pheromone_per_returning_worker), 0.0000000001)
		state.cargo = 0.0
		state.direction = "outbound"
		if state.continuity.enabled:
			# Only an actual home arrival may add living reserves to the party.
			if state.workers.count("rival:trail")<=SwarmSystem.CONFIG.rival_retreat_count:
				assert(state.workers.release("rival:trail",state.workers.count("rival:trail")))
				assert(state.workers.retire_commitment("rival:trail"))
				state.direction="resting";state.remaining_ticks=0;state.continuity.rest_until_tick=_run.clock.tick_count+CONFIG.retreat_ticks;return
			var refill: int=mini(CONFIG.trail_workers-state.workers.count("rival:trail"),state.workers.available)
			if refill>0: assert(state.workers.allocate("rival:trail",refill))
	state.remaining_ticks = leg

func _tick_replacement() -> void:
	var state: RivalState=_run.rival
	var group: RivalContinuityState=state.continuity
	if not group.enabled: return
	if group.brood_count>0:
		group.remaining_ticks-=1
		if group.remaining_ticks>0: return
		assert(state.workers.add_living_workers("available",group.brood_count,"Rival paid brood emergence"))
		group.emerged_total+=group.brood_count
		assert(state.workers.release("rival:brood",CONFIG.replacement_carers))
		assert(state.workers.retire_commitment("rival:brood"))
		group.brood_count=0;group.funded_tick=0
		return
	var count: int=mini(CONFIG.replacement_group,CONFIG.population-state.workers.total)
	if count<1 or state.workers.available<CONFIG.replacement_carers or state.stored_carbohydrate<count*CONFIG.replacement_cost or group.emerged_total>WorkerLedger.MAX_COUNT-CONFIG.population-count: return
	assert(state.workers.create_commitment("rival:brood","internal","rival_brood"))
	assert(state.workers.allocate("rival:brood",CONFIG.replacement_carers))
	state.stored_carbohydrate=roundf((state.stored_carbohydrate-count*CONFIG.replacement_cost)*100000.0)/100000.0
	group.replacement_spent+=count*CONFIG.replacement_cost
	group.brood_count=count;group.remaining_ticks=CONFIG.replacement_ticks;group.funded_tick=_run.clock.tick_count

func _tick_reinforcement() -> void:
	var rival: RivalState = _run.rival
	var group: RivalReinforcementState = rival.reinforcement
	if group.phase in ["idle", "engaged"]: return
	group.remaining_ticks -= 1
	if group.remaining_ticks > 0: return
	if group.phase == "outbound" and _run.swarm.active() and group.swarm_serial == _run.swarm.serial:
		group.phase = "engaged"
		return
	var released: bool = rival.workers.release("rival:reinforcement",rival.workers.count("rival:reinforcement"))
	var retired: bool = rival.workers.retire_commitment("rival:reinforcement")
	assert(released and retired)
	group.phase = "idle"; group.remaining_ticks = 0; group.travel_ticks = 0


func sample_contact(cohort: TransitCohort, route: TrailRouteState) -> void:
	if cohort.worker_count <= 0 or cohort.foreign_sampled or _run.rival.pheromone < 0.1 or _run.rival.contacts_total >= WorkerLedger.MAX_COUNT:
		return
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var progress: float = 1.0 - float(cohort.remaining_ticks) / TRAILS.leg_ticks(segment.length())
	if cohort.direction == "inbound":
		progress = 1.0 - progress
	var point: Vector2 = segment.point_at( progress)
	var start: Vector2 = CONFIG.pile_position
	var finish: Vector2 = _run.world.nodes[CONFIG.food_id].position
	var span: Vector2 = finish - start
	if span.length_squared() <= 0.0:
		return
	var t: float = clampf((point - start).dot(span) / span.length_squared(), 0.0, 1.0)
	if point.distance_to(start + span * t) <= CONFIG.contact_radius:
		cohort.foreign_contact = true
		cohort.foreign_sampled = true
		_run.rival.contacts_total += 1
