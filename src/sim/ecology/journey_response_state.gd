class_name JourneyResponseState
extends RefCounted
## One aggregate survey; delivered findings are distinct from private samples.
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
var route_id: String = ""
var phase: String = "idle"
var workers: int = 0
var elapsed_ticks: int = 0
var departed_at: float = 0
var ambush_fraction: float = -1
var foreign_seen: bool = false
var sampled_at: float = 0
var reports: Dictionary = {}
var defense: JourneyDefenseState = JourneyDefenseState.new()
var pressure: JourneyPressureState = JourneyPressureState.new()
var orders: JourneyOrders = JourneyOrders.new()

func active() -> bool: return phase != "idle"
func origin_id(trails: TrailNetwork) -> String:
	return trails.routes[route_id].origin_pile if active() and trails.routes.has(route_id) else ""
func to_dict() -> Dictionary:
	return {"route_id":route_id,"phase":phase,"workers":workers,"elapsed_ticks":elapsed_ticks,"departed_at":departed_at,
		"ambush_fraction":ambush_fraction,"foreign_seen":foreign_seen,"sampled_at":sampled_at,"reports":reports.duplicate(true),"defense":defense.to_dict(),"pressure":pressure.to_dict(),"orders":orders.targets.duplicate()}

func restore(data: Dictionary, colony: ColonyState, trails: TrailNetwork, time: float) -> bool:
	if not data.has_all(["route_id","phase","workers","elapsed_ticks","departed_at","ambush_fraction","foreign_seen","sampled_at","reports"]): return false
	if not data.route_id is String or not data.phase in ["idle","outbound","fighting","inbound"] or not WorkerLedger.valid_count(data.workers) or not WorkerLedger.valid_count(data.elapsed_ticks) or typeof(data.foreign_seen) != TYPE_BOOL or not data.reports is Dictionary: return false
	for key: String in ["departed_at","sampled_at","ambush_fraction"]:
		if not typeof(data[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])): return false
	if data.departed_at < 0 or data.departed_at > time or data.sampled_at < 0 or data.sampled_at > time or (data.ambush_fraction != -1 and (data.ambush_fraction < 0 or data.ambush_fraction > 1)): return false
	if (data.ambush_fraction >= 0 or data.foreign_seen) != (data.sampled_at > 0): return false
	for id: Variant in data.reports:
		var report: Variant = data.reports[id]
		if not id is String or not trails.routes.has(id) or not report is Dictionary or report.size() != 4 or not report.has_all(["finding","fraction","observed_at","received_at"]): return false
		if trails.routes[id].purpose != "food" or trails.routes[id].reported_losses <= 0: return false
		if report.finding not in ["ambush","foreign","mixed","inconclusive"]: return false
		for key: String in ["fraction","observed_at","received_at"]:
			if not typeof(report[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(report[key])): return false
		if report.observed_at < 0 or report.observed_at > report.received_at or report.received_at > time or report.received_at <= 0: return false
		if report.finding in ["ambush","mixed"]:
			if report.fraction < 0 or report.fraction > 1 or report.observed_at == 0: return false
		elif report.fraction != -1: return false
	var restored_defense := JourneyDefenseState.new()
	var legacy: Dictionary = restored_defense.to_dict(); legacy.sent = int(data.workers); legacy.initial_sent = int(data.workers)
	var defense_data: Variant = data.get("defense",legacy)
	if not defense_data is Dictionary or not restored_defense.restore(defense_data,data,colony,trails,time): return false
	var restored_pressure := JourneyPressureState.new()
	var pressure_data: Variant = data.get("pressure", restored_pressure.to_dict())
	if not pressure_data is Dictionary or not restored_pressure.restore(pressure_data,data,defense_data,trails,time): return false
	var origin: String = trails.routes[data.route_id].origin_pile if trails.routes.has(data.route_id) else ""
	var commitment: Dictionary = colony.piles[origin].workers.to_dict().commitments.get("journey:"+origin,{}) if origin != "" else {}
	for pile: PileState in colony.piles.values():
		for id: String in pile.workers.to_dict().commitments:
			if id.begins_with("journey:") and (data.phase == "idle" or pile.id != origin or id != "journey:"+origin): return false
	if data.phase == "idle":
		if data.route_id != "" or data.workers != 0 or data.elapsed_ticks != 0 or data.departed_at != 0 or data.ambush_fraction != -1 or data.foreign_seen or data.sampled_at != 0 or not commitment.is_empty(): return false
	else:
		if not trails.routes.has(data.route_id) or trails.routes[data.route_id].purpose != "food" or trails.routes[data.route_id].reported_losses <= 0: return false
		if restored_defense.mode == "investigate" and data.workers != CONFIG.investigation_workers: return false
		if restored_defense.mode == "defend" and (not data.reports.has(data.route_id) or data.reports[data.route_id].finding not in ["ambush","mixed"]): return false
		if restored_defense.mode == "defend" and (data.ambush_fraction != -1 or data.foreign_seen or data.sampled_at != 0): return false
		var segment: TrailSegmentState = trails.segments[trails.routes[data.route_id].segment_id]
		if data.elapsed_ticks >= TRAILS.leg_ticks(segment.start.distance_to(segment.end)) or (data.sampled_at > 0 and data.sampled_at < data.departed_at) or (data.ambush_fraction == -1 and data.sampled_at != 0 and not data.foreign_seen): return false
		if restored_defense.extra_ticks >= TRAILS.leg_ticks(segment.start.distance_to(segment.end)): return false
		if data.phase != "inbound" and data.elapsed_ticks * SimulationClock.TICK_INTERVAL > time - data.departed_at: return false
		if commitment.get("kind") != "other" or commitment.get("owner_id") != data.route_id or commitment.get("count") != data.workers + restored_defense.extra_workers: return false
		if data.elapsed_ticks * SimulationClock.TICK_INTERVAL > time - data.departed_at + TRAILS.leg_ticks(segment.start.distance_to(segment.end)) * SimulationClock.TICK_INTERVAL: return false
	route_id = data.route_id; phase = data.phase; workers = int(data.workers); elapsed_ticks = int(data.elapsed_ticks)
	departed_at = float(data.departed_at); ambush_fraction = float(data.ambush_fraction); foreign_seen = data.foreign_seen; sampled_at = float(data.sampled_at); reports = data.reports.duplicate(true)
	var restored_orders := JourneyOrders.new()
	if not restored_orders.restore(data.get("orders", {}), trails): return false
	for id: String in restored_orders.targets:
		if restored_orders.targets[id] > 0 and (not reports.has(id) or reports[id].finding not in ["ambush", "mixed"] or restored_defense.outcomes.get(id, {}).get("outcome", "") == "secured"): return false
	orders = restored_orders
	defense = restored_defense
	pressure = restored_pressure
	return true
