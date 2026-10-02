class_name BroodCohort
extends RefCounted
## One aggregate immature cohort; never part of the living-worker ledger.

const CONFIG = preload("res://data/resources/default_brood.tres")
var id: String = "brood_1"
var stage: String = "egg"
var count: int = CONFIG.starting_count
var lost_count: int = 0
var progress_seconds: float = 0.0
var nutrition: float = 1.0
var care: float = 1.0
var adaptation_id: String = ""
var adaptation_trial: bool = false
var inherited_traits: Array[String] = []


static func next_id(matured_total: int, active_count: int = 0) -> String:
	return "brood_%d" % (matured_total / CONFIG.starting_count + active_count + 1)


func to_dict() -> Dictionary:
	return {"id": id, "stage": stage, "count": count, "lost_count": lost_count, "progress_seconds": progress_seconds,
		"nutrition": nutrition, "care": care,
		"adaptation_id": adaptation_id, "adaptation_trial": adaptation_trial,
		"inherited_traits": inherited_traits.duplicate()}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["id", "stage", "count", "progress_seconds", "nutrition", "care"]):
		return false
	var lost: Variant = data.get("lost_count", 0)
	if not data.id is String or not data.id.begins_with("brood_") or not data.stage in ["egg", "larva", "pupa"] or not WorkerLedger.valid_count(data.count) or not WorkerLedger.valid_count(lost) or data.count < 1 or data.count + lost != CONFIG.starting_count:
		return false
	for key: String in ["progress_seconds", "nutrition", "care"]:
		if not typeof(data[key]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])) or data[key] < 0.0:
			return false
	if data.progress_seconds >= CONFIG.stage_seconds(data.stage) or data.nutrition > 1.0 or data.care > 1.0:
		return false
	var trait_id: Variant = data.get("adaptation_id", "")
	var trial: Variant = data.get("adaptation_trial", false)
	if not trait_id is String or not (trait_id == "" or AdaptationRules.valid_trait(trait_id)) or typeof(trial) != TYPE_BOOL or (trial and trait_id == ""):
		return false
	var traits: Variant = data.get("inherited_traits", [] if trait_id == "" else [trait_id])
	if not traits is Array:
		return false
	var parsed_traits: Array[String] = []
	for value: Variant in traits:
		if not value is String or not AdaptationRules.valid_trait(value) or value in parsed_traits:
			return false
		parsed_traits.append(value)
	if ("lean" in parsed_traits and "load" in parsed_traits) or (trait_id != "" and trait_id not in parsed_traits):
		return false
	id = data.id
	stage = data.stage
	count = int(data.count)
	lost_count = int(lost)
	progress_seconds = float(data.progress_seconds)
	nutrition = float(data.nutrition)
	care = float(data.care)
	adaptation_id = trait_id
	adaptation_trial = trial
	inherited_traits = parsed_traits
	return true
