extends RefCounted
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func run(test: Object) -> bool:
	var game: SimulationController = Defense.new().ready_game()
	test.check(game.journey_response.set_goal("route_1", "hunt") and game.journey_response.set_force("route_1", 24), "Hunt goal captures a funded worker swarm")
	var root := Root.new(); root.simulation = game
	var before: Dictionary = game.run.to_dict()
	test.check(not game.journey_response.set_goal("route_1", "clear") and before == game.run.to_dict(), "Dispatched hunt goal cannot change remotely")
	var twin := Controller.new()
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Outbound hunt restores")
	var private_kill: bool = false
	for tick: int in 1600:
		if not game.run.journey_response.active(): break
		game.advance(0.25); twin.advance(0.25)
		test.check(game.run.to_dict() == twin.run.to_dict(), "Hunt and private return continue exactly")
		if game.run.predator.killed and game.run.journey_response.active():
			private_kill = true
			test.check(not game.run.knowledge.nodes.has("known:ambusher_carcass"), "Private kill creates no premature knowledge")
			test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Private physical carcass restores before return")
	test.check(private_kill and game.run.predator.killed and game.run.world.nodes.has("ambusher_carcass"), "Successful hunt creates exactly one physical carcass")
	test.check(game.run.knowledge.nodes.has("known:ambusher_carcass") and root.outward_status("home").journey_response.outcomes.route_1.goal == "hunt", "Returning workers deliver protein remains and kill outcome")
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Reported carcass and witness archive restore")
	var protein_before: float = game.run.colony.piles.home.resources.protein
	test.check(game.create_trail("home", "known:ambusher_carcass"), "Reported carcass accepts ordinary gatherers")
	game.advance(160)
	test.check(game.run.colony.piles.home.resources.protein > protein_before and game.run.trails.routes.route_2.energy_limited, "Recovered protein arrives physically; further trips wait for travel food")
	game.set_trail_workers("route_1", 5); game.advance(400)
	test.check(game.run.colony.piles.home.resources.protein > protein_before and game.run.world.nodes.ambusher_carcass.quantity == 0, "Protein requires physical harvest and delivery; carcass depletes")
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Depleted carcass and paid gathering restore")
	var saved: Dictionary = Defense.new().snapshot(game)
	for field: String in ["killed", "quantity", "position", "goal"]:
		var broken: Dictionary = saved.duplicate(true)
		match field:
			"killed": broken.predator.defense.killed = false
			"goal": broken.journey_response.defense.goal = "teleport"
			_:
				for node: Dictionary in broken.world.nodes:
					if node.id == "ambusher_carcass":
						if field == "quantity": node.quantity = 100
						else: node.position = [1, 1]
		test.check(not twin.restore_snapshot(broken), "Malformed corpse/goal rejected: " + field)
	var clear_game: SimulationController = Defense.new().ready_game()
	clear_game.journey_response.defend("route_1", 24)
	while clear_game.run.journey_response.active(): clear_game.advance(0.25)
	test.check(clear_game.run.predator.defeated_at > 0 and not clear_game.run.predator.killed and not clear_game.run.world.nodes.has("ambusher_carcass"), "Driving off a predator produces no food")
	root.free(); return true
