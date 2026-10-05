extends RefCounted
const Survey = preload("res://tests/test_journey_investigation.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")

func ready_game(seed_value: int = 3043) -> SimulationController:
	var game: SimulationController = Survey.new().investigated_game(seed_value)
	game.journey_response.investigate("route_1")
	while game.run.journey_response.active(): game.advance(0.25)
	return game

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func run(test: Object) -> bool:
	var game: SimulationController = Survey.new().investigated_game()
	var before: Dictionary = game.run.to_dict()
	test.check(not game.journey_response.defend("route_1") and game.run.to_dict() == before,"Loss alone cannot authorize an unseen ambusher swarm")
	game = ready_game()
	var pile: PileState = game.run.colony.piles.home
	var root := Root.new(); root.simulation = game
	var available: int = pile.workers_available
	var food: float = pile.resources.carbohydrate
	test.check(game.journey_response.defend("route_1") and pile.workers_available == available - 12 and pile.resources.carbohydrate < food,"Delivered ambusher finding funds twelve defenders and route travel")
	var checkpoints: Array[Dictionary] = [snapshot(game)]
	game.advance(5)
	test.check(game.run.journey_response.phase == "outbound" and game.run.predator.resistance == 6,"Defenders travel before applying combat pressure")
	game.toggle_pause(); before = game.run.to_dict(); game.advance(50)
	test.check(game.run.to_dict() == before,"Pause freezes aggregate defense and reinforcement travel")
	game.toggle_pause()
	while game.run.journey_response.phase == "outbound": game.advance(0.25)
	checkpoints.append(snapshot(game))
	var party: JourneyResponseState = game.run.journey_response
	var fighters: int = party.workers
	test.check(game.journey_response.reinforce("route_1") and party.workers == fighters and party.defense.extra_workers == 4,"Paid reinforcement remains a traveling batch until physical meeting")
	before = game.run.to_dict()
	test.check(not game.journey_response.reinforce("route_1") and game.run.to_dict() == before,"Duplicate traveling reinforcement rejects atomically")
	checkpoints.append(snapshot(game))
	var known: Dictionary = root.outward_status("home").journey_response
	var expected: int = root.inward_status("home").workers_total
	var emerged: int = pile.brood_matured_total
	var combat_loss_saved: bool = false
	while party.active():
		game.advance(0.25)
		if party.active():
			test.check(root.inward_status("home").workers_total == expected + pile.brood_matured_total - emerged and root.outward_status("home").journey_response.workers == 16 and root.outward_status("home").journey_response.outcomes.is_empty(),"Remote casualties and success do not change expected labor or outcome")
			if party.defense.lost > 0 and not combat_loss_saved: checkpoints.append(snapshot(game)); combat_loss_saved = true
			if party.phase == "inbound" and checkpoints[-1].journey_response.phase != "inbound": checkpoints.append(snapshot(game))
	test.check(party.defense.outcomes.route_1.outcome == "secured" and game.run.predator.defeated_at > 0 and pile.workers_available == available + pile.brood_matured_total - emerged - game.run.predator.defense_losses,"Returning survivors deliver successful removal and reconcile real defense losses")
	test.check(combat_loss_saved and party.defense.reported_losses == game.run.predator.defense_losses and root.inward_status("home").workers_total == pile.workers_total,"Defense casualties are separately conserved and learned at home")
	before = game.run.to_dict()
	test.check(root.trail_summaries("home")[0].ambusher_addressed and not game.journey_response.defend("route_1") and game.run.to_dict() == before,"Delivered victory updates known alarm without funding another pointless swarm")
	checkpoints.append(snapshot(game))
	for saved: Dictionary in checkpoints:
		var copy := Controller.new(); var original := Controller.new()
		test.check(copy.restore_snapshot(saved) and original.restore_snapshot(saved),"Outbound/fighting/reinforcement/casualty/inbound/completed defense restores")
		original.advance(100); copy.advance(100)
		test.check(original.run.to_dict() == copy.run.to_dict(),"Exact seeded continuation from defense checkpoint")
	for speed: int in [1,4,16,64]:
		var copy := Controller.new(); copy.restore_snapshot(checkpoints[2]); copy.set_time_scale(speed); copy.advance(100.0 / speed); copy.set_time_scale(1)
		var original := Controller.new(); original.restore_snapshot(checkpoints[2]); original.advance(100)
		test.check(copy.run.to_dict() == original.run.to_dict(),"Defense fixed ticks at " + str(speed))
	var restored := Controller.new()
	for field: String in ["lost","profiles","reinforcement","rounds","receipt","pressure","removal","orphan"]:
		var broken: Dictionary = checkpoints[2].duplicate(true)
		match field:
			"lost": broken.journey_response.defense.lost += 1
			"profiles": broken.journey_response.defense.lost_profiles = {"load":1}
			"reinforcement": broken.journey_response.defense.extra_ticks = 99999
			"rounds": broken.journey_response.defense.round_ticks = 99999
			"receipt": broken.journey_response.defense.outcomes.route_1 = {"outcome":"secured","lost":0,"sent":12,"observed_at":1,"received_at":99999}
			"pressure": broken.predator.defense.resistance = -1
			"removal": broken.predator.defense.defeated_at = 100
			"orphan": broken.journey_response.erase("defense")
		test.check(not restored.restore_snapshot(broken),"Malformed defense state rejects: " + field)
	var attacks: int = game.run.predator.kills_total
	var route: TrailRouteState = game.run.trails.routes.route_1
	var cargo: float = route.delivered_total
	game.set_trail_workers("route_1",5); game.advance(180)
	test.check(route.delivered_total > cargo and game.run.predator.kills_total == attacks,"Ordinary harvesting after intervention delivers food without further ambush kills")
	test.check(game.run.rival.direction != "dormant" and game.run.rival.workers.count("rival:trail") == 6,"Ambusher removal leaves independent rival ecology running")
	# Early recall with a dispatched batch joins on physical crossing and returns all labor.
	game = ready_game(); available = game.run.colony.piles.home.workers_available
	game.journey_response.defend("route_1"); game.advance(8); game.journey_response.reinforce("route_1"); game.advance(1)
	test.check(game.journey_response.recall() and game.run.journey_response.active(),"Recall keeps paid defenders and traveling reinforcements away until return")
	var copy := Controller.new(); test.check(copy.restore_snapshot(snapshot(game)),"Recalled party with traveling reinforcement restores")
	while game.run.journey_response.active(): game.advance(0.25); copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.colony.piles.home.workers_available == available and game.run.predator.defeated_at == 0 and game.run.journey_response.defense.outcomes.route_1.outcome == "withdrew","Recall meets reinforcement and releases survivors without removing threat")
	root.simulation = ready_game()
	var view := View.new(); test.get_root().add_child(view); view.journey_command = root.respond_to_journey
	view._signals = root.sensory_snapshot("home"); view._status = root.outward_status("home"); view.selected_id = "threat:route_1"
	view._pointer_press(view._conflict_rect("conflict_send").get_center(),"mouse")
	view._pointer_press(view._conflict_rect("draft_commit").get_center(),"mouse")
	test.check(root.simulation.run.journey_response.defense.mode == "defend","Mouse mobilization uses a distinct defense action")
	root.simulation.advance(4); view._status = root.outward_status("home")
	view._pointer_press(view._conflict_rect("conflict_send").get_center(),"touch")
	view._pointer_press(view._conflict_rect("draft_commit").get_center(),"touch")
	test.check(root.simulation.run.journey_response.defense.extra_workers == 4,"Touch reinforces by real dispatch")
	view.queue_free(); root.free()
	_test_retreat_and_genetics(test)
	return true

