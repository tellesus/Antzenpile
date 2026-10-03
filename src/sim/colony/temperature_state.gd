class_name TemperatureState
extends RefCounted
const CONFIG = preload("res://data/weather/default_heat.tres")
var temperature: int = CONFIG.baseline
var water_used_units: int = 0

func larval_rate() -> float:
	return CONFIG.severe_rate if temperature > CONFIG.extreme_high else CONFIG.strained_rate if temperature > CONFIG.favorable_high else 1.0

func to_dict() -> Dictionary:
	return {"temperature": temperature, "water_used_units": water_used_units}

func restore(data: Dictionary, nursery: String) -> bool:
	if data.size() != 2 or not data.has_all(["temperature", "water_used_units"]): return false
	if not WorkerLedger.valid_count(data.temperature) or not WorkerLedger.valid_count(data.water_used_units): return false
	if data.temperature < CONFIG.baseline - CONFIG.rain_cooling or data.temperature > CONFIG.peak: return false
	if nursery != "developed" and (data.temperature != CONFIG.baseline or data.water_used_units != 0): return false
	temperature = int(data.temperature)
	water_used_units = int(data.water_used_units)
	return true
