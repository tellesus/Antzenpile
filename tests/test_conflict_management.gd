extends RefCounted
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func run(test: Object) -> bool:
	var game: SimulationController = Defense.new().ready_game()
	var root := Root.new(); root.simulation = game
	var baseline: Dictionary = Defense.new().snapshot(game)
	var before: Dictionary = game.run.to_dict()
	test.check(not game.journey_response.set_force("route_1", 13) and game.run.to_dict() == before, "Invalid force budget is atomic")
	test.check(root.respond_to_journey("force_16", "route_1").accepted, "Known threat accepts a persistent force budget")
	test.check(game.run.journey_response.defense.sent == 16 and game.run.journey_response.defense.initial_sent == 16, "Initial selected force physically departs with paid labor")
	test.check(not root.outward_status("home").journey_response.reinforcement_pending, "Initial force is not mislabeled as pending reinforcement")
	test.check(game.journey_response.set_force("route_1", 24) and game.run.journey_response.defense.extra_workers == 4, "Raised budget sends one real reinforcement batch")
	var twin := Controller.new()
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Force intent and travel restore")
	while game.run.journey_response.active():
		game.advance(0.25); twin.advance(0.25)
		test.check(game.run.to_dict() == twin.run.to_dict(), "Physical budget continuation is exact")
	test.check(game.run.journey_response.orders.targets.route_1 == 0, "Returned ending stops further automatic attacks")
	game.advance(60); test.check(not game.run.journey_response.active(), "No repeated swarm after settlement")
	game = Controller.new(); game.restore_snapshot(baseline); root.simulation = game
	game.run.colony.piles.home.resources.carbohydrate = 0
	test.check(game.journey_response.set_force("route_1", 20) and not game.run.journey_response.active(), "Unfunded choice waits without manufacturing workers")
	test.check(root.outward_status("home").journey_response.force_orders.route_1 == 20, "Waiting budget is immediately known locally")
	test.check(game.journey_response.set_force("route_1", 12) and game.run.journey_response.orders.targets.route_1 == 12, "Replacement changes the same order")
	test.check(game.journey_response.set_force("route_1", 0), "Cancel waiting intent without a departure")
	game.run.colony.piles.home.resources.carbohydrate = 30; game.advance(2)
	test.check(not game.run.journey_response.active(), "Canceled waiting order never launches later")
	for malformed: Variant in [-1, 13, 28, "12"]:
		var broken: Dictionary = baseline.duplicate(true); broken.journey_response.orders = {"route_1":malformed}
		test.check(not twin.restore_snapshot(broken), "Malformed saved force budget rejected")
	var legacy: Dictionary = baseline.duplicate(true); legacy.journey_response.erase("orders"); legacy.journey_response.defense.erase("initial_sent")
	test.check(twin.restore_snapshot(legacy), "Legacy absence defaults to no standing attack")
	root.free()
	return true
