class_name TransitCohort
extends RefCounted
## One bounded batch of committed workers, never a separate worker pool.

var id: String
var route_id: String
var direction: String = "outbound"
var worker_count: int = 0
var resource_id: String = ""
var payload: float = 0.0
var remaining_ticks: int = 1


func to_dict() -> Dictionary:
	return {"id": id, "route_id": route_id, "direction": direction,
		"worker_count": worker_count, "resource_id": resource_id,
		"payload": payload, "remaining_ticks": remaining_ticks}


func restore(data: Dictionary) -> bool:
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
	return true
