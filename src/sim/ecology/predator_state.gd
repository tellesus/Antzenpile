class_name PredatorState
extends RefCounted

const CONFIG = preload("res://data/ecology/backyard_predator.tres")
var last_attack_tick: int = -1
var kills_total: int = 0
const RESPONSE = preload("res://data/ecology/default_journey_response.tres")
var resistance: int = RESPONSE.resistance
var defeated_at: float = 0
var defense_losses: int = 0
var health: int = RESPONSE.hunt_health
var killed: bool = false


func to_dict() -> Dictionary:
	return {"last_attack_tick": str(last_attack_tick), "kills_total": kills_total,
		"defense": {"resistance":resistance,"defeated_at":defeated_at,"losses":defense_losses,"health":health,"killed":killed}}


func restore(data: Dictionary, tick: int) -> bool:
	if not data.has_all(["last_attack_tick", "kills_total"]) or not data.last_attack_tick is String or not data.last_attack_tick.is_valid_int() or str(data.last_attack_tick.to_int()) != data.last_attack_tick or not WorkerLedger.valid_count(data.kills_total):
		return false
	var last: int = data.last_attack_tick.to_int()
	if data.kills_total == 0:
		if last != -1:
			return false
	elif last < CONFIG.first_tick or last > tick or data.kills_total > 1 + (last - CONFIG.first_tick) / CONFIG.recovery_ticks:
		return false
	var extra: Variant = data.get("defense",{"resistance":RESPONSE.resistance,"defeated_at":0.0,"losses":0})
	if not extra is Dictionary or extra.size() not in [3,5] or not extra.has_all(["resistance","defeated_at","losses"]): return false
	var restored_health: Variant = extra.get("health", RESPONSE.hunt_health)
	var restored_killed: Variant = extra.get("killed", false)
	if not WorkerLedger.valid_count(restored_health) or restored_health > RESPONSE.hunt_health or not restored_killed is bool or restored_killed != (restored_health == 0) or restored_killed and (extra.resistance != 0 or extra.defeated_at <= 0): return false
	if not WorkerLedger.valid_count(extra.resistance) or extra.resistance > RESPONSE.resistance or not WorkerLedger.valid_count(extra.losses): return false
	if not typeof(extra.defeated_at) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(extra.defeated_at)) or extra.defeated_at < 0 or extra.defeated_at > tick * SimulationClock.TICK_INTERVAL: return false
	if extra.defeated_at > 0 and (extra.resistance != 0 or extra.defeated_at < CONFIG.first_tick * SimulationClock.TICK_INTERVAL): return false
	if extra.losses > tick / RESPONSE.round_ticks or (extra.resistance < RESPONSE.resistance and tick < CONFIG.first_tick): return false
	if extra.defeated_at > 0 and last * SimulationClock.TICK_INTERVAL > extra.defeated_at: return false
	resistance = int(extra.resistance); defeated_at = float(extra.defeated_at); defense_losses = int(extra.losses)
	health = int(restored_health); killed = restored_killed
	last_attack_tick = last
	kills_total = int(data.kills_total)
	return true
