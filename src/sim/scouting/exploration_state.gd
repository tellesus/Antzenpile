class_name ExplorationState
extends RefCounted
## Home colony's standing intent; active workers remain in individual ledger commitments.

const CONFIG = preload("res://data/scouting/default_scouts.tres")
var target: int = 0
var bias: Variant = null
var cooldown_ticks: int = 0
var coverage: Dictionary[String, float] = {}
var priorities: Array[String] = []
var priority_cursor: int = 0
var investigation_turn: bool = false
var priority_last_sent: Dictionary[String, float] = {}


func to_dict() -> Dictionary:
	return {"target": target, "bias": bias, "cooldown_ticks": cooldown_ticks,
		"coverage": coverage.duplicate(), "priorities": priorities.duplicate(), "priority_cursor": priority_cursor,
		"investigation_turn": investigation_turn, "priority_last_sent": priority_last_sent.duplicate()}


func restore(data: Dictionary, world: WorldState, time: float) -> bool:
	if not data.has_all(["target", "bias", "cooldown_ticks"]) or not WorkerLedger.valid_count(data.target) or data.target > CONFIG.active_cap or not WorkerLedger.valid_count(data.cooldown_ticks) or data.cooldown_ticks > CONFIG.departure_interval_ticks:
		return false
	if data.bias != null and (not typeof(data.bias) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.bias)) or data.bias < 0 or data.bias >= TAU):
		return false
	var searched: Variant = data.get("coverage", {})
	var queued: Variant = data.get("priorities", [])
	var cursor: Variant = data.get("priority_cursor", 0)
	var turn: Variant = data.get("investigation_turn", false)
	var sent: Variant = data.get("priority_last_sent", {})
	if not searched is Dictionary or not queued is Array or queued.size() > CONFIG.active_cap or not WorkerLedger.valid_count(cursor) or cursor >= maxi(1, queued.size()) or not turn is bool or not sent is Dictionary:
		return false
	var restored_coverage: Dictionary[String, float] = {}
	for key: Variant in searched:
		if not key is String or not typeof(searched[key]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(searched[key])) or searched[key] < 0 or searched[key] > 1:
			return false
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2:
			return false
		for index: int in 2:
			if not parts[index].is_valid_int() or str(parts[index].to_int()) != parts[index] or parts[index].to_int() < 0 or parts[index].to_int() >= ceili(world.bounds.size[index] / CONFIG.coverage_cell_size):
				return false
		restored_coverage[key] = roundf(float(searched[key]) * 1e10) / 1e10
	var restored_priorities: Array[String] = []
	var restored_sent: Dictionary[String, float] = {}
	for key: Variant in queued:
		if not key is String or key in restored_priorities:
			return false
		restored_priorities.append(key)
	for key: Variant in sent:
		if key not in restored_priorities or not typeof(sent[key]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(sent[key])) or sent[key] < 0 or sent[key] > time:
			return false
		restored_sent[key] = float(sent[key])
	target = int(data.target)
	bias = null if data.bias == null else float(data.bias)
	cooldown_ticks = int(data.cooldown_ticks)
	coverage = restored_coverage
	priorities = restored_priorities
	priority_cursor = int(cursor)
	investigation_turn = turn
	priority_last_sent = restored_sent
	return true


func cell_key(point: Vector2, bounds: Rect2) -> String:
	var cell: Vector2 = (point - bounds.position) / CONFIG.coverage_cell_size
	return "%d:%d" % [floori(cell.x), floori(cell.y)]


func decay(delta: float, raining: bool) -> void:
	var half_life: float = CONFIG.rain_coverage_half_life if raining else CONFIG.coverage_half_life
	for key: String in coverage.keys():
		coverage[key] = roundf(coverage[key] * pow(0.5, delta / half_life) * 1e10) / 1e10
		if coverage[key] < 0.0001:
			coverage.erase(key)


func record_return(points: Array[Vector2], bounds: Rect2) -> void:
	for point: Vector2 in points:
		coverage[cell_key(point, bounds)] = 1.0
