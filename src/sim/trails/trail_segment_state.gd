class_name TrailSegmentState
extends RefCounted
## Distinct estimated infrastructure; chemical fields are separate from familiarity.

var id: String
var route_id: String
var start: Vector2
var end: Vector2
var pheromone_strength: float = 0.0
var persistent_chemistry: float = 0.0
var route_familiarity: float = 0.0
var traffic: int = 0
var exposure: float = 0.0
var waypoints: Array[Vector2] = []

func points() -> Array[Vector2]:
	var result: Array[Vector2] = [start]; result.append_array(waypoints); result.append(end)
	return result

func length() -> float:
	var result: float = 0
	var path: Array[Vector2] = points()
	for index: int in range(1, path.size()): result += path[index-1].distance_to(path[index])
	return result

func point_at(fraction: float) -> Vector2:
	if waypoints.is_empty(): return start.lerp(end, fraction)
	var remaining: float = clampf(fraction, 0, 1) * length()
	var path: Array[Vector2] = points()
	for index: int in range(1, path.size()):
		var size: float = path[index-1].distance_to(path[index])
		if remaining <= size: return path[index-1].lerp(path[index], remaining / size)
		remaining -= size
	return end

func distance_from_start(point: Vector2) -> float:
	var path: Array[Vector2] = points()
	var walked: float = 0; var best: float = INF; var distance: float = 0
	for index: int in range(1, path.size()):
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point, path[index-1], path[index])
		if nearest.distance_to(point) < best:
			best = nearest.distance_to(point); distance = walked + path[index-1].distance_to(nearest)
		walked += path[index-1].distance_to(path[index])
	return distance

func distance_to_path(point: Vector2) -> float:
	var best: float = INF; var path: Array[Vector2] = points()
	for index: int in range(1, path.size()): best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point,path[index-1],path[index])))
	return best

func intersections(origin: Vector2, destination: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []; var path: Array[Vector2] = points()
	for index: int in range(1, path.size()):
		var intersection: Variant = Geometry2D.segment_intersects_segment(path[index-1],path[index],origin,destination)
		if intersection != null: result.append(intersection)
	return result

func terrain_cost(world: WorldState) -> float:
	return _path_average(world, false)

func path_exposure(world: WorldState) -> float:
	return _path_average(world, true)

func _path_average(world: WorldState, exposed: bool) -> float:
	if waypoints.is_empty(): return exposure_for(world,start,end) if exposed else terrain_cost_for(world,start,end)
	var total: float = 0; var path: Array[Vector2] = points()
	for index: int in range(1, path.size()):
		var average: float = exposure_for(world,path[index-1],path[index]) if exposed else terrain_cost_for(world,path[index-1],path[index])
		total += average * path[index-1].distance_to(path[index])
	return total / length()


static func exposure_for(world: WorldState, origin: Vector2, destination: Vector2) -> float:
	var total: float = 0.0
	for index: int in 16:
		var point: Vector2 = origin.lerp(destination, (float(index) + 0.5) / 16.0)
		for region: Dictionary in world.terrain:
			var area := Rect2(region.bounds[0], region.bounds[1], region.bounds[2], region.bounds[3])
			if area.has_point(point):
				total += float(region.exposure)
				break
	return total / 16.0


static func terrain_cost_for(world: WorldState, origin: Vector2, destination: Vector2) -> float:
	var total: float = 0.0
	for index: int in 16:
		var point: Vector2 = origin.lerp(destination, (float(index) + 0.5) / 16.0)
		var movement_cost: float = 1.0
		for region: Dictionary in world.terrain:
			var area := Rect2(region.bounds[0], region.bounds[1], region.bounds[2], region.bounds[3])
			if area.has_point(point):
				movement_cost = float(region.movement_cost)
				break
		total += movement_cost
	return total / 16.0


func to_dict() -> Dictionary:
	return {"id": id, "route_id": route_id,
		"start": [start.x, start.y], "end": [end.x, end.y],
		"pheromone_strength": pheromone_strength,
		"persistent_chemistry": persistent_chemistry,
		"route_familiarity": route_familiarity, "traffic": traffic, "exposure": exposure,"waypoints":waypoints.map(func(point: Vector2) -> Array: return [point.x,point.y])}


func restore(data: Dictionary, bounds: Rect2) -> bool:
	if not data.has_all(["id", "route_id", "start", "end", "pheromone_strength", "route_familiarity", "traffic", "exposure"]):
		return false
	if not data.id is String or data.id.is_empty() or not data.route_id is String or data.route_id.is_empty():
		return false
	for key: String in ["start", "end"]:
		if not data[key] is Array or data[key].size() != 2:
			return false
		for value: Variant in data[key]:
			if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
				return false
	var origin := Vector2(data.start[0], data.start[1])
	var destination := Vector2(data.end[0], data.end[1])
	var raw: Variant = data.get("waypoints", [])
	if not raw is Array or raw.size() not in [0, 2]: return false
	var restored_points: Array[Vector2] = []
	for record: Variant in raw:
		if not record is Array or record.size() != 2: return false
		for value: Variant in record:
			if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)): return false
		var point := Vector2(record[0],record[1])
		if not bounds.has_point(point) or point == origin or point == destination or point in restored_points: return false
		restored_points.append(point)
	if not bounds.has_point(origin) or not bounds.has_point(destination) or origin == destination:
		return false
	if not typeof(data.pheromone_strength) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.pheromone_strength)) or data.pheromone_strength < 0.0 or data.pheromone_strength > 1.0:
		return false
	var durable: Variant = data.get("persistent_chemistry", 0.0)
	if not typeof(durable) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(durable)) or durable < 0.0 or durable > data.pheromone_strength:
		return false
	if not typeof(data.route_familiarity) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.route_familiarity)) or data.route_familiarity < 0.0 or data.route_familiarity > 1.0:
		return false
	if not WorkerLedger.valid_count(data.traffic):
		return false
	if not typeof(data.exposure) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.exposure)) or data.exposure < 0.0 or data.exposure > 1.0:
		return false
	id = data.id
	route_id = data.route_id
	start = origin
	end = destination
	waypoints = restored_points
	# Match the tick quantization after JSON's decimal-to-binary conversion.
	pheromone_strength = snappedf(float(data.pheromone_strength), 0.0000000001)
	persistent_chemistry = snappedf(float(durable), 0.0000000001)
	route_familiarity = snappedf(float(data.route_familiarity), 0.0000000001)
	traffic = int(data.traffic)
	exposure = float(data.exposure)
	return true


func reinforce_chemistry(amount: float, fraction: float) -> void:
	# Blend incoming secretion before saturation; repeated returns cannot turn
	# baseline chemistry durable without contributing expressed workers.
	var total: float = pheromone_strength + amount
	var durable: float = persistent_chemistry + amount * fraction
	persistent_chemistry = snappedf(durable / total if total > 1.0 else durable, 0.0000000001)
	pheromone_strength = snappedf(minf(1.0, total), 0.0000000001)


func decay_chemistry(half_lives: float) -> void:
	var ordinary: float = maxf(0.0, pheromone_strength - persistent_chemistry) * pow(0.5, half_lives)
	persistent_chemistry = snappedf(persistent_chemistry * pow(0.5, half_lives / AdaptationRules.CHEMISTRY.persistence_multiplier), 0.0000000001)
	pheromone_strength = snappedf(ordinary + persistent_chemistry, 0.0000000001)
	if pheromone_strength < 0.0001:
		pheromone_strength = 0.0
		persistent_chemistry = 0.0
