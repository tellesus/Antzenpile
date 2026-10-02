class_name TrailRouteState
extends RefCounted
## Intent, labor commitment, and reported outcome; cohorts own in-flight details.

const CONFIG = preload("res://data/trails/default_trails.tres")

var id: String
var origin_pile: String
var destination_knowledge_id: String
var estimated_destination: Vector2
var segment_id: String
var desired_workers: int = 0
var allocated_workers: int = 0
var active_workers: int = 0
var status: String = "inactive"
var departure_cooldown_ticks: int = 0
var reported_depleted: bool = false
var resume_on_report: bool = false
var last_empty_report_at: float = 0.0
var delivered_total: float = 0.0
var receipt: Dictionary = {}
var energy_limited: bool = false
var foreign_reports: int = 0
var last_foreign_time: float = 0.0
var reported_rival_losses: int = 0
var conflict_report: String = ""
var conflict_observed_at: float = 0.0
var reported_losses: int = 0
var last_loss_time: float = 0.0
var attack_reports: int = 0
var fighting_reports: int = 0
var missing_workers: int = 0
var last_witness_time: float = 0.0


func to_dict() -> Dictionary:
	return {"id": id, "origin_pile": origin_pile,
		"destination_knowledge_id": destination_knowledge_id,
		"estimated_destination": [estimated_destination.x, estimated_destination.y],
		"segment_id": segment_id, "desired_workers": desired_workers,
		"allocated_workers": allocated_workers, "active_workers": active_workers,
		"status": status, "departure_cooldown_ticks": departure_cooldown_ticks,
		"resume_on_report": resume_on_report, "last_empty_report_at": last_empty_report_at,
		"reported_depleted": reported_depleted, "delivered_total": delivered_total, "receipt": receipt.duplicate(true),
		"reported_rival_losses": reported_rival_losses, "conflict_report": conflict_report,
		"conflict_observed_at": conflict_observed_at, "foreign_reports": foreign_reports, "last_foreign_time": last_foreign_time, "energy_limited": energy_limited, "reported_losses": reported_losses, "last_loss_time": last_loss_time,
		"attack_reports": attack_reports, "fighting_reports": fighting_reports,
		"missing_workers": missing_workers, "last_witness_time": last_witness_time}


