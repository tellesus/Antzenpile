extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")


func _steps(game: SimulationController, count: int) -> void:
	for index: int in count:
		game.advance(0.25)


func run(test: Object) -> bool:
	var game := Controller.new(3020)
	test.check(game.dispatch_scout("home", 0.0) and game.dispatch_scout("home", PI), "East and west scouts can search for differently exposed resources")
	game.advance(100.0)
	test.check(game.run.knowledge.nodes.has("known:carb_exposed") and game.run.knowledge.nodes.has("known:carb_sheltered"), "Both carbohydrate reports arrive before route investment")
	if not game.run.knowledge.nodes.has("known:carb_exposed") or not game.run.knowledge.nodes.has("known:carb_sheltered"):
		return true
	test.check(game.create_trail("home", "known:carb_exposed"), "Create east trail")
	var east: TrailSegmentState = game.run.trails.segments.segment_1
	var east_route: TrailRouteState = game.run.trails.routes.route_1
	test.check(east.exposure == 1.0 and game.run.rain.phase == "waiting", "East route crosses authored exposed terrain; no premature rain")
	game.advance(22.0)
	test.check(east.traffic >= 5 and game.run.rain.phase == "waiting", "One established trail cannot start rain")
	test.check(game.create_trail("home", "known:carb_sheltered"), "Create west trail")
	var west: TrailSegmentState = game.run.trails.segments.segment_2
	var west_route: TrailRouteState = game.run.trails.routes.route_2
	test.check(west.exposure == 0.0 and game.run.rain.phase == "waiting", "West route crosses sheltered terrain and must carry before rain")
	var starts: Array[int] = []
	game.rain.rain_started.connect(func() -> void: starts.append(1))
	var water_before_rain: float = game.run.colony.piles.home.resources.water
	for index: int in 200:
		if game.run.rain.phase == "raining":
			break
		game.advance(0.25)
	test.check(game.run.rain.phase == "raining" and starts.size() == 1 and east.traffic >= 5 and west.traffic >= 5, "Both successful routes trigger one rain event")
	test.check(game.run.colony.piles.home.resources.water > water_before_rain, "Rain deposits water on its first fixed tick")
	var root := Root.new()
	root.simulation = game
	var status: Dictionary = root.outward_status("home")
	test.check(status.rain_phase == "raining" and not status.has("terrain") and not status.has("exposure") and not status.has("world"), "Normal OUTWARD gets semantic weather without terrain truth")
	test.check(status.resources.water == game.run.colony.piles.home.resources.water and root.inward_status("home").resources.water == status.resources.water, "Both normal views receive the updated water store")
	root.free()
	test.check(game.set_trail_workers(east_route.id, 0) and game.set_trail_workers(west_route.id, 0), "Cancel both routes while cohorts return")
	for index: int in 140:
		if game.run.trails.cohorts.is_empty():
			break
		game.advance(0.25)
	test.check(game.run.trails.cohorts.is_empty() and game.run.rain.phase == "raining", "Both routes settle before matched chemistry comparison")
	east.pheromone_strength = 0.8
	west.pheromone_strength = 0.8
	east.route_familiarity = 0.6
	west.route_familiarity = 0.6
	_steps(game, 40)
	test.check(east.pheromone_strength < west.pheromone_strength * 0.6 and east.pheromone_strength > 0.0, "Exposed chemistry loses far more than sheltered chemistry")
	test.check(is_equal_approx(east.route_familiarity, west.route_familiarity) and east.route_familiarity > 0.58, "Route familiarity keeps its baseline slow decay under rain")
	var snapshot: Dictionary = game.run.to_dict()
	var copy := Controller.new()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot, "", true, true))
	var restore_ok: bool = copy.run.restore(parsed)
	test.check(snapshot.version == 5 and restore_ok and copy.run.to_dict() == snapshot, "Mid-rain version-5 JSON restore preserves exposure and remaining rain time")
	var before: Dictionary = copy.run.to_dict()
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.rain.elapsed_seconds = -1.0
	test.check(not copy.run.restore(invalid) and copy.run.to_dict() == before, "Invalid rain elapsed time rejects atomically")
	invalid = snapshot.duplicate(true)
	invalid.trails.segments[0].exposure = 0.5
	test.check(not copy.run.restore(invalid) and copy.run.to_dict() == before, "Forged exposure inconsistent with terrain rejects atomically")
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(10.0)
	test.check(game.run.to_dict() == paused, "Pause freezes rain and chemistry")
	game.toggle_pause()
	copy.set_time_scale(4)
	for index: int in 80:
		game.advance(0.25)
		copy.advance(0.0625)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Rain continuation is deterministic across save and simulation speed")
	for index: int in 300:
		if game.run.rain.phase == "finished":
			break
		game.advance(0.25)
	test.check(game.run.rain.phase == "finished" and game.run.rain.elapsed_seconds == 60.0 and starts.size() == 1, "Rain ends once after 60 simulated seconds")
	test.check(east.pheromone_strength < 0.1 and east.route_familiarity > 0.1, "Exposed route retains readable memory after chemical washout")
	var before_rebuild: float = east.pheromone_strength
	test.check(game.create_trail("home", "known:carb_exposed"), "Exposed route can be reinvested after rain")
	game.advance(25.0)
	test.check(east.pheromone_strength > before_rebuild and starts.size() == 1, "Successful post-rain traffic rebuilds exposed chemistry without another event")
	_test_water_accounting(test)
	return true


func _test_water_accounting(test: Object) -> void:
	var dry := Controller.new(3021)
	var initial: float = dry.run.colony.piles.home.resources.water
	dry.advance(1.0)
	test.check(dry.run.rain.phase == "waiting" and dry.run.colony.piles.home.resources.water == initial, "No water arrives before the rain event")
	var game := Controller.new(3021)
	game.run.rain.phase = "raining"
	game.advance(0.25)
	test.check(game.run.colony.piles.home.resources.water == initial + 0.0125, "First rain tick adds its proportional water share")
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(15.0)
	test.check(game.run.to_dict() == paused, "Paused rain does not add water")
	game.toggle_pause()
	game.advance(29.75)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot), "Mid-rain water store restores through the controller")
	for index: int in 119:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.run.rain.phase == "raining" and game.run.colony.piles.home.resources.water == initial + 2.9875, "Penultimate rain tick adds water without finishing early")
	game.advance(0.25)
	copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Mid-rain JSON continuation preserves exact water and event state")
	test.check(game.run.rain.phase == "finished" and game.run.colony.piles.home.resources.water == initial + 3.0, "Full 60-second event adds exactly three water units")
	var finished: float = game.run.colony.piles.home.resources.water
	game.advance(1.0)
	test.check(game.run.colony.piles.home.resources.water == finished, "Finished rain adds no further water")
	for scale: int in [4, 16, 64]:
		var fast := Controller.new(3021)
		fast.run.rain.phase = "raining"
		fast.set_time_scale(scale)
		fast.advance(60.0 / float(scale))
		test.check(fast.run.rain.phase == "finished" and fast.run.colony.piles.home.resources.water == initial + 3.0, "Rain total uses simulated time at %d×" % scale)
