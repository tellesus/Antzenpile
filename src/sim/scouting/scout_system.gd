extends RefCounted

const Agent = preload("res://src/sim/scouting/scout_agent.gd")
const Pathfinder = preload("res://src/sim/scouting/scout_pathfinder.gd")
const Senses = preload("res://src/sim/scouting/scout_senses.gd")
const Evidence = preload("res://src/sim/scouting/observation.gd")
const Memory = preload("res://src/sim/knowledge/scout_mission_memory.gd")
const Caution = preload("res://src/sim/scouting/scout_caution.gd")
var config: ScoutConfig = preload("res://data/scouting/default_scouts.tres")
var last_error: String = ""
var _run: RunState
var _predator: PredatorSystem


func _init(run_state: RunState) -> void:
	_run = run_state
	_predator = PredatorSystem.new(run_state)


func dispatch(origin_id: String, bearing: Variant = null, standing: bool = false) -> bool:
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
	var cautions: Array[String] = []
	if standing:
		cautions = Caution.routes(_run, origin_id)
	for attempt: int in config.target_attempts:
		var angle: float = _run.rng.randf_range(-PI, PI) if bearing == null else float(bearing) + _run.rng.randf_range(-config.cone_radians, config.cone_radians)
		var distance: float = _run.rng.randf_range(config.minimum_distance, config.maximum_distance)
		var target: Vector2 = (origin.position + Vector2.from_angle(angle) * distance).round()
		route = finder.path(origin.position, target)
		if route.size() > 1:
			if not cautions.is_empty() and Caution.path_risk(route, cautions, _run.trails, origin.position) > 0.0 and attempt < config.target_attempts - 1:
				continue
			var freshness: float = _run.exploration.coverage.get(_run.exploration.cell_key(target, _run.world.bounds), 0.0) if standing else 0.0
			if freshness > 0 and _run.rng.randf() < freshness * config.novelty_rejection and attempt < config.target_attempts - 1:
				continue
			break
	if route.size() < 2:
		_run.rng.state = saved_rng
		return _reject("No reachable scout target")
	return _dispatch_route(origin, route, standing, (route.back() - origin.position).angle() if bearing == null else float(bearing))


func _dispatch_route(origin: PileState, route: Array[Vector2], standing: bool, bearing: float, source_id: String = "", trunk_id: String = "") -> bool:
	if origin.workers_available < 1 or _run.active_scout_count() >= config.active_cap or _run.next_scout_id >= WorkerLedger.MAX_COUNT:
		return _reject("Scout labor or capacity unavailable")
	var id: String = "scout_%d" % _run.next_scout_id
	if origin.workers.count(id) >= 0 or not origin.workers.create_commitment(id, "scout", id):
		return _reject("Scout commitment unavailable")
	var allocated: bool = origin.workers.allocate(id, 1)
	assert(allocated)
	var agent := Agent.new()
	agent.id = id
	agent.origin_pile = origin.id
	agent.standing = standing
	if standing and source_id.is_empty():
		agent.avoid_routes = Caution.routes(_run, origin.id)
	agent.position = origin.position
	agent.path = route
	agent.mission_target = route.back()
	agent.return_path.append(origin.position)
	agent.investigation_source_id = source_id
	agent.trunk_route_id = trunk_id
	var round_trip: float = 0.0
	for index: int in range(1, route.size()):
		round_trip += 2.0 * maxf(Pathfinder.travel_cost(_run.world, route[index - 1]), Pathfinder.travel_cost(_run.world, route[index])) / config.speed
	var expectation: float = config.manual_expectation_seconds
	if standing:
		expectation = round_trip + 2.0 * (config.standing_search_seconds + config.cue_extension_seconds) + config.return_grace_seconds
	elif not source_id.is_empty():
		expectation = round_trip + config.return_grace_seconds
	agent.expected_tick = _run.clock.tick_count + ceili(expectation / SimulationClock.TICK_INTERVAL)
	if not trunk_id.is_empty():
		agent.trunk_path = route.duplicate()
	_run.scouts[id] = agent
	_remember_departure(agent, bearing)
	_run.next_scout_id += 1
	last_error = ""
	return true


