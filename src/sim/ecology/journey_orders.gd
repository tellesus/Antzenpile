class_name JourneyOrders
extends RefCounted
## Colony-known budgets for one attempt, not remote force estimates.
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
var targets: Dictionary[String, int] = {}
var goals: Dictionary[String, String] = {}
var recruitment: Dictionary = {}

static func valid_target(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= WorkerLedger.MAX_COUNT

func restore(data: Variant, trails: TrailNetwork) -> bool:
	if not data is Dictionary: return false
	var restored: Dictionary[String, int] = {}
	for id: Variant in data:
		if not id is String or not trails.routes.has(id) or trails.routes[id].purpose != "food" or not WorkerLedger.valid_count(data[id]) or not valid_target(int(data[id])): return false
		restored[id] = int(data[id])
	targets = restored
	return true

func restore_recruitment(data: Variant, colony: ColonyState, trails: TrailNetwork) -> bool:
	if not data is Dictionary: return false
	var restored: Dictionary = {}
	for id: Variant in data:
		if not id is String or not trails.routes.has(id) or trails.routes[id].purpose != "food": return false
		var entry: Variant = data[id]
		if not entry is Dictionary or entry.size() != 5 or not entry.has_all(["count","kind","all_hands","waiting","trail_target"]): return false
		if not WorkerLedger.valid_count(entry.count) or entry.count < 1 or entry.kind not in ["defend","gather"] or not entry.all_hands is bool or not entry.waiting is Dictionary or not WorkerLedger.valid_count(entry.trail_target): return false
		if entry.kind == "defend" and (targets.get(id, 0) == 0 or entry.trail_target != 0): return false
		if entry.kind == "gather" and entry.trail_target < entry.count: return false
		var origin: String = trails.routes[id].origin_pile
		var commitment: Dictionary = colony.piles[origin].workers.to_dict().commitments.get("response:" + id, {})
		if commitment.get("kind") != "other" or commitment.get("owner_id") != id or commitment.get("count", -1) < 0 or commitment.count > entry.count: return false
		var waiting: Dictionary = {}
		for route_id: Variant in entry.waiting:
			if not route_id is String or not trails.routes.has(route_id) or trails.routes[route_id].origin_pile != origin or trails.routes[route_id].purpose != "food" or not WorkerLedger.valid_count(entry.waiting[route_id]): return false
			waiting[route_id] = int(entry.waiting[route_id])
		restored[id] = {"count":int(entry.count),"kind":entry.kind,"all_hands":entry.all_hands,"waiting":waiting,"trail_target":int(entry.trail_target)}
	for pile: PileState in colony.piles.values():
		for id: String in pile.workers.to_dict().commitments:
			if id.begins_with("response:") and (not restored.has(id.trim_prefix("response:")) or trails.routes[id.trim_prefix("response:")].origin_pile != pile.id): return false
	recruitment = restored
	return true
