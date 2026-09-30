class_name PileState
extends RefCounted

const Ledger = preload("res://src/sim/colony/worker_ledger.gd")
const RESOURCE_IDS: Array[String] = ["carbohydrate", "protein", "water"]
var id: String = "home"
var position: Vector2 = Vector2(20, 20)
var queen_count: int = 1
var workers: WorkerLedger = Ledger.new()
var resources: Dictionary[String, float] = {"carbohydrate": 0.0, "protein": 0.0, "water": 0.0}
var workers_total: int:
	get: return workers.total
var workers_available: int:
	get: return workers.available


func to_dict() -> Dictionary:
	return {"id": id, "position": [position.x, position.y], "queen_count": queen_count,
		"workers": workers.to_dict(), "resources": resources.duplicate()}


func deposit_resource(resource_id: String, amount: float) -> bool:
	if not resources.has(resource_id) or not is_finite(amount) or amount < 0.0 or not is_finite(resources[resource_id] + amount):
		return false
	resources[resource_id] += amount
	return true


func restore(data: Dictionary) -> bool:
	if not data.has_all(["id", "position", "queen_count", "workers", "resources"]) or not data.id is String or data.id.is_empty() or not Ledger.valid_count(data.queen_count):
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
	id = data.id
	position = Vector2(data.position[0], data.position[1])
	queen_count = int(data.queen_count)
	workers = restored
	resources = restored_resources
	return true
