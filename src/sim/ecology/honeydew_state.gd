class_name HoneydewState
extends RefCounted
## One backyard producer relationship; source quantity remains in WorldState.

const CONFIG = preload("res://data/ecology/backyard_honeydew.tres")
const RELATIONSHIPS: Array[String] = ["unknown", "exploited", "tended"]

var relationship: String = "unknown"
var condition: float = CONFIG.initial_condition
var protection_workers: int = 0


func to_dict() -> Dictionary:
	return {"relationship": relationship, "condition": condition, "protection_workers": protection_workers}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["relationship", "condition", "protection_workers"]) or not data.relationship is String or not RELATIONSHIPS.has(data.relationship):
		return false
	if not typeof(data.condition) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.condition)) or float(data.condition) < CONFIG.minimum_condition or float(data.condition) > 100.0:
		return false
	if not WorkerLedger.valid_count(data.protection_workers) or int(data.protection_workers) != (CONFIG.protection_workers if data.relationship == "tended" else 0):
		return false
	relationship = data.relationship
	condition = float(data.condition)
	protection_workers = int(data.protection_workers)
	return true
