class_name SimulationController
extends RefCounted
## Run-scoped composition; no scene tree, input, or graphics required.

const Run = preload("res://src/core/run_state.gd")
var run: RunState


func _init(seed_value: int = 482817) -> void:
	run = Run.new(seed_value)


func advance(real_delta: float) -> bool:
	return run.clock.advance(real_delta)
