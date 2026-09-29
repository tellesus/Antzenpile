class_name WorkerLedger
extends RefCounted
## Only authority for living workers. Commitments remain until their owner reports returns.

const MAX_COUNT: int = 9007199254740991 # Largest exact JSON integer.
const KINDS: Array[String] = ["internal", "scout", "trail", "other"]
var total: int:
	get: return _total
var available: int:
	get: return _available
var last_error: String = ""
var _total: int = 0
var _available: int = 0
var _commitments: Dictionary = {}
var _population_reason: String = ""


func create_commitment(id: String, kind: String, owner_id: String) -> bool:
	if id.is_empty() or id == "available" or _commitments.has(id) or not KINDS.has(kind) or owner_id.is_empty():
		return _reject("Invalid or duplicate commitment/owner")
	_commitments[id] = {"kind": kind, "owner_id": owner_id, "count": 0}
	return _success()


func count(pool: String) -> int:
	if pool == "available":
		return _available
	return int(_commitments[pool].count) if _commitments.has(pool) else -1


func retire_commitment(id: String) -> bool:
	if not _commitments.has(id) or count(id) != 0:
		return _reject("Only an empty known commitment can be retired")
	_commitments.erase(id)
	return _success()


func allocate(commitment: String, amount: Variant) -> bool:
	return transfer("available", commitment, amount)


func release(commitment: String, amount: Variant) -> bool:
	return transfer(commitment, "available", amount)


func transfer(source: String, destination: String, amount: Variant) -> bool:
	if not valid_count(amount) or count(source) < 0 or count(destination) < 0:
		return _reject("Unknown pool or invalid worker count")
	var value: int = int(amount)
	if count(source) < value:
		return _reject("Insufficient workers")
	if value > 0 and source != destination:
		_set_count(source, count(source) - value)
		_set_count(destination, count(destination) + value)
	return _success()


func add_living_workers(pool: String, amount: Variant, reason: String) -> bool:
	if not valid_count(amount) or count(pool) < 0 or reason.strip_edges().is_empty():
		return _reject("Population change requires known pool, integer count, and reason")
	var value: int = int(amount)
	if value > MAX_COUNT - _total:
		return _reject("Population exceeds exact snapshot range")
	if value > 0:
		_total += value
		_set_count(pool, count(pool) + value)
		_population_reason = reason
	return _success()


func remove_living_workers(pool: String, amount: Variant, reason: String) -> bool:
	if not valid_count(amount) or count(pool) < 0 or reason.strip_edges().is_empty():
		return _reject("Population change requires known pool, integer count, and reason")
	var value: int = int(amount)
	if count(pool) < value:
		return _reject("Cannot remove more workers than the pool contains")
	if value > 0:
		_total -= value
		_set_count(pool, count(pool) - value)
		_population_reason = reason
	return _success()


func invariant_holds() -> bool:
	var sum: int = _available
	if not valid_count(_total) or not valid_count(_available):
		return false
	for entry: Dictionary in _commitments.values():
		if not valid_count(entry.count) or int(entry.count) > MAX_COUNT - sum:
			return false
		sum += int(entry.count)
	return sum == _total


func to_dict() -> Dictionary:
	return {"total": _total, "available": _available,
		"commitments": _commitments.duplicate(true), "population_reason": _population_reason}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["total", "available", "commitments", "population_reason"]) or not valid_count(data.total) or not valid_count(data.available) or not data.commitments is Dictionary or not data.population_reason is String:
		return _reject("Malformed ledger snapshot")
	var entries: Dictionary = {}
	var sum: int = int(data.available)
	for id: Variant in data.commitments:
		var entry: Variant = data.commitments[id]
		if not id is String or id.is_empty() or id == "available" or not entry is Dictionary or not entry.has_all(["kind", "owner_id", "count"]):
			return _reject("Malformed commitment")
		if not entry.kind is String or not KINDS.has(entry.kind) or not entry.owner_id is String or entry.owner_id.is_empty() or not valid_count(entry.count):
			return _reject("Invalid commitment fields")
		if int(entry.count) > MAX_COUNT - sum:
			return _reject("Population exceeds exact snapshot range")
		sum += int(entry.count)
		entries[id] = {"kind": entry.kind, "owner_id": entry.owner_id, "count": int(entry.count)}
	if sum != int(data.total):
		return _reject("Worker conservation failed")
	_total = int(data.total)
	_available = int(data.available)
	_commitments = entries
	_population_reason = data.population_reason
	return _success()


static func valid_count(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= MAX_COUNT and float(value) == floor(float(value))


func _set_count(pool: String, value: int) -> void:
	if pool == "available":
		_available = value
	else:
		_commitments[pool].count = value


func _success() -> bool:
	assert(invariant_holds(), "Worker ledger conservation")
	last_error = ""
	return true


func _reject(reason: String) -> bool:
	last_error = reason
	return false
