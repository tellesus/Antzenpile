class_name SimWorld
extends RefCounted
## The physical world: seeded terrain, food, one colony and a tick counter.
## Headless and deterministic. Must never touch scenes, rendering or input.

enum Terrain { SOIL, GRASS, STONE, WATER, SAND }

const TICKS_PER_SECOND := 10
const UNREACHABLE := 1.0e9
const PATCH_INTERVAL_TICKS := 900
const _NX: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
const _NY: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]

var world_seed: int
var width: int
var height: int
var tick: int = 0
var terrain: PackedByteArray
var passable: PackedByteArray
var food: PackedFloat32Array
var food_total_spawned: float = 0.0
var nest_cell: Vector2i
var nest_dist: PackedFloat32Array
var colony: Colony
var rng := RandomNumberGenerator.new()


func _init(p_seed: int, p_width: int = 200, p_height: int = 200, start_ants: int = 120) -> void:
	world_seed = p_seed
	width = p_width
	height = p_height
	rng.seed = p_seed
	nest_cell = Vector2i(width / 2, height / 2)
	_generate_terrain()
	nest_dist = compute_distance_field(nest_cell)
	food = PackedFloat32Array()
	food.resize(width * height)
	var reach: float = minf(width, height) * 0.5 - 6.0
	# Two patches close enough to find unaided; the rest reward exploring.
	for i in 2:
		spawn_patch(minf(12.0, reach * 0.25), minf(22.0, reach * 0.45))
	for i in 5:
		spawn_patch(minf(34.0, reach * 0.5), minf(62.0, reach * 0.8))
	for i in 5:
		spawn_patch(minf(62.0, reach * 0.8), reach)
	colony = Colony.new(self, start_ants)


func step() -> void:
	tick += 1
	colony.step()
	if tick % PATCH_INTERVAL_TICKS == 0:
		spawn_patch(30.0, minf(width, height) * 0.5 - 6.0)


func index_of(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain_at(cell: Vector2i) -> int:
	return terrain[index_of(cell)]


## Places one cluster of food between two distances from the nest.
## Returns false if no suitable spot was found.
func spawn_patch(min_dist: float, max_dist: float) -> bool:
	for attempt in 40:
		var angle: float = rng.randf() * TAU
		var d: float = rng.randf_range(min_dist, max_dist)
		var cx: int = nest_cell.x + int(cos(angle) * d)
		var cy: int = nest_cell.y + int(sin(angle) * d)
		if cx < 3 or cy < 3 or cx >= width - 3 or cy >= height - 3:
			continue
		var ci: int = cy * width + cx
		if passable[ci] == 0 or nest_dist[ci] >= UNREACHABLE:
			continue
		var radius: int = rng.randi_range(2, 3)
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy > radius * radius:
					continue
				var i: int = (cy + dy) * width + cx + dx
				if passable[i] == 0 or nest_dist[i] >= UNREACHABLE:
					continue
				var amount: float = float(rng.randi_range(4, 9))
				food[i] += amount
				food_total_spawned += amount
		return true
	return false


## Walking distance from one cell to every reachable cell (8-connected).
func compute_distance_field(from: Vector2i) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(width * height)
	dist.fill(UNREACHABLE)
	var start: int = index_of(from)
	dist[start] = 0.0
	var queue := PackedInt32Array([start])
	var head := 0
	# Label-correcting search: a cell is re-queued whenever a shorter way in is found.
	while head < queue.size():
		var ci: int = queue[head]
		head += 1
		var cx: int = ci % width
		var cy: int = ci / width
		var d: float = dist[ci]
		for k in 8:
			var nx: int = cx + _NX[k]
			var ny: int = cy + _NY[k]
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var ni: int = ny * width + nx
			if passable[ni] == 0:
				continue
			var nd: float = d + (1.0 if k < 4 else 1.41421)
			if nd < dist[ni] - 0.001:
				dist[ni] = nd
				queue.append(ni)
	return dist


## A stable fingerprint of the whole world state, used by determinism tests.
func state_hash() -> int:
	return hash([hash(terrain), hash(food), world_seed, width, height, tick,
		nest_cell, food_total_spawned, colony.state_hash()])


func _generate_terrain() -> void:
	var ground := FastNoiseLite.new()
	ground.seed = world_seed
	ground.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ground.frequency = 0.02
	ground.fractal_octaves = 3

	var wet := FastNoiseLite.new()
	wet.seed = world_seed + 1
	wet.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wet.frequency = 0.012

	terrain = PackedByteArray()
	terrain.resize(width * height)
	for y in height:
		for x in width:
			var g: float = ground.get_noise_2d(x, y)
			var w: float = wet.get_noise_2d(x, y)
			var t: int = Terrain.SOIL
			if w > 0.55:
				t = Terrain.WATER
			elif g > 0.45:
				t = Terrain.STONE
			elif g > 0.05:
				t = Terrain.GRASS
			elif g < -0.45:
				t = Terrain.SAND
			terrain[y * width + x] = t

	# The nest always sits on open soil.
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := nest_cell + Vector2i(dx, dy)
			if in_bounds(c):
				terrain[index_of(c)] = Terrain.SOIL

	passable = PackedByteArray()
	passable.resize(width * height)
	for i in width * height:
		passable[i] = 0 if terrain[i] == Terrain.WATER else 1
