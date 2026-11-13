class_name HumidityState
extends RefCounted
const CONFIG = preload("res://data/resources/default_humidity.tres")
var moisture: int = CONFIG.starting
var carers: int = 0
var water_used_units: int = 0

func larval_rate() -> float:
	if moisture < CONFIG.extreme_low or moisture > CONFIG.extreme_high:
		return CONFIG.extreme_rate
	return CONFIG.strained_rate if moisture < CONFIG.favorable_low or moisture > CONFIG.favorable_high else 1.0

func to_dict() -> Dictionary:
	return {"moisture": moisture, "carers": carers, "water_used_units": water_used_units}

func restore(data: Dictionary, ledger: WorkerLedger, pile_id: String, nursery: String) -> bool:
	if not data.has_all(["moisture", "carers", "water_used_units"]):
		return false
	for field: String in ["moisture", "carers", "water_used_units"]:
		if not WorkerLedger.valid_count(data[field]):
			return false
	if data.moisture > 1000000 or data.carers > CONFIG.care_cap or nursery != "developed" and (data.carers > 0 or data.moisture != CONFIG.starting or data.water_used_units > 0):
		return false
	var record: Dictionary = ledger.to_dict().commitments.get("humidity:" + pile_id, {})
	if data.carers == 0 and not record.is_empty() or data.carers > 0 and record != {"kind": "internal", "owner_id": pile_id, "count": int(data.carers)}:
		return false
	moisture = int(data.moisture)
	carers = int(data.carers)
	water_used_units = int(data.water_used_units)
	return true
