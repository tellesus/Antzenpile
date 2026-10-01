extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")


func run(test: Object) -> bool:
	var game := Controller.new(3030)
	test.check(game.dispatch_scout("home", 0.0) and game.dispatch_scout("home", -PI / 2.0), "Water-access run dispatches ordinary scouts")
	if not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:carb_exposed") and game.run.knowledge.nodes.has("known:water_01"), 220.0):
		test.check(false, "Starting exposed carbohydrate and water reports arrive")
		return true
	test.check(game.create_trail("home", "known:carb_exposed") and game.create_trail("home", "known:water_01"), "Exposed routes can be invested")
	var water_route: TrailRouteState = game.run.trails.find_route("home", "known:water_01")
	var carb_route: TrailRouteState = game.run.trails.find_route("home", "known:carb_exposed")
	test.check(game.set_trail_workers(water_route.id, 20) and game.set_trail_workers(carb_route.id, 15), "High labor drains the starting water source")
	test.check(_until(game, func() -> bool: return water_route.status == "depleted" and water_route.active_workers == 0, 800.0), "Empty water return stops the route after travelers come home")
	var source: WorldNodeState = game.run.world.nodes.water_01
	test.check(source.quantity == 0.0 and game.run.rain.phase == "waiting" and game.run.knowledge.temporal_hint("known:water_01").last_return_empty, "Water is physically dry, rain waits, and colony memory reports an empty return")
	game.advance(30.0)
	test.check(source.quantity == 0.0 and water_route.status == "depleted", "Dry weather does not refill or secretly reopen the route")
	if not game.dispatch_scout("home", PI) or not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:carb_sheltered"), 220.0):
		test.check(false, "Sheltered carbohydrate report arrives")
		return true
	test.check(game.create_trail("home", "known:carb_sheltered"), "Sheltered route can establish the first rain trigger")
	test.check(_until(game, func() -> bool: return game.run.rain.phase == "raining", 100.0), "Ordinary sheltered and exposed traffic begins rain")
	test.check(is_equal_approx(source.quantity, 0.1) and water_route.status == "depleted" and game.run.knowledge.temporal_hint("known:water_01").last_return_empty, "First rain tick refills physical water without refreshing memory or route")
	var root := Root.new()
	root.simulation = game
	var outward: Dictionary = root.outward_status("home")
	test.check(not outward.has("world") and not outward.has("water_source_quantity") and outward.rain_phase == "raining", "Normal OUTWARD reports weather without source truth")
	root.free()
	game.advance(15.0)
	test.check(is_equal_approx(source.quantity, 6.1) and water_route.status == "depleted", "Exterior water accumulates steadily during rain while depleted traffic stays stopped")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot) and copy.run.to_dict() == game.run.to_dict(), "Mid-rain world quantity restores through the version-5 snapshot")
	game.advance(10.0)
	copy.advance(10.0)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Mid-rain continuation refills the same physical quantity after reload")
	test.check(game.recheck_trail(water_route.id), "Player can explicitly recheck the depleted water route")
	test.check(water_route.status == "active" and game.run.knowledge.temporal_hint("known:water_01").last_return_empty, "Recheck changes intent without instantly changing returned evidence")
	var delivered_before: float = water_route.delivered_total
	test.check(_until(game, func() -> bool: return water_route.delivered_total > delivered_before, 100.0), "Rechecked workers bring rain-fed exterior water home")
	test.check(not game.run.knowledge.temporal_hint("known:water_01").last_return_empty and game.run.colony.piles.home.workers.invariant_holds(), "Loaded return updates knowledge and preserves the worker ledger")
	_test_capacity_and_pause(test)
	return true


func _test_capacity_and_pause(test: Object) -> void:
	var dry := Controller.new(3043)
	dry.run.world.nodes.water_01.quantity = 0.0
	dry.run.world.nodes.water_01.active = false
	dry.run.rain.phase = "raining"
	dry.advance(60.0)
	test.check(is_equal_approx(dry.run.world.nodes.water_01.quantity, 24.0) and dry.run.world.nodes.water_01.active and dry.run.rain.phase == "finished", "One complete front physically restores twenty-four water units to an empty source")
	var game := Controller.new(3042)
	var source: WorldNodeState = game.run.world.nodes.water_01
	source.quantity = 99.95
	game.run.rain.phase = "raining"
	game.toggle_pause()
	var frozen: Dictionary = game.run.to_dict()
	game.advance(10.0)
	test.check(game.run.to_dict() == frozen, "Pause prevents rain-fed source renewal")
	game.toggle_pause()
	game.advance(0.25)
	test.check(is_equal_approx(source.quantity, 100.0) and source.quantity <= 100.0, "Exterior refill respects the authored source capacity")
	game.set_time_scale(16)
	game.advance(60.0 / 16.0)
	test.check(is_equal_approx(source.quantity, 100.0) and source.quantity <= 100.0 and game.run.rain.phase == "finished", "Fast simulation cannot exceed source capacity or extend the front")
	game.advance(100.0)
	test.check(is_equal_approx(source.quantity, 100.0) and source.quantity <= 100.0, "Dry interval does not add exterior water")


func _until(game: SimulationController, predicate: Callable, limit_seconds: float) -> bool:
	for tick: int in roundi(limit_seconds / 0.25):
		if predicate.call():
			return true
		game.advance(0.25)
	return predicate.call()
