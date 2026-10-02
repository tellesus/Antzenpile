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
var contaminant_mass: float = 0.0
var remaining_ticks: int = 1
var unpaid_energy_cost: float = 0.0
var energy_multiplier: float = 1.0
var carry_multiplier: float = 1.0
var chemistry_fraction: float = 0.0
var lost_workers: int = 0
var adapted_lost_workers: int = 0
var lost_profiles: Dictionary[String, int] = {}
var foreign_contact: bool = false
var foreign_sampled: bool = false
var reports_source_outcome: bool = true
var swarm_engaged: bool = false
var rival_losses: int = 0
var conflict_report: String = ""
var conflict_observed_at: float = 0.0
var predator_encountered: bool = false
var witnessed_attack: bool = false
var witnessed_fighting: bool = false
var detour_attempted: bool = false
var detour: TrailDetour
var detour_report: Observation


func to_dict() -> Dictionary:
	return {"id": id, "route_id": route_id, "direction": direction,
		"worker_count": worker_count, "resource_id": resource_id,
		"payload": payload, "remaining_ticks": remaining_ticks, "contaminant_mass": contaminant_mass,
		"unpaid_energy_cost": unpaid_energy_cost,
		"energy_multiplier": energy_multiplier, "carry_multiplier": carry_multiplier,
		"chemistry_fraction": chemistry_fraction,
		"lost_workers": lost_workers, "adapted_lost_workers": adapted_lost_workers,
		"lost_profiles": lost_profiles.duplicate(),
		"witnessed_attack": witnessed_attack, "witnessed_fighting": witnessed_fighting,
		"foreign_sampled": foreign_sampled, "reports_source_outcome": reports_source_outcome,
		"swarm_engaged": swarm_engaged, "rival_losses": rival_losses,
		"conflict_report": conflict_report, "conflict_observed_at": conflict_observed_at, "foreign_contact": foreign_contact, "predator_encountered": predator_encountered, "detour_attempted": detour_attempted,
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
	if not WorkerLedger.valid_count(data.worker_count) or not WorkerLedger.valid_count(data.remaining_ticks) or data.remaining_ticks < 1:
		return false
	if not typeof(data.payload) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.payload)) or data.payload < 0.0:
		return false
	var contamination: Variant = data.get("contaminant_mass",0.0)
	if not typeof(contamination) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(contamination)) or contamination < 0 or contamination > data.payload or (contamination > 0 and (data.resource_id != "carbohydrate" or data.direction != "inbound")): return false
	if data.has("unpaid_energy_cost") and (not typeof(data.unpaid_energy_cost) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.unpaid_energy_cost)) or data.unpaid_energy_cost < 0.0):
		return false
	var energy: Variant = data.get("energy_multiplier", 1.0)
	var carry: Variant = data.get("carry_multiplier", 1.0)
	var chemistry: Variant = data.get("chemistry_fraction", 0.0)
	if not typeof(chemistry) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(chemistry)) or chemistry < 0.0 or chemistry > 1.0:
		return false
	if not typeof(energy) in [TYPE_INT, TYPE_FLOAT] or not typeof(carry) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(energy)) or not is_finite(float(carry)) or energy < 0.7 or energy > 1.2 or carry < 0.85 or carry > 1.3:
		return false
	if typeof(data.get("foreign_contact", false)) != TYPE_BOOL or typeof(data.get("detour_attempted", false)) != TYPE_BOOL:
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
	var losses: Variant = data.get("lost_workers", 0)
	var adapted_losses: Variant = data.get("adapted_lost_workers", 0)
	var rival_deaths: Variant = data.get("rival_losses", 0)
	if not WorkerLedger.valid_count(rival_deaths) or rival_deaths > losses:
		return false
	var encountered: Variant = data.get("predator_encountered", false)
	if not WorkerLedger.valid_count(losses) or losses > CONFIG.workers_per_cohort or losses - rival_deaths > 1 or not WorkerLedger.valid_count(adapted_losses) or adapted_losses > losses or typeof(encountered) != TYPE_BOOL or (losses > rival_deaths and not encountered):
		return false
	if data.worker_count == 0 and (losses == 0 or data.payload != 0.0 or restored_detour != null or restored_report != null):
		return false
	var profile_losses: Variant = data.get("lost_profiles", {})
	if not profile_losses is Dictionary:
		return false
	var restored_profiles: Dictionary[String, int] = {}
	var profile_total: int = 0
	for key: Variant in profile_losses:
		if not key is String or key == "" or not WorkerLedger.valid_count(profile_losses[key]) or profile_losses[key] < 1:
			return false
		restored_profiles[key] = int(profile_losses[key])
		profile_total += int(profile_losses[key])
	if profile_total > losses:
		return false
	var attack_witness: Variant = data.get("witnessed_attack", false)
	var fighting_witness: Variant = data.get("witnessed_fighting", false)
	if typeof(attack_witness) != TYPE_BOOL or typeof(fighting_witness) != TYPE_BOOL:
		return false
	if (attack_witness and (data.worker_count == 0 or losses <= rival_deaths)) or (fighting_witness and (data.worker_count == 0 or rival_deaths == 0)):
		return false
	for key: String in ["foreign_sampled", "reports_source_outcome", "swarm_engaged"]:
		if typeof(data.get(key, key == "reports_source_outcome")) != TYPE_BOOL:
			return false
	var report: Variant = data.get("conflict_report", "")
	var report_time: Variant = data.get("conflict_observed_at", 0.0)
	if not report in ["", "contested", "secured", "withdrew", "dispersed"] or not typeof(report_time) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(report_time)) or report_time < 0.0 or report_time > time or ((report == "") != (report_time == 0.0)):
		return false
	if not data.get("reports_source_outcome", true) and (data.direction != "inbound" or (data.worker_count > 0 and report == "")):
		return false
	if data.worker_count == 0 and (data.get("swarm_engaged", false) or report != ""):
		return false
	if data.get("foreign_contact", false) and not data.get("foreign_sampled", data.get("foreign_contact", false)):
		return false
	id = data.id
	route_id = data.route_id
	direction = data.direction
	worker_count = int(data.worker_count)
	resource_id = data.resource_id
	payload = float(data.payload)
	contaminant_mass = float(contamination)
	remaining_ticks = int(data.remaining_ticks)
	unpaid_energy_cost = float(data.get("unpaid_energy_cost", 0.0))
	energy_multiplier = float(energy)
	carry_multiplier = float(carry)
	chemistry_fraction = snappedf(float(chemistry), 0.00001)
	lost_workers = int(losses)
	adapted_lost_workers = int(adapted_losses)
	lost_profiles = restored_profiles
	predator_encountered = encountered
	witnessed_attack = attack_witness
	witnessed_fighting = fighting_witness
	foreign_contact = data.get("foreign_contact", false)
	foreign_sampled = data.get("foreign_sampled", foreign_contact)
	reports_source_outcome = data.get("reports_source_outcome", true)
	swarm_engaged = data.get("swarm_engaged", false)
	rival_losses = int(rival_deaths)
	conflict_report = report
	conflict_observed_at = float(report_time)
	detour_attempted = data.get("detour_attempted", false)
	detour = restored_detour
	detour_report = restored_report
	return true
