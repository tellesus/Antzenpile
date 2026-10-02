class_name Observation
extends RefCounted
## Historical sensory evidence, never a live WorldNode reference.

var id: String
var scout_id: String
var origin_pile: String
var source_node_id: String
var definition_id: String
var first_observed_at: float
var observed_at: float
var estimated_position: Vector2
var uncertainty_radius: float
var closest_distance: float
var proximity_confirmed: bool = false
var collective_search: bool = false


func detached_copy() -> Observation:
	var copy := Observation.new()
	copy.id = id
	copy.scout_id = scout_id
	copy.origin_pile = origin_pile
	copy.source_node_id = source_node_id
	copy.definition_id = definition_id
	copy.first_observed_at = first_observed_at
	copy.observed_at = observed_at
	copy.estimated_position = estimated_position
	copy.uncertainty_radius = uncertainty_radius
	copy.closest_distance = closest_distance
	copy.proximity_confirmed = proximity_confirmed
	copy.collective_search = collective_search
	return copy


func to_dict() -> Dictionary:
	return {"id": id, "scout_id": scout_id, "origin_pile": origin_pile,
		"source_node_id": source_node_id, "definition_id": definition_id,
		"first_observed_at": first_observed_at, "observed_at": observed_at,
		"estimated_position": [estimated_position.x, estimated_position.y],
		"uncertainty_radius": uncertainty_radius, "closest_distance": closest_distance,
		"proximity_confirmed": proximity_confirmed, "collective_search": collective_search}


func restore(data: Dictionary, world: WorldState, colony: ColonyState, time: float) -> bool:
	if not data.has_all(["id", "scout_id", "origin_pile", "source_node_id", "definition_id", "first_observed_at", "observed_at", "estimated_position", "uncertainty_radius", "closest_distance", "proximity_confirmed"]):
		return false
	for key: String in ["id", "scout_id", "origin_pile", "source_node_id", "definition_id"]:
		if not data[key] is String or data[key].is_empty():
			return false
	if data.id != data.scout_id + ":" + data.source_node_id or not colony.piles.has(data.origin_pile) or not world.nodes.has(data.source_node_id):
		return false
	# Validate identity only; historical evidence must not refresh from current truth.
	if data.definition_id != world.nodes[data.source_node_id].definition_id:
		return false
	for key: String in ["first_observed_at", "observed_at", "uncertainty_radius", "closest_distance"]:
		if not typeof(data[key]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])) or data[key] < 0:
			return false
	if data.first_observed_at > data.observed_at or data.observed_at > time or data.uncertainty_radius <= 0 or not data.proximity_confirmed is bool:
		return false
	if not data.get("collective_search", false) is bool:
		return false
	if not data.estimated_position is Array or data.estimated_position.size() != 2:
		return false
	for value: Variant in data.estimated_position:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	var estimate := Vector2(data.estimated_position[0], data.estimated_position[1])
	if not world.bounds.has_point(estimate):
		return false
	id = data.id
	scout_id = data.scout_id
	origin_pile = data.origin_pile
	source_node_id = data.source_node_id
	definition_id = data.definition_id
	first_observed_at = data.first_observed_at
	observed_at = data.observed_at
	estimated_position = estimate
	uncertainty_radius = data.uncertainty_radius
	closest_distance = data.closest_distance
	# Legacy senses derive float64 uncertainty from a float32 physical distance.
	# Recover that exact calculation when JSON changed only its final bit.
	var physical_distance: float = Vector2(closest_distance, 0).x
	if absf(physical_distance - closest_distance) <= 1e-15:
		closest_distance = physical_distance
	var config: ScoutConfig = preload("res://data/scouting/default_scouts.tres")
	var physical_radius: float = config.localization_floor + closest_distance * config.distance_uncertainty
	if data.get("collective_search", false):
		# Collective samples are authored to eight decimals by ScoutSenses.
		# Do not reconstruct an unrounded legacy radius from their distance.
		var rounded_radius: float = roundf(uncertainty_radius * 1e8) / 1e8
		if absf(rounded_radius - uncertainty_radius) <= 1e-15:
			uncertainty_radius = rounded_radius
	elif absf(physical_radius - uncertainty_radius) <= 1e-15:
		uncertainty_radius = physical_radius
	proximity_confirmed = data.proximity_confirmed
	collective_search = data.get("collective_search", false)
	return true
