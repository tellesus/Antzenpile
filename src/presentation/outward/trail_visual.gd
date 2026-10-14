class_name TrailVisual
extends RefCounted
## Screen-space scent hints from approved route strength and placed sensory traces.

const MAX_LINKS: int = 6
const STEPS: int = 48
const ANTS_PER_LINK: int = 3
const MAX_ANTS: int = MAX_LINKS * ANTS_PER_LINK
const CACHE_LIMIT: int = 12
static var _geometry_cache: Dictionary = {}


static func home_start(viewport: Vector2, route_id: String) -> Vector2:
	# Several faint paths emerge around the known home mouth instead of making
	# identical straight-looking rays. This is purely presentation geometry.
	var home := Vector2(viewport.x * 0.5, viewport.y * 0.78 - 18.0)
	var hash_value: int = abs(route_id.hash())
	var spread: float = float(hash_value % 19 - 9) / 9.0
	return home + Vector2(spread * 14.0, sin(float(hash_value % 67) * 0.22) * 3.0)


static func geometry(start: Vector2, finish: Vector2, route_id: String) -> Dictionary:
	var key: String = "%s|%s|%s" % [route_id, start, finish]
	if _geometry_cache.has(key): return _geometry_cache[key]
	var points := PackedVector2Array()
	var delta: Vector2 = finish - start
	var distance: float = delta.length()
	var side: Vector2 = delta.normalized().orthogonal() if distance > 0.001 else Vector2.RIGHT
	var hash_value: int = abs(route_id.hash())
	var phase: float = float(hash_value % 1000) / 97.0
	var bias: float = float(hash_value % 17 - 8) / 8.0
	# A distinct departure tangent and a broad outer sweep give each memory a
	# curved approach. Low-amplitude filaments add chemical turbulence without
	# implying an actual physical path across hidden terrain.
	var first_control: Vector2 = start + Vector2(bias * 16.0, -clampf(distance * 0.22, 22.0, 78.0))
	var second_control: Vector2 = finish - delta * 0.19 + Vector2(bias * 12.0, -minf(32.0, distance * 0.09))
	var ripple: float = minf(12.0, distance * 0.024)
	for step: int in STEPS + 1:
		var t: float = float(step) / STEPS
		var inv: float = 1.0 - t
		var curve: Vector2 = start * (inv * inv * inv) + first_control * (3.0 * inv * inv * t) + second_control * (3.0 * inv * t * t) + finish * (t * t * t)
		var curl: float = sin(t * 12.0 + phase) * 0.76 + sin(t * 29.0 - phase * 0.7) * 0.24
		points.append(curve + side * curl * ripple * pow(sin(PI * t), 2.0))
	points[0] = start
	points[STEPS] = finish
	var branches: Array[PackedVector2Array] = []
	for index: int in 3:
		var first: int = 10 + index * 12
		var sign_value: float = 1.0 if (index + hash_value % 2) % 2 == 0 else -1.0
		var tangent: Vector2 = (points[first + 1] - points[first]).normalized()
		var at: Vector2 = points[first]
		branches.append(PackedVector2Array([at, at + tangent * 6.0 + side * sign_value * 6.0,
			at + tangent * 13.0 + side * sign_value * 9.0, at + tangent * 21.0 + side * sign_value * 15.0]))
	if _geometry_cache.size() >= CACHE_LIMIT:
		_geometry_cache.erase(_geometry_cache.keys()[0])
	var result: Dictionary = {"points": points, "branches": branches}
	_geometry_cache[key] = result
	return result

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
		var intent: bool=route.get("purpose", "food") in ["founding","interpile"] and route.get("founding_intent",false)
		var ghost: bool = chemical < 0.1 and (familiarity >= 0.1 or intent)
		var strength: float = maxf(familiarity,0.18 if intent else 0.0) if ghost else chemical
		if strength < 0.1:
			continue
		var destination_id: String = str(route.get("destination_knowledge_id", ""))
		for entry: Dictionary in placed:
			if entry.signal.get("category") == "threat": continue
			if entry.signal.source_knowledge_id != destination_id:
				continue
			var start: Vector2 = home_start(viewport, str(route.get("id", destination_id)))
			var finish: Vector2 = entry.center + Vector2(0.0, entry.radius * 0.45)
			var shape: Dictionary = geometry(start, finish, str(route.get("id", destination_id)))
			result.append({"points": shape.points, "branches": shape.branches, "strength": strength, "chemical": chemical, "ghost": ghost,
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
				fragment.points = path.points.slice(group * 12, group * 12 + (3 if path.ghost else 6))
				result.append(fragment)
	return result


static func alarm_markers(routes: Array, placed: Array[Dictionary], viewport: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route: Dictionary in routes:
		if not route.get("journey_alarm",route.get("reported_losses",0)>0 and not route.get("ambusher_addressed",false)) or result.size() >= MAX_LINKS:
			continue
		for entry: Dictionary in placed:
			if entry.signal.get("category") == "threat": continue
			if entry.signal.source_knowledge_id == route.destination_knowledge_id:
				# A route association, not an estimate of the hidden attack location.
				var finish: Vector2 = entry.center + Vector2(0, entry.radius * 0.45)
				var route_id: String = str(route.get("id", route.destination_knowledge_id))
				var shape: Dictionary = geometry(home_start(viewport, route_id), finish, route_id)
				var at: Vector2 = shape.points[int(STEPS * 0.32)]
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
