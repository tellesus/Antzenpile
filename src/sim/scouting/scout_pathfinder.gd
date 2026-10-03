extends RefCounted
## Conservative one-meter cardinal grid. Static terrain graph is built per dispatch.

class TerrainGraph extends AStar2D:
	func _estimate_cost(_from_id: int, _end_id: int) -> float:
		# Zero remains admissible even when authored terrain costs are below one.
		return 0.0

var _graph := TerrainGraph.new()
var _positions: Dictionary[Vector2i, int] = {}


func _init(world: WorldState) -> void:
	var id: int = 0
	for y: int in range(ceili(world.bounds.position.y), ceili(world.bounds.end.y)):
		for x: int in range(ceili(world.bounds.position.x), ceili(world.bounds.end.x)):
			var position := Vector2(x, y)
			var cost: float = travel_cost(world, position)
			if not is_finite(cost):
				continue
			var cell := Vector2i(x, y)
			_positions[cell] = id
			_graph.add_point(id, position, cost)
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.UP]:
				if _positions.has(cell + offset):
					_graph.connect_points(id, _positions[cell + offset])
			id += 1


func path(start: Vector2, destination: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not start.is_equal_approx(start.round()) or not destination.is_equal_approx(destination.round()):
		return result
	if not _positions.has(Vector2i(start)) or not _positions.has(Vector2i(destination)):
		return result
	result.assign(_graph.get_point_path(_positions[Vector2i(start)], _positions[Vector2i(destination)]))
	return result


func path_from_origin(start: Vector2, destination: Vector2, world: WorldState) -> Array[Vector2]:
	# A founded entrance may lie between graph cells. Preserve its real location;
	# only the short entrance edge departs from the cardinal grid.
	var result: Array[Vector2] = []
	if not start.is_finite() or not is_finite(travel_cost(world,start)): return result
	result = path(start.round(),destination)
	if not result.is_empty() and result[0] != start: result.push_front(start)
	return result


static func travel_cost(world: WorldState, position: Vector2) -> float:
	if not world.bounds.has_point(position):
		return INF
	var cell := Rect2(position - Vector2(0.5, 0.5), Vector2.ONE)
	var cost: float = 0.0
	for region: Dictionary in world.terrain:
		var area := Rect2(region.bounds[0], region.bounds[1], region.bounds[2], region.bounds[3])
		if area.intersects(cell):
			if not region.traversable:
				return INF
			cost = maxf(cost, region.movement_cost)
	return cost if cost > 0.0 else INF
