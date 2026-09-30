class_name PileState
extends RefCounted

const Ledger = preload("res://src/sim/colony/worker_ledger.gd")
const Brood = preload("res://src/sim/colony/brood_cohort.gd")
const BROOD_CONFIG = preload("res://data/resources/default_brood.tres")
const RESOURCE_IDS: Array[String] = ["carbohydrate", "protein", "water"]
var id: String = "home"
var position: Vector2 = Vector2(20, 20)
var queen_count: int = 1
var workers: WorkerLedger = Ledger.new()
var resources: Dictionary[String, float] = {"carbohydrate": 0.0, "protein": 0.0, "water": 0.0}
var brood_cohorts: Array[BroodCohort] = []
var brood_matured_total: int = 0
var workers_total: int:
	get: return workers.total
var workers_available: int:
	get: return workers.available


func to_dict() -> Dictionary:
	var brood_records: Array[Dictionary] = []
	for cohort: BroodCohort in brood_cohorts:
		brood_records.append(cohort.to_dict())
	return {"id": id, "position": [position.x, position.y], "queen_count": queen_count,
		"workers": workers.to_dict(), "resources": resources.duplicate(),
		"brood_cohorts": brood_records, "brood_matured_total": brood_matured_total}


func deposit_resource(resource_id: String, amount: float) -> bool:
	if not resources.has(resource_id) or not is_finite(amount) or amount < 0.0 or not is_finite(resources[resource_id] + amount):
		return false
	resources[resource_id] += amount
	return true


func consume_resources(costs: Dictionary) -> bool:
	for resource_id: String in costs:
		var amount: Variant = costs[resource_id]
		if not resources.has(resource_id) or not typeof(amount) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(amount)) or amount < 0.0 or resources[resource_id] < amount:
			return false
	for resource_id: String in costs:
		# Authored brood costs are millesimal; quantize each debit to avoid
		# accumulated binary drift across full-precision JSON continuations.
		resources[resource_id] = maxf(0.0, roundf((resources[resource_id] - float(costs[resource_id])) * 1000.0) / 1000.0)
	return true


func restore(data: Dictionary) -> bool:
	if not data.has_all(["id", "position", "queen_count", "workers", "resources", "brood_cohorts", "brood_matured_total"]) or not data.id is String or data.id.is_empty() or not Ledger.valid_count(data.queen_count):
		return false
	if not data.position is Array or data.position.size() != 2 or not data.workers is Dictionary:
		return false
	for value: Variant in data.position:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	var restored := Ledger.new()
	if not restored.restore(data.workers):
		return false
	if not data.resources is Dictionary or data.resources.size() != RESOURCE_IDS.size():
		return false
	var restored_resources: Dictionary[String, float] = {}
	for resource_id: String in RESOURCE_IDS:
		if not data.resources.has(resource_id) or not typeof(data.resources[resource_id]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.resources[resource_id])) or data.resources[resource_id] < 0.0:
			return false
		restored_resources[resource_id] = float(data.resources[resource_id])
	if not data.brood_cohorts is Array or data.brood_cohorts.size() > 1 or not Ledger.valid_count(data.brood_matured_total):
		return false
	var restored_brood: Array[BroodCohort] = []
	for record: Variant in data.brood_cohorts:
		var cohort := Brood.new()
		if not record is Dictionary or not cohort.restore(record):
			return false
		restored_brood.append(cohort)
	if (restored_brood.is_empty() and data.brood_matured_total != BROOD_CONFIG.starting_count) or (not restored_brood.is_empty() and data.brood_matured_total != 0):
		return false
	id = data.id
	position = Vector2(data.position[0], data.position[1])
	queen_count = int(data.queen_count)
	workers = restored
	resources = restored_resources
	brood_cohorts = restored_brood
	brood_matured_total = int(data.brood_matured_total)
	return true
