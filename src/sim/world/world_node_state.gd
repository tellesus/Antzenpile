class_name WorldNodeState
extends RefCounted

var id: String
var definition_id: String
var position: Vector2
var quantity: float
var active: bool = true
var properties: Dictionary = {}


func to_dict() -> Dictionary:
	return {"id": id, "definition_id": definition_id, "position": [position.x, position.y],
		"quantity": quantity, "active": active, "properties": properties.duplicate(true)}
