extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")


func run(test: Object) -> bool:
	var game := Controller.new(3020)
	var starts: Array[int] = []
	game.rain.rain_started.connect(func() -> void: starts.append(1))
	test.check(game.dispatch_scout("home", 0.0) and game.dispatch_scout("home", PI), "Recurring-weather fixture dispatches east and west scouts")
	game.advance(100.0)
	test.check(game.create_trail("home", "known:carb_exposed"), "Exposed route starts the weather fixture")
	game.advance(22.0)
	test.check(game.create_trail("home", "known:carb_sheltered"), "Sheltered route completes the weather fixture")
	test.check(_until(game, func() -> bool: return game.run.rain.phase == "raining", 60.0), "Established routes trigger the first front")
	test.check(starts.size() == 1 and game.run.rain.fronts_completed == 0, "First front starts once")
	test.check(game.set_trail_workers("route_1", 0) and game.set_trail_workers("route_2", 0), "Player recalls both routes before the later front")
	test.check(_until(game, func() -> bool: return game.run.rain.phase == "finished", 80.0), "First front finishes after sixty simulated seconds")
	var first_finish_tick: int = game.run.clock.tick_count
	var next_tick: int = game.run.rain.next_start_tick
	test.check(game.run.rain.fronts_completed == 1 and next_tick == first_finish_tick + 2400, "Finished front schedules a later physical weather event")
	var old: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	old.rain.erase("fronts_completed")
	old.rain.erase("next_start_tick")
	var legacy := Controller.new()
	test.check(legacy.restore_snapshot(old) and legacy.run.rain.fronts_completed == 1 and legacy.run.rain.next_start_tick == first_finish_tick + 2400, "Older finished version-5 save starts a fresh dry interval")
	var bad: Dictionary = game.run.to_dict()
	bad.rain.next_start_tick = str(first_finish_tick)
	var stable: Dictionary = game.run.to_dict()
	test.check(not game.restore_snapshot(bad) and game.run.to_dict() == stable, "Due or past rain tick rejects atomically on restore")
	bad = stable.duplicate(true)
	bad.rain.fronts_completed = 0
	test.check(not game.restore_snapshot(bad) and game.run.to_dict() == stable, "Finished weather without a completed front rejects atomically")
	game.advance(float(next_tick - game.run.clock.tick_count - 1) * 0.25)
	test.check(game.run.clock.tick_count == next_tick - 1 and game.run.rain.phase == "finished" and starts.size() == 1, "Dry interval holds to the last tick before recurrence")
	var east: TrailSegmentState = game.run.trails.segments.segment_1
	var west: TrailSegmentState = game.run.trails.segments.segment_2
	east.pheromone_strength = 0.8
	west.pheromone_strength = 0.8
	east.route_familiarity = 0.6
	west.route_familiarity = 0.6
	var before_second: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(before_second), "Dry-boundary save restores exactly")
	game.set_time_scale(4)
	game.advance(0.0625)
	game.set_time_scale(1)
	copy.advance(0.25)
	test.check(game.run.clock.tick_count == next_tick and game.run.rain.phase == "raining" and starts.size() == 2, "Second front starts at the authored fixed tick under 4×")
	test.check(game.run.to_dict() == copy.run.to_dict(), "Second-front boundary continues exactly after reload")
	var root := Root.new()
	root.simulation = game
	var status: Dictionary = root.outward_status("home")
	test.check(status.rain_phase == "raining" and not status.has("next_start_tick") and not status.has("fronts_completed") and not status.has("weather_schedule"), "Normal OUTWARD gets weather state without the physical schedule")
	root.free()
	game.advance(10.0)
	copy.advance(10.0)
	test.check(east.pheromone_strength < west.pheromone_strength * 0.6 and is_equal_approx(east.route_familiarity, west.route_familiarity), "Later front again washes exposed chemistry while familiarity persists")
	test.check(game.run.to_dict() == copy.run.to_dict(), "Mid-second-front continuation stays exact")
	test.check(game.create_trail("home", "known:carb_exposed") and game.set_trail_workers("route_1", 8), "Player can recommit more labor to exposed route during later rain")
	var traffic_before: int = east.traffic
	game.advance(45.0)
	test.check(east.traffic > traffic_before and game.run.colony.piles.home.workers.count("trail:route_1") == 8, "Recommitted workers rebuild traffic through recurring weather")
	test.check(game.run.rain.phase == "raining" and game.run.rain.fronts_completed == 1, "Second rain has not ended early")
	test.check(_until(game, func() -> bool: return game.run.rain.phase == "finished", 20.0), "Second front finishes after sixty simulated seconds")
	test.check(game.run.rain.fronts_completed == 2 and game.run.rain.next_start_tick == game.run.clock.tick_count + 2400 and starts.size() == 2, "A third front is scheduled without duplicate second start")
	test.check(game.run.colony.piles.home.workers.invariant_holds(), "Recurring weather and labor response conserve workers")
	_test_exact_water_and_pause(test)
	return true


func _test_exact_water_and_pause(test: Object) -> void:
	var game := Controller.new(3035)
	game.run.colony.piles.home.brood_cohorts.clear()
	game.run.rain.phase = "finished"
	game.run.rain.elapsed_seconds = 60.0
	game.run.rain.fronts_completed = 1
	game.run.rain.next_start_tick = 2
	var original: float = game.run.colony.piles.home.resources.water
	game.advance(0.25)
	test.check(game.run.rain.phase == "finished" and game.run.colony.piles.home.resources.water == original, "No water arrives before the next front")
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(100.0)
	test.check(game.run.to_dict() == paused, "Pause freezes the recurring front boundary")
	game.toggle_pause()
	game.advance(0.25)
	test.check(game.run.rain.phase == "raining" and game.run.colony.piles.home.resources.water == original + 0.0125, "Later front deposits water steadily from its first tick")
	game.advance(59.75)
	test.check(game.run.rain.phase == "finished" and game.run.rain.fronts_completed == 2 and game.run.colony.piles.home.resources.water == original + 3.0, "Each complete front adds exactly three water without active brood")
	for scale: int in [4, 16, 64]:
		var fast := Controller.new(3035)
		fast.run.colony.piles.home.brood_cohorts.clear()
		fast.run.rain.phase = "finished"
		fast.run.rain.elapsed_seconds = 60.0
		fast.run.rain.fronts_completed = 1
		fast.run.rain.next_start_tick = 1
		fast.set_time_scale(scale)
		fast.advance(60.0 / float(scale))
		test.check(fast.run.rain.phase == "finished" and fast.run.rain.fronts_completed == 2 and fast.run.colony.piles.home.resources.water == original + 3.0, "Recurring front uses simulated time at %d×" % scale)


func _until(game: SimulationController, predicate: Callable, limit_seconds: float) -> bool:
	for step: int in int(limit_seconds / 0.25):
		if predicate.call():
			return true
		game.advance(0.25)
	return predicate.call()
