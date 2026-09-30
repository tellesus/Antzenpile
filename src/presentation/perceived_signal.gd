class_name PerceivedSignal
extends RefCounted
## Detached, disposable presentation values. No authoritative object references.

var id: String
var source_knowledge_id: String
var category: String
var bearing: Variant = null # Radians clockwise from east; null at the origin.
var estimated_distance: float
var uncertainty_radius: float
var strength: float
var confidence: float
var confidence_label: String
var age: float
var risk: Variant = null # Unknown until evidence exists; zero would claim safety.
var traffic: Variant = null # Unknown until trail information exists.


func to_dict() -> Dictionary:
	return {"id": id, "source_knowledge_id": source_knowledge_id, "category": category,
		"bearing": bearing, "estimated_distance": estimated_distance,
		"uncertainty_radius": uncertainty_radius, "strength": strength,
		"confidence": confidence, "confidence_label": confidence_label,
		"age": age, "risk": risk, "traffic": traffic}
