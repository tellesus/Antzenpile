extends RefCounted
## Home-delivered route evidence only. Never queries predators or physical sources.
const CONFIG = preload("res://data/scouting/default_scouts.tres")


static func addressed(route: TrailRouteState, outcomes: Dictionary) -> bool:
	var outcome: Dictionary = outcomes.get(route.id, {})
	return outcome.get("outcome", "") == "secured" and route.reported_rival_losses == 0 and route.last_loss_time <= outcome.get("received_at", 0.0)


static func routes(run: RunState, origin_id: String) -> Array[String]:
	var result: Array[String] = []
	for route: TrailRouteState in run.trails.routes.values():
		if route.origin_pile == origin_id and route.reported_losses > 0 and not addressed(route, run.journey_response.defense.outcomes):
			result.append(route.id)
	result.sort()
	return result


static func path_risk(path: Array[Vector2], route_ids: Array[String], trails: TrailNetwork, home: Vector2) -> float:
	var risk: float = 0.0
	for id: String in route_ids:
		var end: Vector2 = trails.routes[id].estimated_destination
		var edge: Vector2 = end - home
		for point: Vector2 in path:
			if point.distance_to(home) <= CONFIG.caution_home_radius:
				continue
			var t: float = clampf((point - home).dot(edge) / maxf(edge.length_squared(), 0.000001), 0.0, 1.0)
			risk = maxf(risk, maxf(0.0, 1.0 - point.distance_to(home + edge * t) / CONFIG.caution_radius))
	return risk