func _dispatch_general(origin_id: String, bearing: Variant) -> bool:
	var candidates: Array[TrailRouteState] = []
	for route: TrailRouteState in _run.trails.routes.values():
		var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
		if route.origin_pile != origin_id or route.delivered_total <= 0 or segment.route_familiarity < config.established_trail_familiarity or route.reported_losses > 0 and not Caution.addressed(route, _run.journey_response.defense.outcomes) or route.conflict_report not in ["", "secured", "dispersed"] or route.foreign_reports > 0:
			continue
		var direction: float = (route.estimated_destination - _run.colony.piles[origin_id].position).angle()
		if bearing != null and absf(wrapf(direction - float(bearing), -PI, PI)) > config.cone_radians:
			continue
		candidates.append(route)
	candidates.sort_custom(func(a: TrailRouteState, b: TrailRouteState) -> bool: return a.id < b.id)
	if not candidates.is_empty() and _run.rng.randf() < config.trail_exploration_share:
		var selected: TrailRouteState = candidates[_run.rng.randi_range(0, candidates.size() - 1)]
		var origin: PileState = _run.colony.piles[origin_id]
		var path: Array[Vector2] = Pathfinder.new(_run.world).path(origin.position, selected.estimated_destination.round())
		if path.size() > 1 and Caution.path_risk(path, Caution.routes(_run, origin_id), _run.trails, origin.position) == 0.0:
			return _dispatch_route(origin, path, true, (path.back() - origin.position).angle(), "", selected.id)
	return dispatch(origin_id, bearing, true)



func set_effort(target: Variant) -> bool:
	if typeof(target) != TYPE_INT or not WorkerLedger.valid_count(target) or target > config.active_cap:
		return _reject("Exploration target must fit the scout capacity")
	_run.exploration.target = target
	var active: Array[ScoutAgent] = []
	for agent: ScoutAgent in _run.scouts.values():
		if agent.standing and not agent.lost and agent.phase not in ["returning", "blocked_returning"]:
			active.append(agent)
	active.sort_custom(func(a: ScoutAgent, b: ScoutAgent) -> bool: return a.id.trim_prefix("scout_").to_int() > b.id.trim_prefix("scout_").to_int())
	while active.size() > target:
		_start_return(active.pop_front())
	last_error = ""
	return true


func set_bias(bearing: Variant) -> bool:
	if bearing != null and (not typeof(bearing) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(bearing))):
		return _reject("Exploration bearing must be finite")
	_run.exploration.bias = null if bearing == null else _memory_bearing(float(bearing))
	last_error = ""
	return true


func standing_count() -> int:
	var count: int = 0
	for agent: ScoutAgent in _run.scouts.values():
		count += 1 if agent.standing else 0
	return count


func recall(id: String) -> bool:
	if not _run.scouts.has(id):
		return _reject("Scout mission no longer awaiting return")
	var agent: ScoutAgent = _run.scouts[id]
	# An absence cannot acknowledge a command differently from a living scout.
	if not agent.lost:
		_start_return(agent)
	last_error = ""
	return true


