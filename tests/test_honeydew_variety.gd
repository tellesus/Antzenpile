extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
func run(test: Object) -> bool:
	for seed_value: int in [71,3030,3043]:
		var game := Controller.new(seed_value,"garden_edge")
		game.scouting.set_bias(2.15); game.scouting.set_effort(2)
		for tick: int in 2400:
			if game.run.knowledge.nodes.has("known:aphid_01"): break
			game.advance(0.25)
		var known: bool = game.run.knowledge.nodes.has("known:aphid_01")
		test.check(known, "Ordinary Garden Edge exploration discovers the western aphids: " + str(seed_value))
		if not known: continue
		game.scouting.set_effort(0)
		test.check(game.create_trail("home","known:aphid_01"), "Returned western source funds real gathering")
		for tick: int in 800:
			if game.run.trails.routes.route_1.delivered_total > 0: break
			game.advance(0.25)
		test.check(game.run.trails.routes.route_1.delivered_total > 0 and game.start_honeydew_tending("home"), "Physical harvest enables independent aphid attendants")
		var delivered: float = game.run.trails.routes.route_1.delivered_total
		var twin := Controller.new()
		test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Varied authored geography and tended relationship restore")
		game.advance(700); twin.advance(700)
		var route: TrailRouteState = game.run.trails.routes.route_1
		test.check(game.run.to_dict() == twin.run.to_dict(), "Sustained Garden Edge honeydew continues exactly")
		test.check(route.delivered_total > delivered and route.reported_losses == 0 and route.foreign_reports == 0 and game.run.predator.defeated_at == 0, "Honeydew production/gathering need no compulsory fight after both exterior threats activate")
	var contested: SimulationController = Defense.new().ready_game()
	test.check(contested.run.trails.routes.route_1.attack_reports > 0, "Existing Backyard retains a genuinely contested approach")
	return true
