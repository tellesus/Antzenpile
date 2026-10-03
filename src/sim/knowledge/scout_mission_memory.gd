class_name ScoutMissionMemory
extends RefCounted
## Departure facts known at home; coarse course is delivered only on return.

const MAX_COURSE: int = 8
const RECENT_RETURNS: int = 16
var id: String
var origin_pile: String
var bearing: float
var departed_at: float
var scent: float = 1.0
var returned_at: float = -1.0
var course: Array[Dictionary] = []
var expected_at: float = -1.0
var missing_at: float = -1.0


func completed_at() -> float:
	return maxf(returned_at, missing_at)


func to_dict() -> Dictionary:
	return {"id": id, "origin_pile": origin_pile, "bearing": bearing,
		"departed_at": departed_at, "scent": scent, "returned_at": returned_at,
		"course": course.duplicate(true), "expected_at": expected_at, "missing_at": missing_at}


func restore(data: Dictionary, colony: ColonyState, scouts: Dictionary, next_id: int, time: float) -> bool:
	if not data.has_all(["id", "origin_pile", "bearing", "departed_at", "scent", "returned_at", "course"]):
		return false
	if not data.id is String or not data.id.begins_with("scout_") or not data.origin_pile is String or not colony.piles.has(data.origin_pile):
		return false
	var suffix: String = data.id.trim_prefix("scout_")
	if not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= next_id:
		return false
	for field: String in ["bearing", "departed_at", "scent", "returned_at"]:
		if not typeof(data[field]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[field])):
			return false
	if data.bearing < 0.0 or data.bearing >= TAU or data.departed_at < 0.0 or data.departed_at > time or data.scent < 0.0 or data.scent > 1.0:
		return false
	if data.returned_at != -1.0 and (data.returned_at < data.departed_at or data.returned_at > time):
		return false
	var expected: Variant = data.get("expected_at", -1.0)
	var missing: Variant = data.get("missing_at", -1.0)
	for value: Variant in [expected, missing]:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	if expected != -1.0 and (expected <= data.departed_at or expected > WorkerLedger.MAX_COUNT * SimulationClock.TICK_INTERVAL):
		return false
	if missing != -1.0 and (expected < 0.0 or missing < expected or missing > time or data.returned_at != -1.0):
		return false
	if (data.returned_at == -1.0 and missing == -1.0) != scouts.has(data.id) or (scouts.has(data.id) and scouts[data.id].origin_pile != data.origin_pile):
		return false
	if scouts.has(data.id) and expected >= 0.0:
		var deadline: float = scouts[data.id].expected_tick * SimulationClock.TICK_INTERVAL
		if deadline < expected or (not scouts[data.id].lost and not is_equal_approx(expected, deadline)):
			return false
	if not data.course is Array or data.course.size() > MAX_COURSE or (data.returned_at == -1.0 and not data.course.is_empty()):
		return false
	for sample: Variant in data.course:
		if not sample is Dictionary or not sample.has_all(["bearing", "estimated_distance"]):
			return false
		for field: String in ["bearing", "estimated_distance"]:
			if not typeof(sample[field]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(sample[field])):
				return false
		if sample.bearing < 0.0 or sample.bearing >= TAU or sample.estimated_distance < 0.0 or sample.estimated_distance > 100.0:
			return false
	id = data.id
	origin_pile = data.origin_pile
	bearing = float(data.bearing)
	departed_at = float(data.departed_at)
	scent = float(data.scent)
	returned_at = float(data.returned_at)
	expected_at = float(expected)
	missing_at = float(missing)
	for sample: Dictionary in data.course:
		course.append(sample.duplicate(true))
	return true