func maintain_effort() -> void:
	var policy: ExplorationState = _run.exploration
	policy.cooldown_ticks = maxi(0, policy.cooldown_ticks - 1)
	if policy.cooldown_ticks > 0 or standing_count() >= policy.target or _run.active_scout_count() >= config.active_cap or _run.colony.piles.home.workers_available < 1:
		return
	var saved_rng: int = _run.rng.state
	var bearing: Variant = policy.bias if policy.bias != null and _run.rng.randf() < config.directional_share else null
	var id: String = "scout_%d" % _run.next_scout_id
	var priority: String = _next_investigation() if policy.investigation_turn else ""
	var accepted: bool = dispatch_investigation("home", priority) if not priority.is_empty() else _dispatch_general("home", bearing)
	if not accepted and not priority.is_empty():
		priority = ""
		accepted = _dispatch_general("home", bearing)
	if accepted:
		_run.scouts[id].standing = true
		_run.scouts[id].search_memory = policy.coverage.duplicate()
		for known: KnownNode in _run.knowledge.nodes.values():
			if known.confidence_at(_run.simulation_time) >= config.verification_confidence:
				_run.scouts[id].known_sources.append(known.source_node_id)
		if not _run.scouts[id].trunk_route_id.is_empty():
			var source_id: String = _run.knowledge.nodes[_run.trails.routes[_run.scouts[id].trunk_route_id].destination_knowledge_id].source_node_id
			if source_id not in _run.scouts[id].known_sources:
				_run.scouts[id].known_sources.append(source_id)
		_run.scouts[id].known_sources.sort()
		for resource: String in PileState.RESOURCE_IDS:
			_run.scouts[id].need_weights[resource] = roundf((1.0 + config.need_weight / (1.0 + _run.colony.piles.home.resources[resource])) * 1e8) / 1e8
		policy.investigation_turn = not policy.investigation_turn
		if not priority.is_empty():
			policy.priority_last_sent[priority] = _run.simulation_time
	else:
		_run.rng.state = saved_rng
	policy.cooldown_ticks = config.departure_interval_ticks


func set_priority(knowledge_id: String, enabled: bool) -> bool:
	if not _run.knowledge.nodes.has(knowledge_id):
		return _reject("Investigation needs a returned source report")
	var policy: ExplorationState = _run.exploration
	if enabled and knowledge_id not in policy.priorities:
		if policy.priorities.size() >= config.active_cap:
			return _reject("Investigation priorities full")
		policy.priorities.append(knowledge_id)
	elif not enabled:
		policy.priorities.erase(knowledge_id)
		policy.priority_last_sent.erase(knowledge_id)
	policy.priority_cursor %= maxi(1, policy.priorities.size())
	last_error = ""
	return true


func _next_investigation() -> String:
	var policy: ExplorationState = _run.exploration
	var investigating: int = 0
	var busy: Array[String] = []
	for agent: ScoutAgent in _run.scouts.values():
		if agent.standing and not agent.investigation_source_id.is_empty():
			investigating += 1
			busy.append("known:" + agent.investigation_source_id)
	if investigating >= maxi(1, policy.target / 2):
		return ""
	for attempt: int in policy.priorities.size():
		var id: String = policy.priorities[policy.priority_cursor]
		policy.priority_cursor = (policy.priority_cursor + 1) % policy.priorities.size()
		if id not in busy and _run.simulation_time - policy.priority_last_sent.get(id, -config.verification_interval) >= config.verification_interval:
			return id
	return ""


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
	return _dispatch_route(pile, route, false, (target - pile.position).angle(), known.source_node_id)



