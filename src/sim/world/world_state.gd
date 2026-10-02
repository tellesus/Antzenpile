class_name WorldState
extends RefCounted

const WorldNode = preload("res://src/sim/world/world_node_state.gd")
var bounds: Rect2
var home_position: Vector2
var nodes: Dictionary[String, WorldNodeState] = {}
# Static terrain snapshots: callers must not mutate authored terrain during the slice.
var terrain: Array[Dictionary] = []
var last_error: String = ""


func to_dict() -> Dictionary:
	var records: Array[Dictionary] = []
	var ids: Array = nodes.keys()
	ids.sort()
	for id: String in ids:
		records.append(nodes[id].to_dict())
	return {"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"home_position": [home_position.x, home_position.y], "nodes": records, "terrain": terrain.duplicate(true)}


func restore(data: Dictionary, definition_ids: Array[String]) -> bool:
	last_error = ""
	if not data.has_all(["bounds", "home_position", "nodes", "terrain"]) or not _numbers(data.bounds, 4) or not _numbers(data.home_position, 2):
		return _reject("Missing/invalid bounds or home position")
	var area := Rect2(data.bounds[0], data.bounds[1], data.bounds[2], data.bounds[3])
	var home := Vector2(data.home_position[0], data.home_position[1])
	if area.size.x <= 0.0 or area.size.y <= 0.0 or not area.has_point(home):
		return _reject("World bounds must contain home and have positive size")
	if not data.nodes is Array or not data.terrain is Array or data.terrain.is_empty():
		return _reject("Nodes/terrain must be arrays and terrain cannot be empty")
	var candidate_nodes: Dictionary[String, WorldNodeState] = {}
	for value: Variant in data.nodes:
		if not value is Dictionary or not value.has_all(["id", "definition_id", "position", "quantity", "active", "properties"]):
			return _reject("Malformed node")
		if not value.id is String or value.id.is_empty() or candidate_nodes.has(value.id):
			return _reject("Empty/duplicate node ID")
		if not value.definition_id is String or not definition_ids.has(value.definition_id):
			return _reject("Unknown resource definition")
		if not _numbers(value.position, 2) or not _number(value.quantity) or value.quantity < 0.0:
			return _reject("Invalid node position/quantity")
		var position := Vector2(value.position[0], value.position[1])
		if not area.has_point(position) or typeof(value.active) != TYPE_BOOL or not value.properties is Dictionary:
			return _reject("Node outside bounds or invalid active/properties")
		var contamination: Variant = value.properties.get("contaminant_fraction",0.0)
		if not _number(contamination) or contamination < 0 or contamination > 1 or (contamination > 0 and value.definition_id != "carbohydrate"): return _reject("Invalid food contamination")
		var node := WorldNode.new()
		node.id = value.id
		node.definition_id = value.definition_id
		node.position = position
		node.quantity = value.quantity
		node.active = value.active
		node.properties = value.properties.duplicate(true)
		candidate_nodes[node.id] = node
	var candidate_terrain: Array[Dictionary] = []
	var terrain_ids: Array[String] = []
	for value: Variant in data.terrain:
		if not value is Dictionary or not value.has_all(["id", "bounds", "exposure", "traversable", "movement_cost"]):
			return _reject("Malformed terrain")
		if not value.id is String or value.id.is_empty() or terrain_ids.has(value.id) or not _numbers(value.bounds, 4):
			return _reject("Invalid terrain ID/bounds")
		var region := Rect2(value.bounds[0], value.bounds[1], value.bounds[2], value.bounds[3])
		if region.size.x <= 0 or region.size.y <= 0 or not area.encloses(region):
			return _reject("Terrain outside world bounds")
		if not _number(value.exposure) or value.exposure < 0 or value.exposure > 1 or not _number(value.movement_cost) or value.movement_cost <= 0 or typeof(value.traversable) != TYPE_BOOL:
			return _reject("Invalid terrain properties")
		terrain_ids.append(value.id)
		candidate_terrain.append(value.duplicate(true))
	bounds = area
	home_position = home
	nodes = candidate_nodes
	terrain = candidate_terrain
	return true


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for item: Variant in value:
		if not _number(item):
			return false
	return true


func _reject(reason: String) -> bool:
	last_error = reason
	return false
