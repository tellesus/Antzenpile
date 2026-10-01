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
	state.remaining_ticks -= 1
	if state.remaining_ticks > 0:
		return
	if state.direction == "outbound":
		state.cargo = minf(food.quantity, CONFIG.trail_workers * TRAILS.carry_per_worker) if food.active else 0.0
		food.quantity = maxf(0.0, food.quantity - state.cargo)
		food.active = food.quantity > 0.0
		state.direction = "inbound"
	else:
		state.stored_carbohydrate = roundf((state.stored_carbohydrate + state.cargo) * 100000.0) / 100000.0
		if state.cargo > 0.0:
			state.pheromone = snappedf(minf(1.0, state.pheromone + CONFIG.trail_workers * TRAILS.pheromone_per_returning_worker), 0.0000000001)
		state.cargo = 0.0
		state.direction = "outbound"
	state.remaining_ticks = leg


func sample_contact(cohort: TransitCohort, route: TrailRouteState) -> void:
	if cohort.worker_count <= 0 or cohort.foreign_contact or _run.rival.pheromone < 0.1 or _run.rival.contacts_total >= WorkerLedger.MAX_COUNT:
		return
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var progress: float = 1.0 - float(cohort.remaining_ticks) / TRAILS.leg_ticks(segment.start.distance_to(segment.end))
	if cohort.direction == "inbound":
		progress = 1.0 - progress
	var point: Vector2 = segment.start.lerp(segment.end, progress)
	var start: Vector2 = CONFIG.pile_position
	var finish: Vector2 = _run.world.nodes[CONFIG.food_id].position
	var span: Vector2 = finish - start
	if span.length_squared() <= 0.0:
		return
	var t: float = clampf((point - start).dot(span) / span.length_squared(), 0.0, 1.0)
	if point.distance_to(start + span * t) <= CONFIG.contact_radius:
		cohort.foreign_contact = true
		_run.rival.contacts_total += 1