func tick(delta: float) -> void:
	_run.exploration.decay(delta, _run.rain.phase == "raining")
	for memory: ScoutMissionMemory in _run.scout_missions.values():
		var half_life: float = config.rain_scent_half_life if _run.rain.phase == "raining" else config.departure_scent_half_life
		memory.scent = roundf(memory.scent * pow(0.5, delta / half_life) * 1e10) / 1e10
		if memory.scent < 0.0001:
			memory.scent = 0.0
	var ids: Array = _run.scouts.keys()
	ids.sort()
	for id: String in ids:
		var agent: ScoutAgent = _run.scouts[id]
		if agent.lost:
			if _run.clock.tick_count >= agent.expected_tick:
				_settle_missing(agent)
			continue
		if _ambush(agent, agent.position):
			continue
		if agent.phase == "departing":
			agent.phase = "following_trail" if not agent.trunk_route_id.is_empty() else "exploring"
			continue
		if agent.phase in ["following_trail", "blocked_following_trail"]:
			Senses.sample(agent, _run.world, config, _run.rng, _run.simulation_time)
			_move(agent, delta, true)
			if agent.lost:
				continue
			Senses.sample(agent, _run.world, config, _run.rng, _run.simulation_time)
			if agent.phase == "blocked_exploring":
				agent.phase = "blocked_following_trail"
			elif agent.cursor >= agent.path.size() and not _continue_search(agent):
				_start_return(agent)
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
		if agent.lost:
			continue
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
			_remember_return(agent, home.position)
			if agent.standing:
				_run.exploration.record_return(agent.return_path, _run.world.bounds)
			for observation: Observation in agent.observations.values():
				observation.collective_search = agent.standing
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
		if agent.standing and agent.phase in ["exploring", "blocked_exploring"] and _at_breadcrumb(agent) and agent.elapsed >= config.standing_search_seconds:
			if agent.investigating.is_empty() or agent.elapsed >= config.standing_search_seconds + config.cue_extension_seconds:
				_start_return(agent)


func _remember_departure(agent: ScoutAgent, bearing: float) -> void:
	var memory := Memory.new()
	memory.id = agent.id
	memory.origin_pile = agent.origin_pile
	memory.bearing = _memory_bearing(bearing)
	memory.departed_at = _run.simulation_time
	memory.expected_at = agent.expected_tick * SimulationClock.TICK_INTERVAL
	_run.scout_missions[agent.id] = memory


func _remember_return(agent: ScoutAgent, home: Vector2) -> void:
	if not _run.scout_missions.has(agent.id):
		return # Older saves contain no reliable departure history.
	var memory: ScoutMissionMemory = _run.scout_missions[agent.id]
	memory.returned_at = _run.simulation_time
	var count: int = mini(Memory.MAX_COURSE, agent.return_path.size() - 1)
	for index: int in count:
		var sample_index: int = 1 + int(float(index) * (agent.return_path.size() - 2) / maxi(1, count - 1))
		var relative: Vector2 = agent.return_path[sample_index] - home
		if relative.is_zero_approx():
			continue
		memory.course.append({"bearing": _memory_bearing(roundf(relative.angle() * 10.0) / 10.0),
			"estimated_distance": roundf(relative.length() / 2.0) * 2.0})
	_prune_history()


func _prune_history() -> void:
	var returned: Array[ScoutMissionMemory] = []
	for record: ScoutMissionMemory in _run.scout_missions.values():
		if record.completed_at() >= 0.0:
			returned.append(record)
	returned.sort_custom(func(a: ScoutMissionMemory, b: ScoutMissionMemory) -> bool:
		return a.completed_at() < b.completed_at() if a.completed_at() != b.completed_at() else a.id < b.id)
	while returned.size() > Memory.RECENT_RETURNS:
		_run.scout_missions.erase(returned.pop_front().id)


func _ambush(agent: ScoutAgent, from: Vector2) -> bool:
	if agent.predator_encountered or _run.clock.tick_count < PredatorSystem.CONFIG.first_tick:
		return false
	var edge: Vector2 = agent.position - from
	var t: float = clampf((PredatorSystem.CONFIG.position - from).dot(edge) / maxf(edge.length_squared(), 0.000001), 0.0, 1.0)
	var encounter: Vector2 = from + edge * t
	if encounter.distance_to(PredatorSystem.CONFIG.position) > PredatorSystem.CONFIG.radius:
		return false
	agent.predator_encountered = true
	if not _predator.encounter(encounter):
		return false
	var pile: PileState = _run.colony.piles[agent.origin_pile]
	var adapted: int = 1 if _run.rng.randf() < pile.adaptation_fraction() else 0
	var profile: String = pile.genetics.loss_profile(adapted == 1, pile.adaptation_repertoire, pile.workers_total, _run.rng)
	assert(pile.lose_workers(agent.id, 1, adapted, "scout ambush", profile))
	agent.lost = true
	agent.lost_profile = profile
	agent.observations.clear()
	agent.investigating = ""
	# Old saves did not capture an expectation. Do not invent departure history.
	if agent.expected_tick == 0:
		agent.expected_tick = _run.clock.tick_count + ceili(config.manual_expectation_seconds / SimulationClock.TICK_INTERVAL)
	elif agent.expected_tick <= _run.clock.tick_count:
		# A late mission must not reveal the exact tick of a new remote casualty.
		agent.expected_tick = _run.clock.tick_count + ceili(config.return_grace_seconds / SimulationClock.TICK_INTERVAL)
	_run.scout_losses[agent.origin_pile] = _run.scout_losses.get(agent.origin_pile, 0) + 1
	return true


