class_name FoodToxicityState
extends RefCounted
## Hidden liquid-pool chemistry plus locally observed failures; no source attribution.
const CONFIG = preload("res://data/resources/default_food_toxicity.tres")

var mass: float = 0.0
var dose_units: int = 0
var losses: int = 0
var last_loss_tick: int = 0

func to_dict() -> Dictionary:
	return {"mass":mass,"dose_units":dose_units,"losses":losses,"last_loss_tick":last_loss_tick}

func restore(data: Dictionary, carbohydrate: float, lost_workers: int) -> bool:
	if not data.has_all(["mass","dose_units","losses","last_loss_tick"]): return false
	if not typeof(data.mass) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.mass)) or data.mass < 0 or data.mass > carbohydrate: return false
	for key: String in ["dose_units","losses","last_loss_tick"]:
		if not WorkerLedger.valid_count(data[key]): return false
	if data.dose_units > CONFIG.dose_threshold_units or data.losses > lost_workers or ((data.losses == 0) != (data.last_loss_tick == 0)): return false
	mass = float(data.mass); dose_units = int(data.dose_units); losses = int(data.losses); last_loss_tick = int(data.last_loss_tick)
	return true
