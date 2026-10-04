class_name JourneyOrders
extends RefCounted
## Colony-known budgets for one attempt, not remote force estimates.
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
var targets: Dictionary[String, int] = {}

static func valid_target(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and (value == 0 or value >= CONFIG.defense_workers and value <= CONFIG.dispatched_cap and (value - CONFIG.defense_workers) % CONFIG.reinforcement_workers == 0)

func restore(data: Variant, trails: TrailNetwork) -> bool:
	if not data is Dictionary: return false
	var restored: Dictionary[String, int] = {}
	for id: Variant in data:
		if not id is String or not trails.routes.has(id) or trails.routes[id].purpose != "food" or not WorkerLedger.valid_count(data[id]) or not valid_target(int(data[id])): return false
		restored[id] = int(data[id])
	targets = restored
	return true
