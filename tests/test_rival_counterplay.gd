extends RefCounted
const Fixture = preload("res://tests/test_swarm.gd")
const Contact = preload("res://tests/test_rival_contact.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func ready_game() -> SimulationController:
	var game: SimulationController = Fixture.new().forming_fixture()
	while game.run.trails.routes.route_1.conflict_report not in ["withdrew","dispersed"]: game.advance(0.25)
	while game.run.trails.routes.route_1.allocated_workers > 0: game.advance(0.25)
	game.set_trail_workers("route_1",13)
	return game

func run(test: Object) -> bool:
	var game := ready_game()
	var root := Root.new(); root.simulation = game
	var rival: RivalState = game.run.rival
	var group: RivalReinforcementState = rival.reinforcement
	var route: TrailRouteState = game.run.trails.routes.route_1
	var old_store: float = 0
	for tick: int in 1200:
		old_store = rival.stored_carbohydrate
		game.advance(0.25)
		if group.phase == "outbound": break
	test.check(group.phase == "outbound" and rival.workers.count("rival:reinforcement") == 4 and rival.workers.available == 20 and rival.stored_carbohydrate < old_store, "Enemy pays its own stores and commits four real reserves")
	test.check(group.remaining_ticks == group.travel_ticks and group.travel_ticks > 1, "Foreign reserves start at their own pile rather than the junction")
	var saved: Dictionary = Contact.new().snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and game.run.to_dict() == copy.run.to_dict(), "Enemy reserve departure and active swarm restore exactly")
	var phases: Dictionary = {"outbound":true}
	var seen_arrival: bool = false
	var seen_pressure: bool = false
	var seen_return: bool = false
	for tick: int in 1600:
		game.advance(0.25); copy.advance(0.25)
		if not phases.has(group.phase):
			phases[group.phase] = true
			var checkpoint := Controller.new()
			test.check(checkpoint.restore_snapshot(Contact.new().snapshot(game)) and checkpoint.run.to_dict() == game.run.to_dict(), "Reserve phase saves exactly: " + group.phase)
		if group.phase == "engaged": seen_arrival = true
		if not seen_pressure and route.conflict_report in ["holding","resisted","reinforced"]:
			seen_pressure = true
			test.check(route.conflict_received_at > route.conflict_observed_at, "Foreign pressure is physically delivered after observation")
		if group.mobilizations == 1 and group.phase == "idle": seen_return = true
		if not game.run.swarm.active() and seen_return: break
	test.check(seen_arrival and seen_pressure and seen_return and group.mobilizations == 1, "Ordinary higher target permits physical rival counterplay, intermediate reports and returning reserves")
	test.check(game.run.to_dict() == copy.run.to_dict() and rival.workers.total+rival.workers.lost_total == 30 and rival.workers.invariant_holds() and game.run.colony.piles.home.workers.invariant_holds(), "Real casualties and finite reserve return preserve both ledgers and exact continuation")
	var known: Dictionary = root.outward_status("home")
	test.check(not known.has("rival") and not known.has("reinforcement") and not known.trails[0].has("enemy_count"), "Approved context excludes enemy reserve numbers and movement")
	var view := OutwardView.new(); test.get_root().add_child(view)
	view._status = known; view._signals = root.sensory_snapshot("home")
	view.selected_id = "signal:known:carb_exposed"; view.trail_set_command = root.set_trail_target
	view._run_command("journey_open")
	test.check(view._rival_attention(), "Delivered rival fighting opens its own response topic")
	var before: Dictionary = game.run.to_dict()
	view._run_command("journey_topic")
	test.check(not view._rival_attention() and game.run.to_dict() == before, "Survey/ambusher topic switch issues no orders")
	view._run_command("journey_topic")
	var event := InputEventScreenTouch.new(); event.pressed = true; event.position = view._journey_rect("journey_defend").get_center()
	view._unhandled_input(event)
	test.check(route.desired_workers == 0, "Rival-context touch withdrawal requests real travel rather than instant release")
	for field: String in ["count","phase","travel","budget","serial"]:
		var invalid: Dictionary = saved.duplicate(true)
		match field:
			"count": invalid.rival.workers.commitments["rival:reinforcement"].count = 5
			"phase": invalid.rival.reinforcement.phase = "idle"
			"travel": invalid.rival.reinforcement.remaining_ticks = 9999
			"budget": invalid.rival.reinforcement.mobilizations = 4
			"serial": invalid.rival.reinforcement.swarm_serial = 9999
		var fresh := Controller.new(); before = fresh.run.to_dict()
		test.check(not fresh.restore_snapshot(invalid) and fresh.run.to_dict() == before, "Malformed foreign reserve " + field + " rejects atomically")
	var legacy: Dictionary = Contact.new().snapshot(Controller.new())
	legacy.rival.erase("reinforcement"); legacy.swarm.erase("rounds"); legacy.swarm.erase("pressure_reports_sent")
	test.check(copy.restore_snapshot(legacy), "Legacy empty rival defaults without inventing reserve deployments")
	view.free(); root.free()
	return true