func restore(data: Dictionary, colony: ColonyState, knowledge: KnowledgeBase, bounds: Rect2) -> bool:
	if not data.has_all(["id", "origin_pile", "destination_knowledge_id", "estimated_destination", "segment_id", "desired_workers", "allocated_workers", "active_workers", "status", "departure_cooldown_ticks", "reported_depleted", "delivered_total"]):
		return false
	for key: String in ["id", "origin_pile", "destination_knowledge_id", "segment_id", "status"]:
		if not data[key] is String or data[key].is_empty():
			return false
	if not colony.piles.has(data.origin_pile) or not knowledge.nodes.has(data.destination_knowledge_id):
		return false
	if not data.estimated_destination is Array or data.estimated_destination.size() != 2:
		return false
	for value: Variant in data.estimated_destination:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	var endpoint := Vector2(data.estimated_destination[0], data.estimated_destination[1])
	if not bounds.has_point(endpoint) or endpoint == colony.piles[data.origin_pile].position:
		return false
	for key: String in ["desired_workers", "allocated_workers", "active_workers"]:
		if not WorkerLedger.valid_count(data[key]):
			return false
	if data.active_workers > data.allocated_workers:
		return false
	if not WorkerLedger.valid_count(data.departure_cooldown_ticks) or data.departure_cooldown_ticks > CONFIG.departure_interval_ticks or typeof(data.reported_depleted) != TYPE_BOOL:
		return false
	if not typeof(data.delivered_total) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.delivered_total)) or data.delivered_total < 0.0:
		return false
	var saved_receipt: Variant = data.get("receipt", {})
	if not saved_receipt is Dictionary: return false
	if not saved_receipt.is_empty():
		if saved_receipt.size() != 4 or not saved_receipt.has_all(["first_at", "last_at", "last_amount", "earlier_unrecorded"]): return false
		for key: String in ["first_at", "last_at", "last_amount"]:
			if not typeof(saved_receipt[key]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(saved_receipt[key])) or saved_receipt[key] <= 0: return false
		if typeof(saved_receipt.earlier_unrecorded) != TYPE_BOOL or saved_receipt.first_at > saved_receipt.last_at or saved_receipt.last_amount > data.delivered_total: return false
		if saved_receipt.first_at < knowledge.nodes[data.destination_knowledge_id].first_delivered_at: return false
	if data.has("energy_limited") and typeof(data.energy_limited) != TYPE_BOOL:
		return false
	var expected_status: String = "inactive" if data.allocated_workers == 0 else "recalling" if data.desired_workers == 0 else "depleted" if data.reported_depleted else "active"
	if data.status != expected_status or (data.get("energy_limited", false) and data.status != "active"):
		return false
	var losses: Variant = data.get("reported_losses", 0)
	var loss_time: Variant = data.get("last_loss_time", 0.0)
	if not WorkerLedger.valid_count(losses) or not typeof(loss_time) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(loss_time)) or loss_time < 0.0 or ((losses == 0) != (loss_time == 0.0)):
		return false
	var reports: Variant = data.get("foreign_reports", 0)
	var foreign_time: Variant = data.get("last_foreign_time", 0.0)
	if not WorkerLedger.valid_count(reports) or not typeof(foreign_time) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(foreign_time)) or foreign_time < 0.0 or ((reports == 0) != (foreign_time == 0.0)):
		return false
	var rival_deaths: Variant = data.get("reported_rival_losses", 0)
	var conflict: Variant = data.get("conflict_report", "")
	var conflict_time: Variant = data.get("conflict_observed_at", 0.0)
	if not WorkerLedger.valid_count(rival_deaths) or rival_deaths > losses or not conflict in ["", "contested", "secured", "withdrew", "dispersed"] or not typeof(conflict_time) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(conflict_time)) or conflict_time < 0.0 or ((conflict == "") != (conflict_time == 0.0)):
		return false
	var attacks: Variant = data.get("attack_reports", 0)
	var fights: Variant = data.get("fighting_reports", 0)
	var missing: Variant = data.get("missing_workers", 0)
	var witness_time: Variant = data.get("last_witness_time", 0.0)
	for count: Variant in [attacks, fights, missing]:
		if not WorkerLedger.valid_count(count):
			return false
	if attacks > losses - rival_deaths or fights > rival_deaths or missing > losses - attacks - fights:
		return false
	if not typeof(witness_time) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(witness_time)) or witness_time < 0.0 or witness_time > loss_time or ((attacks + fights == 0) != (witness_time == 0.0)):
		return false
	var resume: Variant = data.get("resume_on_report", false)
	var empty_at: Variant = data.get("last_empty_report_at", knowledge.last_empty_report(data.destination_knowledge_id) if data.reported_depleted else 0.0)
	if not resume is bool or not typeof(empty_at) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(empty_at)) or empty_at < 0:
		return false
	id = data.id
	origin_pile = data.origin_pile
	destination_knowledge_id = data.destination_knowledge_id
	estimated_destination = endpoint
	segment_id = data.segment_id
	desired_workers = int(data.desired_workers)
	allocated_workers = int(data.allocated_workers)
	active_workers = int(data.active_workers)
	status = data.status
	departure_cooldown_ticks = int(data.departure_cooldown_ticks)
	reported_depleted = data.reported_depleted
	resume_on_report = resume
	last_empty_report_at = float(empty_at)
	delivered_total = float(data.delivered_total)
	receipt = saved_receipt.duplicate(true)
	energy_limited = data.get("energy_limited", false)
	foreign_reports = int(reports)
	last_foreign_time = float(foreign_time)
	reported_rival_losses = int(rival_deaths)
	conflict_report = conflict
	conflict_observed_at = float(conflict_time)
	reported_losses = int(losses)
	last_loss_time = float(loss_time)
	attack_reports = int(attacks)
	fighting_reports = int(fights)
	missing_workers = int(missing)
	last_witness_time = float(witness_time)
	return true
