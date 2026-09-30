extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Fixture = preload("res://tests/test_observations.gd")
const Config = preload("res://data/trails/default_trails.tres")
const System = preload("res://src/sim/trails/trail_system.gd")
const Root = preload("res://src/core/game_root.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Scent = preload("res://src/presentation/outward/trail_visual.gd")


func _game() -> SimulationController:
	var game: SimulationController = Fixture.new().fixture()
	game.advance(85.0)
	game.create_trail("home", "known:carb_exposed")
	return game


func _steps(game: SimulationController, count: int) -> void:
	for index: int in count:
		game.advance(0.25)


func run(test: Object) -> bool:
	var game := _game()
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	var leg: int = Config.leg_ticks(segment.start.distance_to(segment.end))
	_steps(game, 2 * leg + 1)
	test.check(segment.route_familiarity > 0.039 and segment.route_familiarity < 0.041 and segment.pheromone_strength > segment.route_familiarity, "Loaded return teaches slower familiarity independently of chemistry")
	var saved: Dictionary = game.run.to_dict()
	var copy := Controller.new()
	test.check(copy.run.restore(JSON.parse_string(JSON.stringify(saved, "", true, true))) and copy.run.to_dict() == saved, "Nonzero familiarity survives full-precision snapshot")
	var before: Dictionary = copy.run.to_dict()
	for bad: float in [-0.01, 1.01, NAN]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid.trails.segments[0].route_familiarity = bad
		test.check(not copy.run.restore(invalid) and copy.run.to_dict() == before, "Invalid familiarity rejects atomically")
	test.check(game.set_trail_workers("route_1", 0), "Cancel stops new departures before divergence")
	_steps(game, 2 * leg + 1)
	var starting_chemical: float = segment.pheromone_strength
	var starting_memory: float = segment.route_familiarity
	_steps(game, 360)
	test.check(segment.pheromone_strength < starting_chemical * 0.51 and segment.route_familiarity > starting_memory * 0.93, "Ninety seconds halve chemistry while preserving most familiarity")
	var root := Root.new()
	root.simulation = game
	var summary: Dictionary = root.trail_summaries("home")[0]
	test.check(summary.route_familiarity == segment.route_familiarity and not summary.has("start") and not summary.has("end"), "Normal route summary copies only approved memory value")
	summary.route_familiarity = 1.0
	test.check(segment.route_familiarity < 1.0, "Presentation mutation cannot change familiarity")
	root.free()
	var no_memory := _game()
	var with_memory := _game()
	var estimate: Vector2 = no_memory.run.trails.routes.route_1.estimated_destination
	no_memory.run.world.nodes.carb_exposed.position = estimate + Vector2(2.25, 0)
	with_memory.run.world.nodes.carb_exposed.position = estimate + Vector2(2.25, 0)
	with_memory.run.trails.segments.segment_1.route_familiarity = 0.6
	test.check(System.reliability(with_memory.run.trails.segments.segment_1) == 0.3, "Memory contributes to bounded route reliability without chemical strength")
	_steps(no_memory, leg + 1)
	_steps(with_memory, leg + 1)
	test.check(no_memory.run.trails.cohorts.cohort_1.payload == 0.0 and with_memory.run.trails.cohorts.cohort_1.payload == 5.0, "Memory broadens endpoint tolerance only at source interaction")
	var signal_data: Dictionary = {"id": "carb", "source_knowledge_id": "known:carb_exposed", "bearing": 0.0,
		"estimated_distance": 10.0, "strength": 0.5, "uncertainty_radius": 1.0}
	var placed: Array[Dictionary] = Panorama.project([signal_data], 0.0, Vector2(1280, 720))
	var route: Dictionary = {"destination_knowledge_id": "known:carb_exposed", "pheromone_strength": 0.0, "route_familiarity": 0.6}
	var ghost: Array[Dictionary] = Scent.strokes([route], placed, Vector2(1280, 720))
	test.check(ghost.size() == 4 and ghost[0].ghost, "Chemical washout leaves a sparse memory ghost")
	route.route_familiarity = 0.09
	test.check(Scent.strokes([route], placed, Vector2(1280, 720)).is_empty(), "Weak memory returns to negative space")
	route.route_familiarity = 0.6
	test.check(Scent.strokes([route], Panorama.project([signal_data], PI, Vector2(1280, 720)), Vector2(1280, 720)).is_empty(), "Ghost requires a currently visible known signal")
	return true