func _settle_missing(agent: ScoutAgent) -> void:
	if _run.scout_missions.has(agent.id):
		var memory: ScoutMissionMemory = _run.scout_missions[agent.id]
		if memory.expected_at < 0.0:
			memory.expected_at = agent.expected_tick * SimulationClock.TICK_INTERVAL
		memory.missing_at = _run.simulation_time
	assert(_run.colony.piles[agent.origin_pile].workers.retire_commitment(agent.id))
	_run.scouts.erase(agent.id)
	_prune_history()


static func _memory_bearing(value: float) -> float:
	# Stable decimals also keep earlier version-5 JSON snapshot clients compatible.
	var normalized: float = roundf(fposmod(value, TAU) * 1e8) / 1e8
	return 0.0 if normalized >= TAU else normalized


func _confirmed_new_source(agent: ScoutAgent) -> bool:
	for source_id: String in agent.observations:
		if agent.observations[source_id].proximity_confirmed and _needs_confirmation(source_id, agent):
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
		if not _needs_confirmation(source_id, agent) or evidence.proximity_confirmed:
			continue
		var need: float = agent.need_weights.get(evidence.definition_id, 1.0) if agent.standing else 1.0
		var distance: float = evidence.closest_distance / need
		if distance < closest:
			closest = distance
			chosen = source_id
	return chosen


func _needs_confirmation(source_id: String, agent: ScoutAgent) -> bool:
	var id: String = "known:" + source_id
	return source_id not in agent.known_sources if agent.standing else not _run.knowledge.nodes.has(id)


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
				if agent.standing and radius < 0:
					score -= config.coverage_frontier_penalty * agent.search_memory.get(_run.exploration.cell_key(candidate, _run.world.bounds), 0.0) * pow(0.5, agent.elapsed / config.coverage_half_life)
				if not agent.avoid_routes.is_empty():
					score -= config.caution_frontier_penalty * Caution.path_risk(route.slice(1), agent.avoid_routes, _run.trails, _run.colony.piles[agent.origin_pile].position)
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
		var speed: float = config.speed * (config.trail_travel_multiplier if _on_trunk_edge(agent, target) else 1.0)
		var needed: float = distance * cost / speed
		if needed <= budget:
			var from: Vector2 = agent.position
			agent.position = target
			agent.cursor += 1
			budget -= needed
			if exploring:
				agent.return_path.append(target)
			if _ambush(agent, from):
				return
		else:
			var from: Vector2 = agent.position
			agent.position = agent.position.move_toward(target, budget * speed / cost)
			budget = 0.0
			if _ambush(agent, from):
				return


func _on_trunk_edge(agent: ScoutAgent, target: Vector2) -> bool:
	for index: int in range(1, agent.trunk_path.size()):
		var a: Vector2 = agent.trunk_path[index - 1]
		var b: Vector2 = agent.trunk_path[index]
		if target in [a, b] and absf(agent.position.distance_to(a) + agent.position.distance_to(b) - 1.0) < 0.0001:
			return true
	return false


func _reject(reason: String) -> bool:
	last_error = reason
	return false
