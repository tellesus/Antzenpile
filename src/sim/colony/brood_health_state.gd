class_name BroodHealthState
extends RefCounted
## Aggregate local health; presentation receives symptoms, never this private burden.
const CONFIG = preload("res://data/resources/default_brood_health.tres")
var burden: int = 0
var severe_ticks: int = 0
var losses: int = 0
var last_loss_tick: int = 0

func larval_rate() -> float:
	return CONFIG.severe_rate if burden >= CONFIG.severe_threshold else CONFIG.strained_rate if burden >= CONFIG.symptom_threshold else 1.0

func to_dict() -> Dictionary:
	return {"burden": burden, "severe_ticks": severe_ticks, "losses": losses, "last_loss_tick": last_loss_tick}

func restore(data: Dictionary, brood_losses: int) -> bool:
	if data.size() != 4 or not data.has_all(["burden", "severe_ticks", "losses", "last_loss_tick"]): return false
	for key: String in data:
		if not WorkerLedger.valid_count(data[key]): return false
	if data.burden > CONFIG.maximum or data.severe_ticks >= CONFIG.loss_ticks or data.losses > brood_losses: return false
	if data.burden < CONFIG.severe_threshold and data.severe_ticks != 0 or ((data.losses == 0) != (data.last_loss_tick == 0)): return false
	burden = int(data.burden)
	severe_ticks = int(data.severe_ticks)
	losses = int(data.losses)
	last_loss_tick = int(data.last_loss_tick)
	return true
