extends RefCounted
## Simulation-only approximation of chemical localization; no physical plume model.

const Evidence = preload("res://src/sim/scouting/observation.gd")


static func sample(agent: ScoutAgent, world: WorldState, config: ScoutConfig, rng: RandomNumberGenerator, time: float) -> String:
	var strongest: String = ""
	var nearest: float = INF
	var ids: Array = world.nodes.keys()
	ids.sort()
	for id: String in ids:
		var node: WorldNodeState = world.nodes[id]
		var distance: float = agent.position.distance_to(node.position)
		if agent.standing:
			distance = roundf(distance * 1e8) / 1e8
		if not node.active or node.quantity <= 0 or distance > config.sense_radius:
			continue
		var evidence: Observation = agent.observations.get(id)
		if evidence == null:
			evidence = Evidence.new()
			evidence.id = agent.id + ":" + id
			evidence.scout_id = agent.id
			evidence.origin_pile = agent.origin_pile
			evidence.source_node_id = id
			evidence.definition_id = node.definition_id
			evidence.first_observed_at = time
			evidence.closest_distance = INF
			agent.observations[id] = evidence
		if distance < evidence.closest_distance - 0.0001:
			evidence.closest_distance = distance
			evidence.observed_at = time
			evidence.uncertainty_radius = config.localization_floor + distance * config.distance_uncertainty
			if agent.standing:
				evidence.uncertainty_radius = roundf(evidence.uncertainty_radius * 1e8) / 1e8
			var error: Vector2 = Vector2.from_angle(rng.randf_range(-PI, PI)) * evidence.uncertainty_radius
			evidence.estimated_position = (node.position + error).clamp(world.bounds.position, world.bounds.end - Vector2(0.001, 0.001))
			evidence.proximity_confirmed = distance <= config.confirmation_radius
		if not evidence.proximity_confirmed and distance < nearest:
			nearest = distance
			strongest = id
	return strongest
