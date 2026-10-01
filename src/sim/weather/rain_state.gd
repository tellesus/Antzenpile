class_name RainState
extends RefCounted
## First front waits for established traffic; later fronts follow saved clock ticks.

const CONFIG = preload("res://data/weather/default_rain.tres")
var phase: String = "waiting"
var elapsed_seconds: float = 0.0
var fronts_completed: int = 0
var next_start_tick: int = 0


func to_dict() -> Dictionary:
	return {"phase": phase, "elapsed_seconds": elapsed_seconds,
		"fronts_completed": fronts_completed, "next_start_tick": str(next_start_tick)}


func restore(data: Dictionary, current_tick: int = 0) -> bool:
	if not data.has_all(["phase", "elapsed_seconds"]) or not data.phase is String or not data.phase in ["waiting", "raining", "finished"]:
		return false
	if not typeof(data.elapsed_seconds) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.elapsed_seconds)):
		return false
	var elapsed: float = float(data.elapsed_seconds)
	if elapsed < 0.0 or elapsed > CONFIG.duration_seconds:
		return false
	if data.phase == "waiting" and elapsed != 0.0 or data.phase == "raining" and elapsed >= CONFIG.duration_seconds or data.phase == "finished" and elapsed != CONFIG.duration_seconds:
		return false
	var completed: Variant = data.get("fronts_completed", 1 if data.phase == "finished" else 0)
	var next_tick_value: Variant = data.get("next_start_tick", str(current_tick + CONFIG.dry_interval_ticks) if data.phase == "finished" else "0")
	if not typeof(completed) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(completed)) or completed < 0 or float(completed) != int(completed) or not next_tick_value is String or not next_tick_value.is_valid_int() or str(next_tick_value.to_int()) != next_tick_value:
		return false
	var next_tick: int = next_tick_value.to_int()
	if next_tick < 0 or (data.phase == "waiting" and (completed != 0 or next_tick != 0)) or (data.phase == "raining" and next_tick != 0) or (data.phase == "finished" and (completed < 1 or next_tick <= current_tick)):
		return false
	phase = data.phase
	elapsed_seconds = elapsed
	fronts_completed = completed
	next_start_tick = next_tick
	return true
