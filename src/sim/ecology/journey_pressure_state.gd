class_name JourneyPressureState
extends RefCounted
## Traveling messengers remain assigned as local liaisons after their return.
var messengers: int = 0
var remaining_ticks: int = 0
var travel_ticks: int = 0
var pending: Dictionary = {}
var reports: Dictionary = {}

func to_dict() -> Dictionary:
	return {"messengers": messengers, "remaining_ticks": remaining_ticks, "travel_ticks": travel_ticks, "pending": pending.duplicate(true), "reports": reports.duplicate(true)}

func reset_party() -> void:
	messengers = 0; remaining_ticks = 0; travel_ticks = 0; pending.clear()

func restore(data: Dictionary, party: Dictionary, defense: Dictionary, trails: TrailNetwork, time: float) -> bool:
	if data.size() != 5 or not data.has_all(to_dict().keys()) or not WorkerLedger.valid_count(data.messengers) or not WorkerLedger.valid_count(data.remaining_ticks) or not WorkerLedger.valid_count(data.travel_ticks) or not data.pending is Dictionary or not data.reports is Dictionary: return false
	if data.messengers > 3 or data.messengers >= party.workers and data.messengers > 0 or (data.remaining_ticks > 0) != (not data.pending.is_empty()): return false
	if (party.phase == "idle" or defense.mode != "defend") and (data.messengers != 0 or data.remaining_ticks != 0): return false
	if party.phase != "idle":
		if not trails.routes.has(party.route_id): return false
		var segment: TrailSegmentState = trails.segments[trails.routes[party.route_id].segment_id]
		if data.travel_ticks > TRAIL_CONFIG.leg_ticks(segment.length()): return false
	if not data.pending.is_empty():
		if not valid_report(data.pending, time, false) or data.pending.observed_at < party.departed_at or data.pending.acknowledged_sent > defense.sent or data.messengers == 0: return false
		if data.remaining_ticks + int(round((time - data.pending.observed_at) / SimulationClock.TICK_INTERVAL)) != data.travel_ticks: return false
	elif data.travel_ticks != 0: return false
	for id: Variant in data.reports:
		if not id is String or not trails.routes.has(id) or trails.routes[id].purpose != "food" or not valid_report(data.reports[id],time,true): return false
	messengers = int(data.messengers); remaining_ticks = int(data.remaining_ticks)
	travel_ticks = int(data.travel_ticks)
	pending = normalize(data.pending) if not data.pending.is_empty() else {}
	reports = {}
	for id: String in data.reports: reports[id] = normalize(data.reports[id])
	return true

const TRAIL_CONFIG = preload("res://data/trails/default_trails.tres")
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
static func valid_report(record: Variant, time: float, delivered: bool) -> bool:
	if not record is Dictionary or record.size() != (4 if delivered else 3) or not record.has_all(["pressure","observed_at","acknowledged_sent"]): return false
	if record.pressure not in ["holding","resisted"] or not WorkerLedger.valid_count(record.acknowledged_sent) or record.acknowledged_sent < CONFIG.defense_workers or record.acknowledged_sent > CONFIG.dispatched_cap or (int(record.acknowledged_sent)-CONFIG.defense_workers)%CONFIG.reinforcement_workers != 0: return false
	if not typeof(record.observed_at) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record.observed_at)) or record.observed_at <= 0 or record.observed_at > time: return false
	if delivered and (not record.has("received_at") or not typeof(record.received_at) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record.received_at)) or record.received_at < record.observed_at or record.received_at > time): return false
	return true

static func normalize(record: Dictionary) -> Dictionary:
	var result: Dictionary = {"pressure":record.pressure, "observed_at":float(record.observed_at), "acknowledged_sent":int(record.acknowledged_sent)}
	if record.has("received_at"): result.received_at = float(record.received_at)
	return result
