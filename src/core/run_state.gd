class_name RunState
extends RefCounted

const Clock = preload("res://src/core/simulation_clock.gd")
const SNAPSHOT_VERSION: int = 1
const World = preload("res://src/sim/world/world_state.gd")
const Loader = preload("res://src/sim/world/world_loader.gd")
const Colony = preload("res://src/sim/colony/colony_state.gd")
const Scout = preload("res://src/sim/scouting/scout_agent.gd")
const SCOUT_CONFIG = preload("res://data/scouting/default_scouts.tres")
var world: WorldState
var colony: ColonyState = Colony.new()
var scouts: Dictionary[String, ScoutAgent] = {}
var next_scout_id: int = 1

var run_seed: int:
	get: return _seed
var scenario_id: String:
	get: return _scenario_id
var clock: SimulationClock = Clock.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var simulation_time: float:
	get: return clock.simulation_time

var _seed: int
var _scenario_id: String


func _init(seed_value: int = 482817, scenario: String = "backyard_slice") -> void:
	_seed = seed_value
	_scenario_id = scenario
	rng.seed = _seed
	world = Loader.new().load_scenario()
	colony.initialize_home(world.home_position)


func to_dict() -> Dictionary:
	var scout_records: Array[Dictionary] = []
	var ids: Array = scouts.keys()
	ids.sort()
	for id: String in ids:
		scout_records.append(scouts[id].to_dict())
	# JSON numbers cannot represent all 64-bit RNG states exactly.
	return {"version": SNAPSHOT_VERSION, "seed": str(_seed), "rng_state": str(rng.state),
		"scenario_id": _scenario_id, "clock": clock.to_dict(), "world": world.to_dict(), "colony": colony.to_dict(),
		"scouts": scout_records, "next_scout_id": next_scout_id}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["version", "seed", "rng_state", "scenario_id", "clock", "world", "colony", "scouts", "next_scout_id"]):
		return false
	if data.version != SNAPSHOT_VERSION or not data.scenario_id is String or data.scenario_id.is_empty():
		return false
	for field: String in ["seed", "rng_state"]:
		if not data[field] is String or not data[field].is_valid_int() or str(data[field].to_int()) != data[field]:
			return false
	var restored_world := World.new()
	if not data.world is Dictionary or not restored_world.restore(data.world, Loader.definition_ids()):
		return false
	var restored_colony := Colony.new()
	if not data.colony is Dictionary or not restored_colony.restore(data.colony, restored_world.bounds, restored_world.home_position):
		return false
	if not data.scouts is Array or data.scouts.size() > SCOUT_CONFIG.active_cap or not WorkerLedger.valid_count(data.next_scout_id) or data.next_scout_id < 1:
		return false
	var restored_scouts: Dictionary[String, ScoutAgent] = {}
	for value: Variant in data.scouts:
		var agent := Scout.new()
		if not value is Dictionary or not agent.restore(value, restored_world, restored_colony) or restored_scouts.has(agent.id):
			return false
		var suffix: String = agent.id.trim_prefix("scout_")
		if not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_scout_id:
			return false
		restored_scouts[agent.id] = agent
	for pile: PileState in restored_colony.piles.values():
		for id: String in pile.workers.to_dict().commitments:
			if id.begins_with("scout_") and (not restored_scouts.has(id) or restored_scouts[id].origin_pile != pile.id):
				return false
	if not data.clock is Dictionary or not clock.restore(data.clock):
		return false
	_seed = data.seed.to_int()
	_scenario_id = data.scenario_id
	# Seed first: assigning seed resets generator state.
	rng.seed = _seed
	rng.state = data.rng_state.to_int()
	world = restored_world
	colony = restored_colony
	scouts = restored_scouts
	next_scout_id = int(data.next_scout_id)
	return true
