class_name SimWorld
extends RefCounted
## The physical world: a seeded grid of terrain plus a tick counter.
## Headless and deterministic. Must never touch scenes, rendering or input.

enum Terrain { SOIL, GRASS, STONE, WATER, SAND }

const TICKS_PER_SECOND := 10

var world_seed: int
var width: int
var height: int
var tick: int = 0
var terrain: PackedByteArray
var nest_cell: Vector2i


func _init(p_seed: int, p_width: int = 200, p_height: int = 200) -> void:
	world_seed = p_seed
	width = p_width
	height = p_height
	nest_cell = Vector2i(width / 2, height / 2)
	_generate_terrain()


func step() -> void:
	tick += 1


func index_of(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain_at(cell: Vector2i) -> int:
	return terrain[index_of(cell)]


## A stable fingerprint of the whole world state, used by determinism tests.
func state_hash() -> int:
	var h: int = hash(terrain)
	h = hash([h, world_seed, width, height, tick, nest_cell])
	return h


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
