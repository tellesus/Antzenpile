extends RefCounted

const Agent = preload("res://src/sim/scouting/scout_agent.gd")
const Pathfinder = preload("res://src/sim/scouting/scout_pathfinder.gd")
const Senses = preload("res://src/sim/scouting/scout_senses.gd")
const Evidence = preload("res://src/sim/scouting/observation.gd")
var config: ScoutConfig = preload("res://data/scouting/default_scouts.tres")
var last_error: String = ""
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state


func dispatch(origin_id: String, bearing: Variant = null) -> bool:
	last_error = ""
	if not _run.colony.piles.has(origin_id) or _run.scouts.size() >= config.active_cap:
		return _reject("Unknown origin or scout cap reached")
	if bearing != null and (not typeof(bearing) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(bearing))):
		return _reject("Bearing must be finite or null")
	var origin: PileState = _run.colony.piles[origin_id]
	if origin.workers_available < 1:
		return _reject("No available worker")
	var id: String = "scout_%d" % _run.next_scout_id
	if origin.workers.count(id) >= 0 or _run.next_scout_id >= WorkerLedger.MAX_COUNT:
		return _reject("Scout ID unavailable")
	var saved_rng: int = _run.rng.state
	var finder := Pathfinder.new(_run.world)
	var route: Array[Vector2] = []
	for attempt: int in config.target_attempts:
		var angle: float = _run.rng.randf_range(-PI, PI) if bearing == null else float(bearing) + _run.rng.randf_range(-config.cone_radians, config.cone_radians)
		var distance: float = _run.rng.randf_range(config.minimum_distance, config.maximum_distance)
		var target: Vector2 = (origin.position + Vector2.from_angle(angle) * distance).round()
		route = finder.path(origin.position, target)
		if route.size() > 1:
			break
	if route.size() < 2:
		_run.rng.state = saved_rng
		return _reject("No reachable scout target")
	var agent := Agent.new()
	agent.id = id
	agent.origin_pile = origin_id
	agent.position = origin.position
	agent.path = route
	agent.mission_target = route.back()
	agent.return_path.append(origin.position)
	var created: bool = origin.workers.create_commitment(id, "scout", id)
	assert(created)
	var allocated: bool = origin.workers.allocate(id, 1)
	assert(allocated)
	_run.scouts[id] = agent
	_run.next_scout_id += 1
	return true


func tick(delta: float) -> void:
	var ids: Array = _run.scouts.keys()
	ids.sort()
	for id: String in ids:
		var agent: ScoutAgent = _run.scouts[id]
		if agent.phase == "departing":
			agent.phase = "exploring"
			continue
		var exploring: bool = agent.phase in ["exploring", "blocked_exploring"]
		if exploring and agent.elapsed >= config.exploration_seconds:
			agent.path = agent.return_path.duplicate()
			agent.path.reverse()
			agent.cursor = 0
			agent.phase = "returning"
			agent.investigating = ""
			exploring = false
		agent.phase = "exploring" if exploring else "returning"
		var cue: String = Senses.sample(agent, _run.world, config, _run.rng, _run.simulation_time)
		if exploring:
			_investigate(agent, cue)
		_move(agent, delta, exploring)
		Senses.sample(agent, _run.world, config, _run.rng, _run.simulation_time)
		if exploring:
			agent.elapsed += delta
		elif agent.cursor >= agent.path.size():
			var home: PileState = _run.colony.piles[agent.origin_pile]
			assert(agent.position == home.position)
			for observation: Observation in agent.observations.values():
				assert(not _run.delivered_observations.has(observation.id))
				var delivered := Evidence.new()
				var valid: bool = delivered.restore(observation.to_dict(), _run.world, _run.colony, _run.simulation_time)
				assert(valid)
				_run.delivered_observations[delivered.id] = delivered
			var released: bool = home.workers.release(id, 1)
			assert(released)
			var retired: bool = home.workers.retire_commitment(id)
			assert(retired)
			_run.scouts.erase(id)


func _investigate(agent: ScoutAgent, cue: String) -> void:
	# Replan only at an actually reached waypoint; breadcrumbs stay physical.
	if agent.position.distance_to(agent.return_path.back()) > 0.0001:
		return
	var target: Vector2 = agent.mission_target
	if not cue.is_empty():
		target = agent.observations[cue].estimated_position.round()
		if target == agent.position:
			# A broad estimate may round to our cell: probe one cardinal neighbor.
			var direction: Vector2 = agent.observations[cue].estimated_position - agent.position
			var step := Vector2(signf(direction.x), 0) if absf(direction.x) >= absf(direction.y) else Vector2(0, signf(direction.y))
			target += step
	agent.investigating = cue
	if target == agent.path.back():
		return
	var route: Array[Vector2] = Pathfinder.new(_run.world).path(agent.position, target)
	if route.is_empty():
		return
	agent.path = route
	agent.cursor = 1


func _move(agent: ScoutAgent, delta: float, exploring: bool) -> void:
	var budget: float = delta
	while agent.cursor < agent.path.size() and budget > 0:
		var target: Vector2 = agent.path[agent.cursor]
		var distance: float = agent.position.distance_to(target)
		if distance < 0.000001:
			agent.position = target
			agent.cursor += 1
			if exploring and agent.return_path.back() != target:
				agent.return_path.append(target)
			continue
		var cost: float = maxf(Pathfinder.travel_cost(_run.world, target), Pathfinder.travel_cost(_run.world, agent.position))
		if not is_finite(cost):
			agent.phase = "blocked_exploring" if exploring else "blocked_returning"
			return
		var needed: float = distance * cost / config.speed
		if needed <= budget:
			agent.position = target
			agent.cursor += 1
			budget -= needed
			if exploring:
				agent.return_path.append(target)
		else:
			agent.position = agent.position.move_toward(target, budget * config.speed / cost)
			budget = 0.0


func _reject(reason: String) -> bool:
	last_error = reason
	return false
