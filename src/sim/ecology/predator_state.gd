class_name PredatorState
extends RefCounted

const CONFIG = preload("res://data/ecology/backyard_predator.tres")
var last_attack_tick: int = -1
var kills_total: int = 0


func to_dict() -> Dictionary:
	return {"last_attack_tick": str(last_attack_tick), "kills_total": kills_total}


func restore(data: Dictionary, tick: int) -> bool:
	if not data.has_all(["last_attack_tick", "kills_total"]) or not data.last_attack_tick is String or not data.last_attack_tick.is_valid_int() or str(data.last_attack_tick.to_int()) != data.last_attack_tick or not WorkerLedger.valid_count(data.kills_total):
		return false
	var last: int = data.last_attack_tick.to_int()
	if data.kills_total == 0:
		if last != -1:
			return false
	elif last < CONFIG.first_tick or last > tick or data.kills_total > 1 + (last - CONFIG.first_tick) / CONFIG.recovery_ticks:
		return false
	last_attack_tick = last
	kills_total = int(data.kills_total)
	return true
