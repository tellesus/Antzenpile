class_name RainState
extends RefCounted
## One slice event; all time is simulated fixed-tick time.

const CONFIG = preload("res://data/weather/default_rain.tres")
var phase: String = "waiting"
var elapsed_seconds: float = 0.0


func to_dict() -> Dictionary:
	return {"phase": phase, "elapsed_seconds": elapsed_seconds}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["phase", "elapsed_seconds"]) or not data.phase is String or not data.phase in ["waiting", "raining", "finished"]:
		return false
	if not typeof(data.elapsed_seconds) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.elapsed_seconds)):
		return false
	var elapsed: float = float(data.elapsed_seconds)
	if elapsed < 0.0 or elapsed > CONFIG.duration_seconds:
		return false
	if data.phase == "waiting" and elapsed != 0.0 or data.phase == "raining" and elapsed >= CONFIG.duration_seconds or data.phase == "finished" and elapsed != CONFIG.duration_seconds:
		return false
	phase = data.phase
	elapsed_seconds = elapsed
	return true
