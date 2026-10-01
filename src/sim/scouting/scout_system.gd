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
	if not _run.colony.piles.has(origin_id) or _run.active_scout_count() >= config.active_cap:
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


func dispatch_investigation(origin_id: String, knowledge_id: String) -> bool:
	last_error = ""
	if not _run.colony.piles.has(origin_id) or not _run.knowledge.nodes.has(knowledge_id):
		return _reject("Known source unavailable")
	if _run.active_scout_count() >= config.active_cap or _run.next_scout_id >= WorkerLedger.MAX_COUNT:
		return _reject("Scout cap reached")
	var pile: PileState = _run.colony.piles[origin_id]
	if pile.workers_available < 1:
		return _reject("No available worker")
	var known: KnownNode = _run.knowledge.nodes[knowledge_id]
	var target: Vector2 = known.estimated_position.round()
	var route: Array[Vector2] = Pathfinder.new(_run.world).path(pile.position, target)
	if route.size() < 2:
		return _reject("No reachable known estimate")
	var id: String = "scout_%d" % _run.next_scout_id
	if pile.workers.count(id) >= 0 or not pile.workers.create_commitment(id, "scout", id):
		return _reject("Scout commitment unavailable")
	var allocated: bool = pile.workers.allocate(id, 1)
	assert(allocated)
	var agent := Agent.new()
	agent.id = id
	agent.origin_pile = origin_id
	agent.position = pile.position
	agent.path = route
	agent.mission_target = target
	agent.return_path.append(pile.position)
	agent.investigation_source_id = known.source_node_id
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
		Senses.sample(agent, _run.world, config, _run.rng, _run.simulation_time)
		if exploring:
			if not agent.investigation_source_id.is_empty():
				if _at_breadcrumb(agent) and (agent.cursor >= agent.path.size() or _confirmed_target(agent)):
					_start_return(agent)
					exploring = false
			elif _confirmed_new_source(agent) and _at_breadcrumb(agent):
				_start_return(agent)
				exploring = false
			elif _at_breadcrumb(agent):
				var cue: String = _new_source_cue(agent)
				if not cue.is_empty():
					_investigate(agent, cue)
				if agent.cursor >= agent.path.size() and not _continue_search(agent):
					_start_return(agent)
					exploring = false
		if not exploring and agent.phase != "returning":
			agent.phase = "returning"
		_move(agent, delta, exploring)
		Senses.sample(agent, _run.world, config, _run.rng, _run.simulation_time)
		if exploring:
			agent.elapsed += delta
			if agent.investigation_source_id.is_empty() and _confirmed_new_source(agent) and _at_breadcrumb(agent):
				_start_return(agent)
			elif not agent.investigation_source_id.is_empty() and agent.cursor >= agent.path.size():
				_start_return(agent)
		elif agent.cursor >= agent.path.size():
			var home: PileState = _run.colony.piles[agent.origin_pile]
			assert(agent.position == home.position)
			for observation: Observation in agent.observations.values():
				assert(not _run.delivered_observations.has(observation.id))
				var delivered := Evidence.new()
				var valid: bool = delivered.restore(observation.to_dict(), _run.world, _run.colony, _run.simulation_time)
				assert(valid)
				_run.delivered_observations[delivered.id] = delivered
			if not agent.investigation_source_id.is_empty() and not agent.observations.has(agent.investigation_source_id):
				assert(_run.knowledge.record_outcome(agent.investigation_source_id, false, _run.simulation_time, "scout"))
			var released: bool = home.workers.release(id, 1)
			assert(released)
			var retired: bool = home.workers.retire_commitment(id)
			assert(retired)
			_run.scouts.erase(id)


func _confirmed_new_source(agent: ScoutAgent) -> bool:
	for source_id: String in agent.observations:
		if agent.observations[source_id].proximity_confirmed and not _run.knowledge.nodes.has("known:" + source_id):
			return true
	return false


func _confirmed_target(agent: ScoutAgent) -> bool:
	return agent.observations.has(agent.investigation_source_id) and agent.observations[agent.investigation_source_id].proximity_confirmed


func _new_source_cue(agent: ScoutAgent) -> String:
	var ids: Array = agent.observations.keys()
	ids.sort()
	var closest: float = INF
	var chosen: String = ""
	for source_id: String in ids:
		var evidence: Observation = agent.observations[source_id]
		if _run.knowledge.nodes.has("known:" + source_id) or evidence.proximity_confirmed:
			continue
		if evidence.closest_distance < closest:
			closest = evidence.closest_distance
			chosen = source_id
	return chosen


func _at_breadcrumb(agent: ScoutAgent) -> bool:
	return agent.position.distance_to(agent.return_path.back()) < 0.0001


func _start_return(agent: ScoutAgent) -> void:
	agent.path = agent.return_path.duplicate()
	agent.path.reverse()
	agent.cursor = 0
	agent.phase = "returning"
	agent.investigating = ""


func _investigate(agent: ScoutAgent, cue: String) -> void:
	if agent.investigating == cue and agent.cursor < agent.path.size():
		return
	var evidence: Observation = agent.observations[cue]
	var estimate: Vector2 = evidence.estimated_position.round()
	var route: Array[Vector2] = []
	if not agent.return_path.has(estimate):
		route = Pathfinder.new(_run.world).path(agent.position, estimate)
	if route.size() < 2:
		route = _frontier_path(agent, evidence.estimated_position, ceili(evidence.uncertainty_radius) + 2)
	if route.size() > 1:
		_set_search_path(agent, route, cue)
	else:
		agent.investigating = ""


func _continue_search(agent: ScoutAgent) -> bool:
	var route: Array[Vector2] = _frontier_path(agent, agent.position, -1)
	if route.size() < 2:
		return false
	_set_search_path(agent, route, "")
	return true


func _set_search_path(agent: ScoutAgent, route: Array[Vector2], cue: String) -> void:
	agent.path = route
	agent.cursor = 1
	agent.mission_target = route.back()
	agent.investigating = cue
	agent.phase = "exploring"


func _frontier_path(agent: ScoutAgent, center: Vector2, radius: int) -> Array[Vector2]:
	# Choose from unvisited reachable cells, never from hidden source positions.
	var visited: Dictionary = {}
	for point: Vector2 in agent.return_path:
		visited[Vector2i(point)] = true
	var current: Vector2 = agent.position.round()
	var maximum_ring: int = ceili(_run.world.bounds.size.x + _run.world.bounds.size.y)
	var finder: Variant = null
	var outward: Vector2 = (current - _run.colony.piles[agent.origin_pile].position).normalized()
	for ring: int in range(1, maximum_ring + 1):
		var best_path: Array[Vector2] = []
		var best_score: float = -INF
		for dy: int in range(-ring, ring + 1):
			var dx: int = ring - absi(dy)
			for direction: int in [-1, 1]:
				if dx == 0 and direction == 1:
					continue
				var candidate: Vector2 = current + Vector2(dx * direction, dy)
				if visited.has(Vector2i(candidate)) or not _run.world.bounds.has_point(candidate) or radius >= 0 and candidate.distance_to(center) > radius:
					continue
				if not is_finite(Pathfinder.travel_cost(_run.world, candidate)):
					continue
				var route: Array[Vector2] = [current, candidate]
				if ring > 1:
					if finder == null:
						finder = Pathfinder.new(_run.world)
					route = finder.path(current, candidate)
				if route.size() < 2:
					continue
				var score: float = -candidate.distance_to(center) if radius >= 0 else (candidate - current).dot(outward)
				if score > best_score:
					best_score = score
					best_path = route
		if not best_path.is_empty():
			return best_path
	return []


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
