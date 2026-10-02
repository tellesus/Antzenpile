class_name ExplorationState
extends RefCounted
## Home colony's standing intent; active workers remain in individual ledger commitments.

const CONFIG = preload("res://data/scouting/default_scouts.tres")
var target: int = 0
var bias: Variant = null
var cooldown_ticks: int = 0


func to_dict() -> Dictionary:
	return {"target": target, "bias": bias, "cooldown_ticks": cooldown_ticks}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["target", "bias", "cooldown_ticks"]) or not WorkerLedger.valid_count(data.target) or data.target > CONFIG.active_cap or not WorkerLedger.valid_count(data.cooldown_ticks) or data.cooldown_ticks > CONFIG.departure_interval_ticks:
		return false
	if data.bias != null and (not typeof(data.bias) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.bias)) or data.bias < 0 or data.bias >= TAU):
		return false
	target = int(data.target)
	bias = null if data.bias == null else float(data.bias)
	cooldown_ticks = int(data.cooldown_ticks)
	return true
