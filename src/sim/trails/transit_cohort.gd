class_name TransitCohort
extends RefCounted
## One bounded batch of committed workers, never a separate worker pool.

const Detour = preload("res://src/sim/trails/trail_detour.gd")
const Evidence = preload("res://src/sim/scouting/observation.gd")
const CONFIG = preload("res://data/trails/default_trails.tres")

var id: String
var route_id: String
var direction: String = "outbound"
var worker_count: int = 0
var resource_id: String = ""
var payload: float = 0.0
var remaining_ticks: int = 1
var unpaid_energy_cost: float = 0.0
var energy_multiplier: float = 1.0
var carry_multiplier: float = 1.0
var detour_attempted: bool = false
var detour: TrailDetour
var detour_report: Observation


func to_dict() -> Dictionary:
	return {"id": id, "route_id": route_id, "direction": direction,
		"worker_count": worker_count, "resource_id": resource_id,
		"payload": payload, "remaining_ticks": remaining_ticks,
		"unpaid_energy_cost": unpaid_energy_cost,
		"energy_multiplier": energy_multiplier, "carry_multiplier": carry_multiplier,
		"detour_attempted": detour_attempted,
		"detour": detour.to_dict() if detour != null else null,
		"detour_report": detour_report.to_dict() if detour_report != null else null}


func restore(data: Dictionary, world: WorldState, colony: ColonyState, time: float) -> bool:
	if not data.has_all(["id", "route_id", "direction", "worker_count", "resource_id", "payload", "remaining_ticks"]):
		return false
	for key: String in ["id", "route_id", "direction", "resource_id"]:
		if not data[key] is String:
			return false
	if data.id.is_empty() or data.route_id.is_empty() or not data.direction in ["outbound", "inbound"]:
		return false
	if not WorkerLedger.valid_count(data.worker_count) or data.worker_count < 1 or not WorkerLedger.valid_count(data.remaining_ticks) or data.remaining_ticks < 1:
		return false
	if not typeof(data.payload) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.payload)) or data.payload < 0.0:
		return false
	if data.has("unpaid_energy_cost") and (not typeof(data.unpaid_energy_cost) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.unpaid_energy_cost)) or data.unpaid_energy_cost < 0.0):
		return false
	var energy: Variant = data.get("energy_multiplier", 1.0)
	var carry: Variant = data.get("carry_multiplier", 1.0)
	if not typeof(energy) in [TYPE_INT, TYPE_FLOAT] or not typeof(carry) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(energy)) or not is_finite(float(carry)) or energy < 0.7 or energy > 1.2 or carry < 0.85 or carry > 1.3:
		return false
	if typeof(data.get("detour_attempted", false)) != TYPE_BOOL:
		return false
	var restored_detour: TrailDetour
	var restored_report: Observation
	if data.get("detour") != null:
		restored_detour = Detour.new()
		if not data.detour is Dictionary or not restored_detour.restore(data.detour, world, colony, time, CONFIG.side_scout_max_steps):
			return false
	if data.get("detour_report") != null:
		restored_report = Evidence.new()
		if not data.detour_report is Dictionary or not restored_report.restore(data.detour_report, world, colony, time):
			return false
	if (restored_detour != null or restored_report != null) and not data.get("detour_attempted", false):
		return false
	if restored_detour != null and (restored_report != null or data.direction != "outbound"):
		return false
	if data.direction == "outbound" and (data.payload != 0.0 or not data.resource_id.is_empty()):
		return false
	if (data.payload > 0.0) != (not data.resource_id.is_empty()):
		return false
	id = data.id
	route_id = data.route_id
	direction = data.direction
	worker_count = int(data.worker_count)
	resource_id = data.resource_id
	payload = float(data.payload)
	remaining_ticks = int(data.remaining_ticks)
	unpaid_energy_cost = float(data.get("unpaid_energy_cost", 0.0))
	energy_multiplier = float(energy)
	carry_multiplier = float(carry)
	detour_attempted = data.get("detour_attempted", false)
	detour = restored_detour
	detour_report = restored_report
	return true
