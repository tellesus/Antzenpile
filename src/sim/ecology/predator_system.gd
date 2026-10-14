class_name PredatorSystem
extends RefCounted

const CONFIG = preload("res://data/ecology/backyard_predator.tres")
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state


func tick() -> void:
	if _run.predator.motion!=null: _run.predator.motion.tick(_run)

func in_range(point: Vector2, extra: float = 0.0) -> bool:
	return _run.predator.defeated_at==0 and _run.clock.tick_count>=_run.predator.definition().first_tick and point.distance_to(_run.predator.position())<=_run.predator.definition().radius+extra

func crosses(from: Vector2, to: Vector2) -> bool:
	if _run.predator.defeated_at>0 or _run.clock.tick_count<_run.predator.definition().first_tick: return false
	var previous: Vector2=_run.predator.motion.previous if _run.predator.motion!=null else _run.predator.position()
	var nearest: Vector2=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,from-previous,to-_run.predator.position())
	return nearest.length()<=_run.predator.definition().radius

func encounter(point: Vector2, from: Vector2 = Vector2.INF) -> bool:
	var state: PredatorState = _run.predator
	var tick: int = _run.clock.tick_count
	if (not crosses(from,point) if from.is_finite() else not in_range(point)) or (state.last_attack_tick>=0 and tick-state.last_attack_tick<state.definition().recovery_ticks) or state.kills_total>=WorkerLedger.MAX_COUNT:
		return false
	state.last_attack_tick = tick
	state.kills_total += 1
	return true
