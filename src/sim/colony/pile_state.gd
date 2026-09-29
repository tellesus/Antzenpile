class_name PileState
extends RefCounted

const Ledger = preload("res://src/sim/colony/worker_ledger.gd")
var id: String = "home"
var position: Vector2 = Vector2(20, 20)
var queen_count: int = 1
var workers: WorkerLedger = Ledger.new()
var workers_total: int:
	get: return workers.total
var workers_available: int:
	get: return workers.available


func to_dict() -> Dictionary:
	return {"id": id, "position": [position.x, position.y], "queen_count": queen_count, "workers": workers.to_dict()}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["id", "position", "queen_count", "workers"]) or not data.id is String or data.id.is_empty() or not Ledger.valid_count(data.queen_count):
		return false
	if not data.position is Array or data.position.size() != 2 or not data.workers is Dictionary:
		return false
	for value: Variant in data.position:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	var restored := Ledger.new()
	if not restored.restore(data.workers):
		return false
	id = data.id
	position = Vector2(data.position[0], data.position[1])
	queen_count = int(data.queen_count)
	workers = restored
	return true
