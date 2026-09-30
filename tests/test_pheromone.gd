extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Fixture = preload("res://tests/test_observations.gd")
const Config = preload("res://data/trails/default_trails.tres")
const Root = preload("res://src/core/game_root.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Scent = preload("res://src/presentation/outward/trail_visual.gd")


func _known_game() -> SimulationController:
	var game: SimulationController = Fixture.new().fixture()
	game.advance(85.0)
	return game


func _steps(game: SimulationController, count: int) -> void:
	for index: int in count:
		game.advance(0.25)


func run(test: Object) -> bool:
	var game := _known_game()
	test.check(game.create_trail("home", "known:carb_exposed"), "Known destination supports a chemical route")
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	var leg: int = Config.leg_ticks(segment.start.distance_to(segment.end))
	test.check(segment.pheromone_strength == 0.0 and segment.traffic == 0 and segment.route_familiarity == 0.0, "New segment starts chemically blank")
	_steps(game, 2 * leg + 1)
	test.check(segment.pheromone_strength > 0.17 and segment.pheromone_strength <= 1.0 and segment.traffic == 5, "Five loaded returning workers reinforce once")
	test.check(segment.route_familiarity > 0.0 and segment.route_familiarity < segment.pheromone_strength, "Familiarity now gains separately and more slowly")
	var root := Root.new()
	root.simulation = game
	var summary: Dictionary = root.trail_summaries("home")[0]
	test.check(summary.pheromone_strength == segment.pheromone_strength and not summary.has("start") and not summary.has("end") and not summary.has("traffic"), "Normal view receives detached scent strength without route geometry or raw traffic")
	summary.pheromone_strength = 0.0
	test.check(segment.pheromone_strength > 0.0, "Presentation cannot mutate segment chemistry")
	root.free()
	var saved: Dictionary = game.run.to_dict()
	var restored := Controller.new()
	test.check(restored.run.restore(JSON.parse_string(JSON.stringify(saved, "", true, true))) and restored.run.to_dict() == saved, "Nonzero chemistry and traffic survive JSON continuation")
	var before: Dictionary = restored.run.to_dict()
	for bad_strength: float in [-0.01, 1.01, NAN]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid.trails.segments[0].pheromone_strength = bad_strength
		test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Out-of-range or nonfinite pheromone rejects atomically")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.trails.segments[0].traffic = -1
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Negative traffic rejects atomically")
	test.check(game.set_trail_workers("route_1", 0), "Cancel prevents new departures")
	_steps(game, 2 * leg + 1)
	var idle_strength: float = segment.pheromone_strength
	var idle_traffic: int = segment.traffic
	test.check(game.run.trails.cohorts.is_empty(), "In-flight workers return before disuse check")
	_steps(game, 360)
	test.check(segment.pheromone_strength < idle_strength * 0.51 and segment.pheromone_strength > 0.0 and segment.traffic == idle_traffic, "Inactive segment halves over 90 simulated seconds without traffic")
	game.toggle_pause()
	var paused_strength: float = segment.pheromone_strength
	_steps(game, 400)
	test.check(segment.pheromone_strength == paused_strength, "Paused clock does not decay chemistry")
	var empty := _known_game()
	empty.run.world.nodes.carb_exposed.position = Vector2(35, 35)
	test.check(empty.create_trail("home", "known:carb_exposed"), "Stale estimate creates empty-return fixture")
	_steps(empty, 2 * leg + 1)
	test.check(empty.run.trails.segments.segment_1.pheromone_strength == 0.0 and empty.run.trails.segments.segment_1.traffic == 0, "Empty return does not reinforce or count successful traffic")
	var saturated := _known_game()
	saturated.create_trail("home", "known:carb_exposed")
	saturated.run.trails.segments.segment_1.pheromone_strength = 0.99
	_steps(saturated, 2 * leg + 1)
	test.check(saturated.run.trails.segments.segment_1.pheromone_strength == 1.0, "Reinforcement clamps at one")
	var speed_states: Array[Dictionary] = []
	for scale: int in [1, 4, 16, 64]:
		var copy := Controller.new()
		test.check(copy.run.restore(saved) and copy.set_time_scale(scale), "Scale fixture restores chemistry")
		for index: int in 160:
			copy.advance(0.25 / scale)
		copy.set_time_scale(1)
		speed_states.append(copy.run.to_dict())
	for state: Dictionary in speed_states:
		test.check(state == speed_states[0], "Equal simulated duration yields identical chemistry and traffic")
	var size := Vector2(1280, 720)
	var signal_data: Dictionary = {"id": "carb", "source_knowledge_id": "known:carb_exposed", "bearing": 0.0,
		"estimated_distance": 10.0, "strength": 0.5, "uncertainty_radius": 1.0}
	var placed: Array[Dictionary] = Panorama.project([signal_data], 0.0, size)
	var route: Dictionary = {"destination_knowledge_id": "known:carb_exposed", "pheromone_strength": 0.8}
	test.check(Scent.strokes([route], placed, size).size() == 1, "Strong scent is one coherent screen-space link")
	route.pheromone_strength = 0.2
	test.check(Scent.strokes([route], placed, size).size() == 4, "Weak scent breaks into bounded fragments")
	route.pheromone_strength = 0.05
	test.check(Scent.strokes([route], placed, size).is_empty(), "Nearly lost scent leaves negative space")
	route.pheromone_strength = 0.8
	test.check(Scent.strokes([route], Panorama.project([signal_data], PI, size), size).is_empty(), "Rear-facing evidence draws no scent link")
	test.check(Scent.strokes([route], [], size).is_empty(), "Unknown or absent evidence draws no scent link")
	return true
