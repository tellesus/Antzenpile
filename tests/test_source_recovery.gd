extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Fixture = preload("res://tests/test_trail_exploration.gd")
const Reports = preload("res://tests/test_knowledge.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")


func fixture() -> SimulationController:
	var game := Fixture.new().fixture()
	game.run.world.nodes.carb_exposed.quantity = 0
	for tick: int in 500:
		game.advance(0.25)
		if game.run.trails.routes.route_1.status == "depleted" and game.run.trails.routes.route_1.active_workers == 0:
			break
	assert(game.run.trails.routes.route_1.status == "depleted")
	return game


func report(game: SimulationController, observed: float, confirmed: bool) -> void:
	var evidence: Observation = Reports.new().evidence("scout_%d" % game.run.next_scout_id, observed, 1.0, confirmed)
	game.run.next_scout_id += 1
	var delivered: bool = Reports.new().deliver(game.run.knowledge, evidence, game.run.simulation_time)
	assert(delivered)


func run(test: Object) -> bool:
	var game := fixture()
	var route: TrailRouteState = game.run.trails.routes.route_1
	var root := Root.new()
	root.simulation = game
	var before: Dictionary = game.run.to_dict()
	test.check(not root.toggle_investigation_priority("known:missing").accepted and game.run.to_dict() == before, "Invalid watch rejects without changing gathering or scout intent")
	var result: Dictionary = root.toggle_investigation_priority("known:carb_exposed")
	test.check(result.accepted and result.recovery_watch and result.exploration_off and route.resume_on_report and "known:carb_exposed" in game.run.exploration.priorities, "Depleted-source watch queues investigation and existing gathering intent while exploration is off")
	game.run.world.nodes.carb_exposed.quantity = 100
	game.advance(3)
	test.check(route.status == "depleted" and game.run.scouts.is_empty(), "Hidden renewal cannot resume a watched route or invent exploration labor")
	report(game, route.last_empty_report_at - 1, true)
	game.advance(1)
	test.check(route.status == "depleted" and not game.run.knowledge.recovery_report("known:carb_exposed", route.last_empty_report_at), "Late delivery of a pre-empty observation cannot authorize recovery")
	report(game, game.run.simulation_time, false)
	game.advance(1)
	test.check(route.status == "depleted", "A fresh faint cue is insufficient for automatic gathering")
	var copy := Controller.new()
	var saved: Dictionary = Snapshot.new().snapshot(game)
	test.check(copy.restore_snapshot(saved), "Queued recovery watch and empty-report boundary survive a save")
	before = copy.run.to_dict()
	for field: String in ["resume_on_report", "last_empty_report_at"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.trails.routes[0][field] = "yes" if field == "resume_on_report" else game.run.simulation_time + 1
		test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == before, "Malformed watch policy rejects atomically")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.trails.routes[0].erase("resume_on_report")
	legacy.trails.routes[0].erase("last_empty_report_at")
	test.check(copy.restore_snapshot(legacy) and not copy.run.trails.routes.route_1.resume_on_report, "Older depleted routes default to manual recovery with their returned empty boundary")
	test.check(game.investigate_known_source("home", "known:carb_exposed"), "A real worker can investigate the renewed source")
	var private_seen: bool = false
	for tick: int in 200:
		game.advance(0.25)
		for agent: ScoutAgent in game.run.scouts.values():
			if not agent.observations.is_empty():
				private_seen = true
		if private_seen:
			break
	test.check(private_seen and route.status == "depleted", "A private renewed-source observation still cannot restart traffic")
	saved = Snapshot.new().snapshot(game)
	for scale: int in [4,16,64]:
		var normal := Controller.new()
		var fast := Controller.new()
		assert(normal.restore_snapshot(saved) and fast.restore_snapshot(saved))
		normal.advance(60)
		fast.set_time_scale(scale)
		fast.advance(60.0 / scale)
		fast.set_time_scale(1)
		test.check(normal.run.to_dict() == fast.run.to_dict() and normal.run.trails.routes.route_1.delivered_total > route.delivered_total, "Returned recovery and real resource delivery continue exactly at %dx" % scale)
	game.toggle_pause()
	before = game.run.to_dict()
	game.advance(20)
	test.check(game.run.to_dict() == before, "Pause freezes recovery reports and traffic")
	game.toggle_pause()
	game.advance(40)
	test.check(route.status == "active" and route.delivered_total > saved.trails.routes[0].delivered_total and route.desired_workers == 5 and game.run.colony.piles.home.workers.invariant_holds(), "Confirmed home return resumes existing five-worker gathering without instant resources or extra labor")
	test.check(game.run.knowledge.temporal_hint("known:carb_exposed").renewed_report, "Returned renewal is visible as historical evidence")
	game.run.world.nodes.carb_exposed.quantity = 0
	for tick: int in 300:
		game.advance(0.25)
		if route.status == "depleted" and route.active_workers == 0:
			break
	var cohort_id: int = game.run.trails.next_cohort_id
	game.advance(30)
	test.check(route.status == "depleted" and game.run.trails.next_cohort_id == cohort_id, "A later empty return consumes the old recovery evidence instead of repeatedly relaunching")
	result = root.toggle_investigation_priority("known:carb_exposed")
	test.check(result.accepted and not route.resume_on_report and "known:carb_exposed" not in game.run.exploration.priorities, "Stop Watch removes automatic recovery and its recurring investigation")
	var view := View.new()
	test.get_root().add_child(view)
	view.investigate_command = root.toggle_investigation_priority
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	for signal_data: Dictionary in view._signals:
		if signal_data.source_knowledge_id == "known:carb_exposed":
			view.selected_id = signal_data.id
	test.check(view._investigation_title(view._selected_signal()) == "WATCH AND RESUME GATHERING" and view._recheck_title(view._selected_route(view._selected_signal())) == "TRY GATHERING", "Checking and uncertain gathering have distinct contextual names")
	view._pointer_press(view._investigate_button_rect().get_center(), "touch")
	view._status = root.outward_status("home")
	test.check(view._investigation_title(view._selected_signal()) == "STOP RECOVERY WATCH", "Touch arms a persistent watch with a clear stop action")
	view._pointer_press(view._investigate_button_rect().get_center(), "mouse")
	test.check(not route.resume_on_report, "Mouse stops the same watch")
	game.advance(1)
	report(game, game.run.simulation_time, true)
	view._status = root.outward_status("home")
	test.check(view._recheck_title(view._selected_route(view._selected_signal())) == "RESUME GATHERING", "Fresh confirmed returned evidence changes the gathering action")
	view.free()
	root.free()
	var risky := fixture()
	risky.trails.set_recovery_watch("route_1", true)
	risky.run.trails.routes.route_1.foreign_reports = 1
	risky.advance(1)
	report(risky, risky.run.simulation_time, true)
	risky.advance(1)
	test.check(risky.run.trails.routes.route_1.status == "depleted", "Returned danger blocks automatic recovery and leaves manual approval to the player")
	var stopped := fixture()
	stopped.trails.set_recovery_watch("route_1", true)
	stopped.set_trail_workers("route_1", 0)
	stopped.advance(1)
	report(stopped, stopped.run.simulation_time, true)
	stopped.advance(1)
	test.check(stopped.run.trails.routes.route_1.status == "inactive" and stopped.run.trails.routes.route_1.desired_workers == 0, "Fresh reports cannot reverse Cancel or commit new gathering workers")
	return true
