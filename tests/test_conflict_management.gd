extends RefCounted
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")

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
	_check_order_interface(test, root, baseline)
	root.free()
	return true


func _check_order_interface(test: Object, root: Node, baseline: Dictionary) -> void:
	var game := Controller.new(); game.restore_snapshot(baseline); root.simulation = game
	var view := View.new(); test.get_root().add_child(view)
	view.journey_command = root.respond_to_journey
	view._signals = root.sensory_snapshot("home"); view._status = root.outward_status("home")
	view.selected_id = "threat:route_1"
	view._pointer_press(view._goal_rect("hunt").get_center(), "mouse")
	test.check(not game.run.journey_response.active() and game.run.journey_response.orders.goals.route_1 == "hunt", "Goal choice remains separate from committing a force")
	var before: Dictionary = game.run.to_dict()
	view._pointer_press(view._journey_rect("journey_defend").get_center(), "touch")
	test.check(game.run.to_dict() == before, "Staffing explanation has no invisible duplicate dispatch action")
	view._status.trails[0].desired_workers = 0
	view._status.journey_response.outcomes.route_1 = {"outcome": "withdrew"}
	test.check(view._button_at(view._journey_rect("journey_defend").get_center()) == "journey_panel", "Staffing explanation after a failed attempt cannot trigger an invisible avoidance action")
	view._status = root.outward_status("home")
	game.run.colony.piles.home.resources.carbohydrate = 0
	view._pointer_press(view._force_rect(20).get_center(), "touch")
	test.check(not game.run.journey_response.active() and game.run.journey_response.orders.targets.route_1 == 20, "Explicit total order waits when unfunded without a partial departure")
	view._status = root.outward_status("home")
	view._pointer_press(view._journey_rect("journey_investigate").get_center(), "mouse")
	game.run.colony.piles.home.resources.carbohydrate = 30; game.advance(1)
	test.check(not game.run.journey_response.active() and game.run.journey_response.orders.targets.route_1 == 0, "Visible cancel prevents a queued order launching after food returns")
	view._status = root.outward_status("home")
	for finding: String in ["", "foreign", "surface"]:
		view._status.journey_response.reports.route_1 = {"finding": finding}
		view._status.trails[0].surface_warning = finding == "surface"
		var route: Dictionary = view._selected_route(view._selected_signal())
		before = game.run.to_dict()
		view._pointer_press(view._force_rect(12).get_center(), "touch")
		test.check(not view._can_mobilize(route) and not view._mobilize_block_reason(route).is_empty() and game.run.to_dict() == before, "Unavailable defense explains delivered %s evidence and absorbs old force coordinates" % finding)
	view.free()
