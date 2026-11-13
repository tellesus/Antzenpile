extends RefCounted
const Fixture = preload("res://tests/test_predator.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")

func investigated_game(seed_value: int = 3043) -> SimulationController:
	var game: SimulationController = Fixture.new()._fixture(seed_value)
	while game.run.trails.routes.route_1.reported_losses == 0: game.advance(0.25)
	game.set_trail_workers("route_1",0)
	while game.run.trails.routes.route_1.allocated_workers > 0: game.advance(0.25)
	return game

func run(test: Object) -> bool:
	var game := investigated_game()
	var root := Root.new(); root.simulation = game
	var pile: PileState = game.run.colony.piles.home
	var before: Dictionary = game.run.to_dict()
	test.check(not game.journey_response.investigate("missing") and game.run.to_dict() == before,"Unknown survey cannot mutate resources or labor")
	var workers: int = pile.workers_available
	var food: float = pile.resources.carbohydrate
	test.check(game.journey_response.investigate("route_1") and pile.workers_available == workers - 3 and pile.resources.carbohydrate < food,"Returned loss permits a paid three-worker survey")
	before = game.run.to_dict()
	test.check(not game.journey_response.investigate("route_1") and game.run.to_dict() == before,"Second party cannot duplicate a commitment")
	test.check(game.run.journey_response.reports.is_empty() and not str(root.sensory_snapshot("home")).contains("threat:"),"A departing survey reveals no threat")
	game.advance(5)
	game.toggle_pause(); before = game.run.to_dict(); game.advance(60)
	test.check(game.run.to_dict() == before,"Pause freezes survey travel and private sensing")
	game.toggle_pause()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
	var twin := Controller.new(); test.check(twin.restore_snapshot(saved),"Private active survey saves and restores")
	while game.run.journey_response.active():
		game.advance(0.25); twin.advance(0.25)
		if game.run.journey_response.active():
			test.check(not str(root.sensory_snapshot("home")).contains("threat:"),"Private survey sample remains unknown during actual return travel")
	test.check(game.run.to_dict() == twin.run.to_dict(),"Survey sampling and home report continue identically after JSON")
	var report: Dictionary = game.run.journey_response.reports.route_1
	test.check(report.finding == "ambush" and report.fraction >= 0 and pile.workers_available == workers and pile.workers.count("journey:home") == -1,"Actual route survey returns coarse ambush evidence and releases real labor")
	test.check(str(root.sensory_snapshot("home")).contains("threat:route_1") and not str(root.outward_status("home").journey_response).contains("position"),"Home-delivered evidence supplies a coarse sensory trace without predator coordinates")
	var known: Dictionary = root.outward_status("home").journey_response
	game.run.predator.last_attack_tick = game.run.clock.tick_count
	test.check(root.outward_status("home").journey_response == known,"Hidden predator cooldown cannot refresh a delivered finding")
	# Restore must reject malformed/orphan jobs atomically.
	for key: String in ["workers","elapsed_ticks","route_id","ambush_fraction","sampled_at","phase"]:
		var broken: Dictionary = saved.duplicate(true)
		broken.journey_response[key] = "missing" if key == "route_id" else "fighting" if key == "phase" else -5
		var current: Dictionary = twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict() == current,"Invalid survey " + key + " cannot partly restore")
	var orphan: Dictionary = saved.duplicate(true); orphan.erase("journey_response")
	test.check(not twin.restore_snapshot(orphan),"Legacy default cannot hide an active survey commitment")
	game = investigated_game(); game.journey_response.investigate("route_1"); game.advance(2)
	var committed: int = game.run.colony.piles.home.workers_available
	test.check(game.journey_response.recall() and game.run.colony.piles.home.workers_available == committed,"Recall preserves actual return travel and away labor")
	while game.run.journey_response.active(): game.advance(0.25)
	test.check(game.run.journey_response.reports.route_1.finding == "inconclusive" and game.run.colony.piles.home.workers.invariant_holds(),"Early recall yields no fabricated threat evidence")
	game = investigated_game(); game.advance(600); game.journey_response.investigate("route_1")
	while not game.run.journey_response.foreign_seen: game.advance(0.25)
	var foreign_copy := Controller.new()
	test.check(foreign_copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))),"Private survey foreign contact reconciles its distinct shared contact history")
	while game.run.journey_response.active(): game.advance(0.25)
	test.check(game.run.journey_response.reports.route_1.finding == "mixed" and game.run.trails.routes.route_1.foreign_reports == 1,"Returning survey independently reports foreign contact into existing rival escalation")
	root.simulation = investigated_game()
	var view := View.new(); test.get_root().add_child(view)
	view.journey_command = root.respond_to_journey
	view._signals = root.sensory_snapshot("home"); view._status = root.outward_status("home")
	view.selected_id = "signal:known:aphid_01"
	view._pointer_press(view._journey_rect("journey_open").get_center(),"mouse")
	test.check(view.journey_open and not root.simulation.run.journey_response.active(),"Journey attention opens separately from producer tending")
	view._pointer_press(view._journey_rect("journey_investigate").get_center(),"touch")
	test.check(root.simulation.run.journey_response.active(),"Touch investigation funds the same semantic survey command")
	view._status = root.outward_status("home"); root.simulation.advance(2)
	view._pointer_press(view._journey_rect("journey_investigate").get_center(),"mouse")
	test.check(root.simulation.run.journey_response.phase == "inbound","Mouse recall orders physical return")
	view.queue_free()
	for speed: int in [1,4,16,64]:
		var paced := Controller.new(); paced.restore_snapshot(saved); paced.set_time_scale(speed); paced.advance(40.0 / speed); paced.set_time_scale(1)
		var reference := Controller.new(); reference.restore_snapshot(saved); reference.advance(40)
		test.check(paced.run.to_dict() == reference.run.to_dict(),"Survey uses fixed travel time at " + str(speed))
	root.free()
	return true
