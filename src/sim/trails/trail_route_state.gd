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
var delivered_total: float = 0.0
var energy_limited: bool = false
var reported_losses: int = 0
var last_loss_time: float = 0.0


func to_dict() -> Dictionary:
	return {"id": id, "origin_pile": origin_pile,
		"destination_knowledge_id": destination_knowledge_id,
		"estimated_destination": [estimated_destination.x, estimated_destination.y],
		"segment_id": segment_id, "desired_workers": desired_workers,
		"allocated_workers": allocated_workers, "active_workers": active_workers,
		"status": status, "departure_cooldown_ticks": departure_cooldown_ticks,
		"reported_depleted": reported_depleted, "delivered_total": delivered_total,
		"energy_limited": energy_limited, "reported_losses": reported_losses, "last_loss_time": last_loss_time}


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
	if data.has("energy_limited") and typeof(data.energy_limited) != TYPE_BOOL:
		return false
	var expected_status: String = "inactive" if data.allocated_workers == 0 else "recalling" if data.desired_workers == 0 else "depleted" if data.reported_depleted else "active"
	if data.status != expected_status or (data.get("energy_limited", false) and data.status != "active"):
		return false
	var losses: Variant = data.get("reported_losses", 0)
	var loss_time: Variant = data.get("last_loss_time", 0.0)
	if not WorkerLedger.valid_count(losses) or not typeof(loss_time) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(loss_time)) or loss_time < 0.0 or ((losses == 0) != (loss_time == 0.0)):
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
	delivered_total = float(data.delivered_total)
	energy_limited = data.get("energy_limited", false)
	reported_losses = int(losses)
	last_loss_time = float(loss_time)
	return true
