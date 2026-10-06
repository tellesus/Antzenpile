class_name KnownNode
extends RefCounted

const CONFIG = preload("res://data/knowledge/default_knowledge.tres")
var id: String
var source_node_id: String
var definition_id: String
var source_type: String = ""
var label_index: int = 0
var estimated_position: Vector2
var uncertainty_radius: float
var confidence: float
var first_observed_at: float
var last_observed_at: float
var first_delivered_at: float
var last_delivered_at: float
var selected_evidence_id: String
var evidence_ids: Array[String] = []


func age_at(time: float) -> float:
	return maxf(0.0, time - last_observed_at)


func confidence_at(time: float) -> float:
	return aged_confidence(confidence, age_at(time))


static func aged_confidence(baseline: float, age: float) -> float:
	return clampf(baseline * pow(0.5, maxf(0.0, age) / CONFIG.confidence_half_life), 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"id": id, "source_node_id": source_node_id, "definition_id": definition_id, "source_type":source_type, "label_index":label_index,
		"estimated_position": [estimated_position.x, estimated_position.y],
		"uncertainty_radius": uncertainty_radius, "confidence": confidence,
		"first_observed_at": first_observed_at, "last_observed_at": last_observed_at,
		"first_delivered_at": first_delivered_at, "last_delivered_at": last_delivered_at,
		"selected_evidence_id": selected_evidence_id, "evidence_ids": evidence_ids.duplicate()}
