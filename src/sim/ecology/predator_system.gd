class_name PredatorSystem
extends RefCounted

const CONFIG = preload("res://data/ecology/backyard_predator.tres")
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state


func encounter(point: Vector2) -> bool:
	var state: PredatorState = _run.predator
	var tick: int = _run.clock.tick_count
	if tick < CONFIG.first_tick or (state.last_attack_tick >= 0 and tick - state.last_attack_tick < CONFIG.recovery_ticks) or point.distance_to(CONFIG.position) > CONFIG.radius or state.kills_total >= WorkerLedger.MAX_COUNT:
		return false
	state.last_attack_tick = tick
	state.kills_total += 1
	return true
