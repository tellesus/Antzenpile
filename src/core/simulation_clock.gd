class_name SimulationClock
extends RefCounted
## Authoritative time. Rendering supplies elapsed time, systems receive fixed steps.

signal tick(delta: float)

const TICK_INTERVAL: float = 0.25
const SCALES: Array[int] = [1, 4, 16, 64]
const MAX_TICKS_PER_ADVANCE: int = 4096

var paused: bool = false
var time_scale: int:
	get: return _time_scale
var tick_interval: float:
	get: return TICK_INTERVAL
var tick_count: int:
	get: return _tick_count
var simulation_time: float:
	get: return _tick_count * TICK_INTERVAL
var accumulator: float:
	get: return _accumulator

var _time_scale: int = 1
var _tick_count: int = 0
var _accumulator: float = 0.0
var _advancing: bool = false


func set_time_scale(value: Variant) -> bool:
	if typeof(value) != TYPE_INT or not SCALES.has(value):
		return false
	_time_scale = value
	return true


func advance(real_delta: float) -> bool:
	if _advancing or not is_finite(real_delta) or real_delta < 0.0:
		return false
	var added: float = real_delta * _time_scale
	if not is_finite(added) or not is_finite(_accumulator + added):
		return false
	if paused or real_delta == 0.0:
		return true
	_advancing = true
	_accumulator += added
	var emitted: int = 0
	# Retain backlog when limiting catch-up; never silently discard simulated time.
	while _accumulator >= TICK_INTERVAL and emitted < MAX_TICKS_PER_ADVANCE and not paused:
		_accumulator -= TICK_INTERVAL
		_tick_count += 1
		emitted += 1
		tick.emit(TICK_INTERVAL)
	_advancing = false
	return true


func reset() -> bool:
	if _advancing:
		return false
	paused = false
	_time_scale = 1
	_tick_count = 0
	_accumulator = 0.0
	return true


func to_dict() -> Dictionary:
	return {"ticks": str(_tick_count), "time": simulation_time, "remainder": _accumulator,
		"paused": paused, "scale": _time_scale, "interval": TICK_INTERVAL}


func restore(data: Dictionary) -> bool:
	if _advancing or not data.has_all(["ticks", "time", "remainder", "paused", "scale", "interval"]):
		return false
	if not data.ticks is String or not data.ticks.is_valid_int():
		return false
	var count: int = data.ticks.to_int()
	if count < 0 or str(count) != data.ticks or typeof(data.paused) != TYPE_BOOL:
		return false
	for field: String in ["time", "remainder", "scale", "interval"]:
		if not (typeof(data[field]) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(data[field])):
			return false
	if data.time != count * TICK_INTERVAL or data.remainder < 0.0 or data.interval != TICK_INTERVAL:
		return false
	if not SCALES.has(int(data.scale)) or float(data.scale) != int(data.scale):
		return false
	_tick_count = count
	_accumulator = float(data.remainder)
	_time_scale = int(data.scale)
	paused = data.paused
	return true
