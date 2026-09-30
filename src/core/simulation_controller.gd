class_name SimulationController
extends RefCounted
## Run-scoped composition; no scene tree, input, or graphics required.

const Run = preload("res://src/core/run_state.gd")
const Scouts = preload("res://src/sim/scouting/scout_system.gd")
var run: RunState
var scouting: RefCounted


func _init(seed_value: int = 482817) -> void:
	run = Run.new(seed_value)
	scouting = Scouts.new(run)
	run.clock.tick.connect(_tick)


func dispatch_scout(origin_id: String, bearing: Variant = null) -> bool:
	return scouting.dispatch(origin_id, bearing)


func advance(real_delta: float) -> bool:
	return run.clock.advance(real_delta)


func toggle_pause() -> void:
	run.clock.paused = not run.clock.paused


func set_time_scale(value: int) -> bool:
	return run.clock.set_time_scale(value)


func _tick(delta: float) -> void:
	scouting.tick(delta)
	if not run.delivered_observations.is_empty():
		if not run.knowledge.consume(run.delivered_observations, run.simulation_time):
			push_error("Knowledge delivery rejected: " + run.knowledge.last_error)
