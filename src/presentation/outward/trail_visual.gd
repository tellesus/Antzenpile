class_name TrailVisual
extends RefCounted
## Screen-space scent hints from approved route strength and placed sensory traces.

const MAX_LINKS: int = 6
const STEPS: int = 24


static func strokes(routes: Array, placed: Array[Dictionary], viewport: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not viewport.is_finite() or viewport.x <= 0.0 or viewport.y <= 0.0:
		return result
	var count: int = 0
	for route: Dictionary in routes:
		if count >= MAX_LINKS:
			break
		var strength: float = float(route.get("pheromone_strength", 0.0))
		if not is_finite(strength) or strength < 0.1:
			continue
		var destination_id: String = str(route.get("destination_knowledge_id", ""))
		for entry: Dictionary in placed:
			if entry.signal.source_knowledge_id != destination_id:
				continue
			var start := Vector2(viewport.x * 0.5, viewport.y * 0.78 - 18.0)
			var finish: Vector2 = entry.center + Vector2(0.0, entry.radius * 0.45)
			var bend: float = 24.0 if finish.x >= start.x else -24.0
			var control := Vector2((start.x + finish.x) * 0.5 + bend, minf(start.y, finish.y) - 28.0)
			var points := PackedVector2Array()
			for step: int in range(STEPS + 1):
				var t: float = float(step) / STEPS
				points.append(start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + finish * t * t)
			if strength >= 0.45:
				result.append({"points": points, "strength": strength})
			else:
				for group: int in range(4):
					var first: int = group * 6
					result.append({"points": points.slice(first, first + 3), "strength": strength})
			count += 1
			break
	return result
