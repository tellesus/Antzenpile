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
	test.check(not game.journey_response.set_force("route_1", game.run.colony.piles.home.workers_total + game.run.pending_for_pile("home") + 1) and game.run.to_dict() == before, "Force beyond the known local workforce rejects atomically")
	test.check(root.respond_to_journey("force_16", "route_1").accepted, "Known threat accepts a persistent force budget")
	test.check(game.run.journey_response.defense.sent == 16 and game.run.journey_response.defense.initial_sent == 16, "Initial selected force physically departs with paid labor")
	test.check(not root.outward_status("home").journey_response.reinforcement_pending, "Initial force is not mislabeled as pending reinforcement")
	test.check(game.journey_response.set_force("route_1", 24) and game.run.journey_response.defense.extra_workers == 8, "Raised budget sends the selected eight additional workers with real travel")
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
	for malformed: Variant in [-1, 1.5, WorkerLedger.MAX_COUNT + 1, "12"]:
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
	view.journey_command = root.respond_to_journey; view.trail_set_command = root.set_trail_target
	view._signals = root.sensory_snapshot("home"); view._status = root.outward_status("home")
	view.selected_id = "threat:route_1"
	var before: Dictionary = game.run.to_dict()
	view._pointer_press(view._conflict_rect("conflict_send").get_center(), "mouse")
	view._pointer_press(view._conflict_rect("draft_goal").get_center(), "mouse")
	test.check(view.conflict.editing and view.conflict.goal == "hunt" and game.run.to_dict() == before, "Choosing workers and a goal is a free draft until ORDER")
	game.run.colony.piles.home.resources.carbohydrate = 0
	view.conflict.amount = 20
	view._pointer_press(view._conflict_rect("draft_commit").get_center(), "touch")
	test.check(not game.run.journey_response.active() and game.run.journey_response.orders.targets.route_1 == 20, "Explicit order waits when unfunded without a partial departure")
	view._status = root.outward_status("home")
	view._pointer_press(view._conflict_rect("conflict_retreat").get_center(), "mouse")
	game.run.colony.piles.home.resources.carbohydrate = 30; game.advance(1)
	test.check(not game.run.journey_response.active() and game.run.journey_response.orders.targets.route_1 == 0 and game.run.journey_response.orders.recruitment.is_empty(), "Radial retreat cancels queued recruitment before food returns")
	view._status = root.outward_status("home")
	for finding: String in ["", "surface"]:
		view._status.journey_response.reports.route_1 = {"finding": finding}
		view._status.trails[0].surface_warning = finding == "surface"
		var route: Dictionary = view._conflict_route()
		before = game.run.to_dict()
		view._pointer_press(view._conflict_rect("conflict_send").get_center(), "touch")
		test.check(not view.conflict.reason("conflict_send",route,view._status).is_empty() and game.run.to_dict() == before, "Unavailable response explains delivered %s evidence without dispatch" % finding)
	view.free()
