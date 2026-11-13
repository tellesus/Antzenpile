extends RefCounted
const Fixture = preload("res://tests/test_swarm.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Counter = preload("res://tests/test_rival_counterplay.gd")
const Contact = preload("res://tests/test_rival_contact.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func run(test: Object) -> bool:
	var small: SimulationController = Contact.new().fixture()
	test.check(small.set_trail_workers("route_1",1), "A deliberate one-worker target uses the existing ledger")
	for tick: int in 2400:
		small.advance(0.25)
		if small.run.trails.routes.route_1.conflict_report == "withdrew": break
	test.check(small.run.trails.routes.route_1.conflict_report == "withdrew" and small.run.trails.routes.route_1.desired_workers == 0, "A group unable to detach a messenger returns withdrawal rather than a perpetual contested warning")
	var game: SimulationController = Fixture.new().forming_fixture()
	var root := Root.new(); root.simulation = game
	var route: TrailRouteState = game.run.trails.routes.route_1
	for tick: int in 2400:
		game.advance(0.25)
		if route.conflict_report in ["withdrew","dispersed"]: break
	test.check(route.desired_workers == 0 and route.settled_conflict_serial == route.conflict_serial and route.conflict_serial > 0, "Actual returned retreat pauses standing recruitment once for this encounter")
	var serial: int = game.run.swarm.serial
	test.check(not root.trail_summaries("home")[0].journey_alarm and route.reported_losses > 0, "Returned settlement retires current urgency while preserving casualties/history")
	var copy := Controller.new(); test.check(copy.restore_snapshot(Defense.new().snapshot(game)), "Returned pause/serial/losses save together")
	var late := Controller.new(); late.restore_snapshot(Defense.new().snapshot(game))
	test.check(late.set_trail_workers(route.id,13), "Prepare a new order immediately after first returned terminal report")
	late.advance(10.0)
	test.check(late.run.trails.routes.route_1.desired_workers == 13, "Late same-encounter survivor reports cannot cancel the newly prepared order")
	game.advance(180); copy.advance(180)
	test.check(route.allocated_workers == 0 and game.run.swarm.serial == serial and game.run.to_dict() == copy.run.to_dict(), "Avoided route physically releases survivors and cannot repeat the old fight")
	test.check(game.set_trail_workers(route.id,13), "Player can explicitly prepare a larger paid retry after recovery")
	var new_warning: bool = false
	for tick: int in 2000:
		game.advance(0.25)
		if route.conflict_serial > serial:
			new_warning = true; break
	test.check(new_warning and root.trail_summaries("home")[0].journey_alarm and route.conflict_report in ["contested","holding","resisted","reinforced"], "Fresh physical encounter delivers new urgency with a new serial")
	# A higher prepared retry should not be canceled by old same-encounter returns.
	var prepared: int = route.desired_workers
	game.advance(1.0)
	test.check(route.desired_workers == prepared, "Late older receipts do not duplicate an already applied pause")
	root.free()
	game = Counter.new().ready_game(); root = Root.new(); root.simulation = game
	route = game.run.trails.routes.route_1
	for tick: int in 2400:
		game.advance(0.25)
		if route.conflict_report == "secured": break
	test.check(route.conflict_report == "secured", "Ordinary prepared retry can return a rival victory")
	serial = game.run.swarm.serial
	var delivered: float = route.delivered_total
	game.advance(180)
	test.check(game.run.swarm.serial == serial and route.delivered_total > delivered and not root.trail_summaries("home")[0].journey_alarm, "Victory permits continued resource intake without hollow remnant battles or perpetual alarm")
	var invalid: Dictionary = Defense.new().snapshot(game); invalid.trails.routes[0].conflict_serial = serial+100
	test.check(not copy.restore_snapshot(invalid), "Forged future encounter serial rejects")
	root.free()
	game = Defense.new().ready_game(); game.journey_response.defend("route_1"); game.journey_response.reinforce("route_1")
	while game.run.journey_response.active(): game.advance(0.25)
	root = Root.new(); root.simulation = game
	var view := OutwardView.new(); test.get_root().add_child(view)
	view._status = root.outward_status("home"); view._signals = root.sensory_snapshot("home")
	view.selected_id = "signal:"+root.trail_summaries("home")[0].destination_knowledge_id
	view.trail_set_command = root.set_trail_target; view.journey_open = true
	test.check(view._journey_recovery(root.trail_summaries("home")[0]), "Delivered defensive endpoint exposes resuming/avoidance recovery actions")
	var event := InputEventMouseButton.new(); event.pressed = true; event.button_index = MOUSE_BUTTON_LEFT; event.position = view._conflict_rect("journey_close").get_center()
	view._unhandled_input(event)
	view.trail_create_command = root.create_trail_for
	view.gather_order_command = root.order_gathering
	view._pointer_press(view._trail_button_rect("trail_create").get_center(),"mouse")
	view._run_command("gather_commit")
	test.check(game.run.trails.routes.route_1.desired_workers == 5 and game.run.trails.routes.route_1.active_workers == 0, "Mouse recovery commits five real gatherers before their departure")
	view._run_command("journey_avoid")
	test.check(game.run.trails.routes.route_1.desired_workers == 0, "Recovery also permits continued route avoidance")
	view.free(); root.free()
	return true
