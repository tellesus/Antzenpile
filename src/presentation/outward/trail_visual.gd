class_name TrailVisual
extends RefCounted
## Screen-space scent hints from approved route strength and placed sensory traces.

const MAX_LINKS: int = 6
const STEPS: int = 24
const ANTS_PER_LINK: int = 3
const MAX_ANTS: int = MAX_LINKS * ANTS_PER_LINK


static func paths(routes: Array, placed: Array[Dictionary], viewport: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not viewport.is_finite() or viewport.x <= 0.0 or viewport.y <= 0.0:
		return result
	var count: int = 0
	for route: Dictionary in routes:
		if count >= MAX_LINKS:
			break
		var chemical: float = float(route.get("pheromone_strength", 0.0))
		var familiarity: float = float(route.get("route_familiarity", 0.0))
		if not is_finite(chemical) or not is_finite(familiarity):
			continue
		var ghost: bool = chemical < 0.1 and familiarity >= 0.1
		var strength: float = familiarity if ghost else chemical
		if strength < 0.1:
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
			result.append({"points": points, "strength": strength, "chemical": chemical, "ghost": ghost,
				"category": entry.signal.get("category", "carbohydrate"), "route": route.duplicate(true)})
			count += 1
			break
	return result


static func strokes(routes: Array, placed: Array[Dictionary], viewport: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path: Dictionary in paths(routes, placed, viewport):
		if path.chemical >= 0.45:
			result.append(path)
		else:
			for group: int in 4:
				var fragment: Dictionary = path.duplicate()
				fragment.points = path.points.slice(group * 6, group * 6 + 3)
				result.append(fragment)
	return result


static func alarm_markers(routes: Array, placed: Array[Dictionary], viewport: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var home := Vector2(viewport.x * 0.5, viewport.y * 0.78 - 18.0)
	for route: Dictionary in routes:
		if route.get("reported_losses", 0) == 0 or result.size() >= MAX_LINKS:
			continue
		for entry: Dictionary in placed:
			if entry.signal.source_knowledge_id == route.destination_knowledge_id:
				# A route association, not an estimate of the hidden attack location.
				var finish: Vector2 = entry.center + Vector2(0, entry.radius * 0.45)
				var bend: float = 24.0 if finish.x >= home.x else -24.0
				var control := Vector2((home.x + finish.x) * 0.5 + bend, minf(home.y, finish.y) - 28.0)
				var t: float = 0.32
				var at: Vector2 = home * (1.0 - t) * (1.0 - t) + control * 2.0 * t * (1.0 - t) + finish * t * t
				result.append({"id": entry.id, "center": at})
				break
	return result


static func representatives(routes: Array, placed: Array[Dictionary], viewport: Vector2, time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path: Dictionary in paths(routes, placed, viewport):
		var workers: int = int(path.route.get("active_workers", 0))
		if path.ghost or workers <= 0:
			continue
		var count: int = mini(ANTS_PER_LINK, workers)
		var phase: float = float(abs(str(path.route.get("id", "")).hash()) % 100) / 100.0
		for index: int in count:
			var t: float = fposmod(time * 0.065 + float(index) / ANTS_PER_LINK + phase, 1.0)
			if index % 2 == 1:
				t = 1.0 - t
			var sample: float = clampf(t, 0.025, 0.975) * STEPS
			var first: int = int(sample)
			var a: Vector2 = path.points[first]
			var b: Vector2 = path.points[first + 1]
			result.append({"position": a.lerp(b, sample - first), "direction": (b - a) * (-1.0 if index % 2 == 1 else 1.0), "category": path.category})
	return result
