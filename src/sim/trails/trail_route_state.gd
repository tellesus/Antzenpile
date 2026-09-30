class_name TrailRouteState
extends RefCounted
## Intent and labor commitment. Traveler state begins in task 013.

var id: String
var origin_pile: String
var destination_knowledge_id: String
var estimated_destination: Vector2
var segment_id: String
var desired_workers: int = 0
var allocated_workers: int = 0
var active_workers: int = 0
var status: String = "inactive"


func to_dict() -> Dictionary:
	return {"id": id, "origin_pile": origin_pile,
		"destination_knowledge_id": destination_knowledge_id,
		"estimated_destination": [estimated_destination.x, estimated_destination.y],
		"segment_id": segment_id, "desired_workers": desired_workers,
		"allocated_workers": allocated_workers, "active_workers": active_workers,
		"status": status}


func restore(data: Dictionary, colony: ColonyState, knowledge: KnowledgeBase, bounds: Rect2) -> bool:
	if not data.has_all(["id", "origin_pile", "destination_knowledge_id", "estimated_destination", "segment_id", "desired_workers", "allocated_workers", "active_workers", "status"]):
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
	if data.desired_workers != data.allocated_workers or data.active_workers != 0:
		return false
	if not data.status in ["active", "inactive"] or (data.status == "active") != (data.allocated_workers > 0):
		return false
	id = data.id
	origin_pile = data.origin_pile
	destination_knowledge_id = data.destination_knowledge_id
	estimated_destination = endpoint
	segment_id = data.segment_id
	desired_workers = int(data.desired_workers)
	allocated_workers = int(data.allocated_workers)
	active_workers = 0
	status = data.status
	return true
