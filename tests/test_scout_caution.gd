extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Caution = preload("res://src/sim/scouting/scout_caution.gd")
const Pathfinder = preload("res://src/sim/scouting/scout_pathfinder.gd")
const Root = preload("res://src/core/game_root.gd")


func run(test: Object) -> bool:
	var game: SimulationController = load("res://tests/test_predator.gd").new()._fixture()
	var route: TrailRouteState = game.run.trails.routes.route_1
	for tick: int in 1000:
		game.advance(0.25)
		if game.run.predator.kills_total > 0: break
	test.check(Caution.routes(game.run, "home").is_empty(), "Private trail casualties never teach scout danger")
	for tick: int in 1000:
		game.advance(0.25)
		if route.reported_losses > 0: break
	test.check(Caution.routes(game.run, "home") == [route.id], "Real returned journey loss teaches one remembered risky corridor")
	game.set_trail_workers(route.id, 0)
	game.advance(100.0)
	var original: Array[String] = Caution.routes(game.run, "home")
	var hidden: Vector2 = game.run.world.nodes.aphid_01.position
	game.run.world.nodes.aphid_01.position = Vector2(38, 38)
	game.run.world.nodes.aphid_01.quantity = 0
	test.check(Caution.routes(game.run, "home") == original, "Changing hidden source truth cannot relocate learned caution")
	game.run.world.nodes.aphid_01.position = hidden
	game.run.exploration.target = 1
	test.check(game.scouting.dispatch("home", PI / 4, true), "General directional exploration can depart after a returned alarm")
	var agent: ScoutAgent = game.run.scouts.values()[0]
	test.check(agent.avoid_routes == [route.id] and Caution.path_risk(agent.path, agent.avoid_routes, game.run.trails, game.run.colony.piles.home.position) == 0.0, "General explorer chooses an available safer initial path and captures delivered experience")
	var saved: Dictionary = disk(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Captured caution restores exactly")
	game.advance(5.0)
	copy.set_time_scale(4)
	copy.advance(1.25)
	copy.set_time_scale(1)
	test.check(copy.run.to_dict() == game.run.to_dict(), "Captured caution and RNG continue identically across speeds")
	for bad: Variant in [[route.id, route.id], ["missing"], [true], "route_1"]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid.scouts[0].avoid_routes = bad
		var before: Dictionary = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Invalid caution records reject atomically: " + str(bad))
	var legacy: Dictionary = saved.duplicate(true)
	legacy.scouts[0].erase("avoid_routes")
	test.check(copy.restore_snapshot(legacy) and copy.run.scouts.values()[0].avoid_routes.is_empty(), "Legacy away scouts retain their original uncautioned mission")
	var root := Root.new()
	root.simulation = game
	test.check(root.exploration_summary().cautious_routes == 1 and not root.exploration_summary().has("position"), "Normal summary offers learned-caution count, never a physical threat coordinate")
	root.free()
	game.set_exploration(0)
	game.recall_scout(agent.id)
	game.advance(100.0)
	test.check(game.scouting.dispatch("home", PI / 4, false) and game.run.scouts.values()[0].avoid_routes.is_empty(), "Manual exploration remains a deliberate risk-taking override")
	game.recall_scout(game.run.scouts.values()[0].id)
	game.advance(100.0)
	test.check(game.investigate_known_source("home", route.destination_knowledge_id) and game.run.scouts.values()[0].avoid_routes.is_empty(), "Explicit source recheck bypasses general caution")
	_test_frontier(test, game, route)
	_test_defense(test)
	return true


static func disk(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func _test_frontier(test: Object, game: SimulationController, route: TrailRouteState) -> void:
	var agent: ScoutAgent = game.run.scouts.values()[0]
	agent.standing = true
	agent.investigation_source_id = ""
	agent.position = game.run.colony.piles.home.position.lerp(route.estimated_destination, 0.45).round()
	agent.return_path = Pathfinder.new(game.run.world).path(game.run.colony.piles.home.position, agent.position)
	var home: Vector2 = game.run.colony.piles.home.position
	agent.avoid_routes.clear()
	var ordinary: Array[Vector2] = game.scouting._frontier_path(agent, agent.position, -1)
	agent.avoid_routes.assign([route.id])
	var cautious: Array[Vector2] = game.scouting._frontier_path(agent, agent.position, -1)
	test.check(Caution.path_risk(cautious.slice(1), agent.avoid_routes, game.run.trails, home) < Caution.path_risk(ordinary.slice(1), agent.avoid_routes, game.run.trails, home), "Learned caution diverts an unexplored step away from a remembered loss corridor")
	game.scouting.config = game.scouting.config.duplicate()
	game.scouting.config.target_attempts = 1
	test.check(game.scouting.dispatch("home", PI / 4, true), "Caution preference still permits departure when alternatives run out")


func _test_defense(test: Object) -> void:
	var game: SimulationController = load("res://tests/test_ambusher_defense.gd").new().ready_game()
	var route: TrailRouteState = game.run.trails.routes.route_1
	test.check(Caution.routes(game.run, "home") == [route.id], "Reported ambusher remains a learned concern before intervention")
	test.check(game.journey_response.defend(route.id), "Ordinary funded defense can address learned danger")
	for tick: int in 1200:
		game.advance(0.25)
		if game.run.predator.defeated_at > 0:
			break
	test.check(game.run.predator.defeated_at > 0 and Caution.routes(game.run, "home") == [route.id], "Private victory does not instantly teach away scouts or Home that the corridor is safe")
	for tick: int in 1200:
		game.advance(0.25)
		if not game.run.journey_response.active(): break
	test.check(Caution.routes(game.run, "home").is_empty(), "Home-delivered successful defense removes caution for future departures")
