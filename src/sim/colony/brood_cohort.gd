class_name BroodCohort
extends RefCounted
## One aggregate immature cohort; never part of the living-worker ledger.

const CONFIG = preload("res://data/resources/default_brood.tres")
var id: String = "brood_1"
var stage: String = "egg"
var count: int = CONFIG.starting_count
var progress_seconds: float = 0.0
var nutrition: float = 1.0
var care: float = 1.0


static func next_id(matured_total: int, active_count: int = 0) -> String:
	return "brood_%d" % (matured_total / CONFIG.starting_count + active_count + 1)


func to_dict() -> Dictionary:
	return {"id": id, "stage": stage, "count": count, "progress_seconds": progress_seconds,
		"nutrition": nutrition, "care": care}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["id", "stage", "count", "progress_seconds", "nutrition", "care"]):
		return false
	if not data.id is String or not data.id.begins_with("brood_") or not data.stage in ["egg", "larva", "pupa"] or not WorkerLedger.valid_count(data.count) or data.count != CONFIG.starting_count:
		return false
	for key: String in ["progress_seconds", "nutrition", "care"]:
		if not typeof(data[key]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])) or data[key] < 0.0:
			return false
	if data.progress_seconds >= CONFIG.stage_seconds(data.stage) or data.nutrition > 1.0 or data.care > 1.0:
		return false
	id = data.id
	stage = data.stage
	count = int(data.count)
	progress_seconds = float(data.progress_seconds)
	nutrition = float(data.nutrition)
	care = float(data.care)
	return true
