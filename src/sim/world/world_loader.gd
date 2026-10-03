class_name WorldLoader
extends RefCounted

const World = preload("res://src/sim/world/world_state.gd")
const RESOURCE_PATHS: Array[String] = ["res://data/resources/carbohydrate.tres", "res://data/resources/protein.tres", "res://data/resources/water.tres", "res://data/resources/nest_site.tres"]
var last_error: String = ""


static func definition_ids() -> Array[String]:
	var ids: Array[String] = []
	for path: String in RESOURCE_PATHS:
		var definition: ResourceDefinition = load(path)
		ids.append(definition.id)
	return ids


func load_scenario(path: String = "res://data/scenarios/backyard_slice.tres") -> WorldState:
	var scenario: ScenarioDefinition = load(path) as ScenarioDefinition
	if scenario == null:
		last_error = "Scenario cannot be loaded: " + path
		return null
	var records: Array[Dictionary] = []
	for definition: WorldNodeDefinition in scenario.nodes:
		if definition == null or definition.definition == null:
			last_error = "Node has no resource definition"
			return null
		if not is_finite(definition.contaminant_fraction) or definition.contaminant_fraction < 0 or definition.contaminant_fraction > 1:
			last_error = "Invalid authored contaminant fraction"
			return null
		records.append({"id": definition.id, "definition_id": definition.definition.id,
			"position": [definition.position.x, definition.position.y], "quantity": definition.initial_quantity,
			"active": definition.initial_active, "properties": {}})
		if definition.contaminant_fraction > 0: records.back().properties.contaminant_fraction = definition.contaminant_fraction
	var regions: Array[Dictionary] = []
	for definition: TerrainDefinition in scenario.terrain:
		if definition == null:
			last_error = "Missing terrain definition"
			return null
		regions.append({"id": definition.id, "bounds": [definition.bounds.position.x, definition.bounds.position.y, definition.bounds.size.x, definition.bounds.size.y],
			"exposure": definition.exposure, "traversable": definition.traversable, "movement_cost": definition.movement_cost})
	var world := World.new()
	if not world.restore({"bounds": [scenario.bounds.position.x, scenario.bounds.position.y, scenario.bounds.size.x, scenario.bounds.size.y],
		"home_position": [scenario.home_position.x, scenario.home_position.y], "nodes": records, "terrain": regions}, definition_ids()):
		last_error = world.last_error
		return null
	last_error = ""
	return world