func _test_retreat_and_genetics(test: Object) -> void:
	var game: SimulationController = ready_game()
	var saved: Dictionary = snapshot(game)
	var withdrew: bool = false
	for combat_seed: int in 256:
		var candidate := Controller.new(); candidate.restore_snapshot(saved); candidate.run.rng.seed = combat_seed
		candidate.journey_response.defend("route_1")
		while candidate.run.journey_response.active(): candidate.advance(0.25)
		var result: Dictionary = candidate.run.journey_response.defense.outcomes.route_1
		if result.outcome == "withdrew":
			var copy := Controller.new()
			test.check(result.sent - result.lost >= 3 and result.sent - result.lost <= 3 + candidate.journey_response.CONFIG.max_messengers and candidate.run.predator.defeated_at == 0 and copy.restore_snapshot(snapshot(candidate)),"Weak aggregate swarm retreats with surviving labor and persistent manageable threat")
			withdrew = true; break
	test.check(withdrew,"Bounded combat seed coverage exercises actual automatic retreat")
	# Obtain expressed adults through the ordinary paid brood trial.
	game = ready_game()
	var pile: PileState = game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS: pile.deposit_resource(resource,200)
	game.advance(360); test.check(game.start_adaptation("home","load"),"Defense genetics fixture lays an ordinary paid adaptation brood")
	game.advance(360); saved = snapshot(game)
	var captured: bool = false
	for combat_seed: int in 32:
		var candidate := Controller.new(); candidate.restore_snapshot(saved); candidate.run.rng.seed = combat_seed
		var root := Root.new(); root.simulation = candidate
		var known: int = root.inward_status("home").adapted_workers
		candidate.journey_response.defend("route_1")
		while candidate.run.journey_response.active():
			candidate.advance(0.25)
			if candidate.run.journey_response.defense.adapted_lost > 0:
				var copy := Controller.new()
				test.check(root.inward_status("home").adapted_workers == known and copy.restore_snapshot(snapshot(candidate)),"Private defensive phenotype loss conserves expected expression and strict snapshot")
				while candidate.run.journey_response.active(): candidate.advance(0.25); copy.advance(0.25)
				test.check(candidate.run.to_dict() == copy.run.to_dict() and root.inward_status("home").adapted_workers == candidate.run.colony.piles.home.adapted_workers_total,"Returned defense resolves genetic loss with exact continuation")
				captured = true; break
		root.free()
		if captured: break
	test.check(captured,"Seed coverage exercises a real adapted defensive casualty")
