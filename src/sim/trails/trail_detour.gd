class_name TrailDetour
extends RefCounted
## One cohort worker walking from a sensory cue to its estimate and back.

const Agent = preload("res://src/sim/scouting/scout_agent.gd")
const Senses = preload("res://src/sim/scouting/scout_senses.gd")
const Pathfinder = preload("res://src/sim/scouting/scout_pathfinder.gd")
const Evidence = preload("res://src/sim/scouting/observation.gd")
const SCOUT_CONFIG = preload("res://data/scouting/default_scouts.tres")

var id: String
var source_id: String
var origin_pile: String
var position: Vector2
var path: Array[Vector2] = []
var cursor: int = 1
var phase: String = "outbound"
var step_ticks: int = 0
var observation: Observation


func to_dict() -> Dictionary:
	var points: Array = []
	for point: Vector2 in path:
		points.append([point.x, point.y])
	return {"id": id, "source_id": source_id, "origin_pile": origin_pile,
		"position": [position.x, position.y], "path": points, "cursor": cursor,
		"phase": phase, "step_ticks": step_ticks, "observation": observation.to_dict()}


func sample(world: WorldState, rng: RandomNumberGenerator, time: float) -> void:
	var agent := Agent.new()
	agent.id = id
	agent.origin_pile = origin_pile
	agent.position = position
	if observation != null:
		agent.observations[source_id] = observation
	Senses.sample(agent, world, SCOUT_CONFIG, rng, time)
	observation = agent.observations.get(source_id, observation)


func tick(world: WorldState, rng: RandomNumberGenerator, time: float) -> bool:
	if cursor >= path.size():
		return phase == "returning"
	var target: Vector2 = path[cursor]
	var cost: float = maxf(Pathfinder.travel_cost(world, position), Pathfinder.travel_cost(world, target))
	if not is_finite(cost):
		return false
	if step_ticks == 0:
		step_ticks = maxi(1, ceili(cost / SCOUT_CONFIG.speed / SimulationClock.TICK_INTERVAL))
	step_ticks -= 1
	if step_ticks > 0:
		return false
	position = target
	cursor += 1
	sample(world, rng, time)
	if cursor < path.size():
		return false
	if phase == "outbound":
		path.reverse()
		cursor = 1
		phase = "returning"
		return false
	return true


func restore(data: Dictionary, world: WorldState, colony: ColonyState, time: float, max_steps: int) -> bool:
	if not data.has_all(["id", "source_id", "origin_pile", "position", "path", "cursor", "phase", "step_ticks", "observation"]):
		return false
	if not data.id is String or not data.id.begins_with("scout_") or not data.source_id is String or not world.nodes.has(data.source_id) or not data.origin_pile is String or not colony.piles.has(data.origin_pile):
		return false
	if not data.phase in ["outbound", "returning"] or not data.path is Array or data.path.size() < 2 or data.path.size() > max_steps + 1 or not WorkerLedger.valid_count(data.cursor) or data.cursor < 1 or data.cursor >= data.path.size():
		return false
	if not WorkerLedger.valid_count(data.step_ticks) or data.step_ticks > 1000 or not _grid_point(data.position, world.bounds):
		return false
	var restored_path: Array[Vector2] = []
	for pair: Variant in data.path:
		if not _grid_point(pair, world.bounds):
			return false
		restored_path.append(Vector2(pair[0], pair[1]))
	for index: int in range(1, restored_path.size()):
		var distance: Vector2 = (restored_path[index] - restored_path[index - 1]).abs()
		if distance.x + distance.y != 1.0:
			return false
	if Vector2(data.position[0], data.position[1]) != restored_path[int(data.cursor) - 1]:
		return false
	var evidence := Evidence.new()
	if not data.observation is Dictionary or not evidence.restore(data.observation, world, colony, time) or evidence.scout_id != data.id or evidence.source_node_id != data.source_id or evidence.origin_pile != data.origin_pile:
		return false
	id = data.id
	source_id = data.source_id
	origin_pile = data.origin_pile
	position = Vector2(data.position[0], data.position[1])
	path = restored_path
	cursor = int(data.cursor)
	phase = data.phase
	step_ticks = int(data.step_ticks)
	observation = evidence
	return true


static func _grid_point(value: Variant, bounds: Rect2) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for component: Variant in value:
		if not typeof(component) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)) or float(component) != roundf(float(component)):
			return false
	return bounds.has_point(Vector2(value[0], value[1]))
