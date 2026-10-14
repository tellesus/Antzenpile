class_name HoneydewState
extends RefCounted
## One backyard producer relationship; source quantity remains in WorldState.

const CONFIG = preload("res://data/ecology/backyard_honeydew.tres")
const RELATIONSHIPS: Array[String] = ["unknown", "exploited", "tended"]

var services: Dictionary[String,ProducerServiceState]={}
var legacy_services: bool=false
var relationship: String = "unknown"
var condition: float = CONFIG.initial_condition
var protection_workers: int = 0
var recognition_share: float = 0.0


func to_dict() -> Dictionary:
	return {"service_version":1,"services":_service_records(),"relationship": relationship, "condition": condition, "protection_workers": protection_workers, "recognition_share": recognition_share}


func _service_records() -> Dictionary:
	var result: Dictionary={}
	for id: String in services:result[id]=services[id].to_dict()
	return result

func restore(data: Dictionary) -> bool:
	if data.has("services")!=data.has("service_version"):return false
	if not data.has_all(["relationship", "condition", "protection_workers"]) or not data.relationship is String or not RELATIONSHIPS.has(data.relationship):
		return false
	if not typeof(data.condition) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.condition)) or float(data.condition) < CONFIG.minimum_condition or float(data.condition) > 100.0:
		return false
	var share: Variant = data.get("recognition_share", 0.0)
	if not typeof(share) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(share)) or absf(share) > 1.0 or (not data.has("services") and data.relationship != "tended" and share != 0.0):
		return false
	if not WorkerLedger.valid_count(data.protection_workers):return false
	if not data.has("services") and int(data.protection_workers) != (AdaptationRules.protection_workers(CONFIG.protection_workers, share) if data.relationship == "tended" else 0):
		return false
	var parsed: Dictionary[String,ProducerServiceState]={}
	if data.has("services"):
		if data.get("service_version")!=1 or not data.services is Dictionary:return false
		for id: Variant in data.services:
			var state:=ProducerServiceState.new()
			if not PileState.valid_id(id) or not state.restore(data.services[id]):return false
			parsed[id]=state
		if parsed.is_empty() and data.relationship=="tended":return false
		var home: ProducerServiceState=parsed.get("home")
		if data.protection_workers!=(home.count if home!=null else 0) or share!=(home.recognition_share if home!=null else 0):return false
		if not parsed.is_empty() and data.relationship!=("tended" if parsed.values().any(func(state: ProducerServiceState)->bool:return state.known_target()>0) else "exploited"):return false
	else:legacy_services=data.relationship=="tended"
	services=parsed
	relationship = data.relationship
	condition = float(data.condition)
	protection_workers = int(data.protection_workers)
	recognition_share = snappedf(float(share), 0.00001)
	return true
