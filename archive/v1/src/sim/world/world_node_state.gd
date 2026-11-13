class_name WorldNodeState
extends RefCounted

var id: String
var definition_id: String
var source_type: String = ""
var site_profile: String = ""
var position: Vector2
var quantity: float
var active: bool = true
var properties: Dictionary = {}


func to_dict() -> Dictionary:
	return {"id": id, "definition_id": definition_id, "source_type":source_type,"site_profile":site_profile, "position": [position.x, position.y],
		"quantity": quantity, "active": active, "properties": properties.duplicate(true)}
