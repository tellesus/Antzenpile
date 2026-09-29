class_name RunState
extends RefCounted

const Clock = preload("res://src/core/simulation_clock.gd")
const SNAPSHOT_VERSION: int = 1
const World = preload("res://src/sim/world/world_state.gd")
const Loader = preload("res://src/sim/world/world_loader.gd")
var world: WorldState

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


func to_dict() -> Dictionary:
	# JSON numbers cannot represent all 64-bit RNG states exactly.
	return {"version": SNAPSHOT_VERSION, "seed": str(_seed), "rng_state": str(rng.state),
		"scenario_id": _scenario_id, "clock": clock.to_dict(), "world": world.to_dict()}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["version", "seed", "rng_state", "scenario_id", "clock", "world"]):
		return false
	if data.version != SNAPSHOT_VERSION or not data.scenario_id is String or data.scenario_id.is_empty():
		return false
	for field: String in ["seed", "rng_state"]:
		if not data[field] is String or not data[field].is_valid_int() or str(data[field].to_int()) != data[field]:
			return false
	var restored_world := World.new()
	if not data.world is Dictionary or not restored_world.restore(data.world, Loader.definition_ids()):
		return false
	if not data.clock is Dictionary or not clock.restore(data.clock):
		return false
	_seed = data.seed.to_int()
	_scenario_id = data.scenario_id
	# Seed first: assigning seed resets generator state.
	rng.seed = _seed
	rng.state = data.rng_state.to_int()
	world = restored_world
	return true
