extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")


func _distant_water() -> SimulationController:
	var game := Controller.new(6241)
	var water: WorldNodeState = game.run.world.nodes.water_01
	water.position = Vector2(37, 20)
	game.run.world.nodes = {"water_01": water}
	for region: Dictionary in game.run.world.terrain:
		if region.id == "exposed":
			region.movement_cost = 4.0
	return game


func run(test: Object) -> bool:
	var game := _distant_water()
	test.check(game.dispatch_scout("home", 0.0), "Scout can depart toward water outside the initial 8–12 m target")
	game.advance(35.0)
	test.check(game.run.scouts.has("scout_1") and game.run.scouts.scout_1.elapsed > 30.0 and game.run.knowledge.nodes.is_empty(), "Search continues past the old 30-second mission deadline without inventing knowledge")
	var snapshot: Dictionary = game.run.to_dict()
	var restored := Controller.new()
	test.check(restored.restore_snapshot(JSON.parse_string(JSON.stringify(snapshot, "", true, true))) and restored.run.to_dict() == snapshot, "Mid-search save restores a scout with no new snapshot fields")
	var max_distance: float = 0.0
	var locked_away: bool = false
	for tick: int in 2400:
		if game.run.knowledge.nodes.has("known:water_01"):
			break
		game.advance(0.25)
		restored.advance(0.25)
		if game.run.scouts.has("scout_1"):
			var scout: ScoutAgent = game.run.scouts.scout_1
			max_distance = maxf(max_distance, scout.position.distance_to(Vector2(20, 20)))
			locked_away = locked_away or scout.observations.has("water_01") and scout.observations.water_01.proximity_confirmed and scout.phase == "returning"
	var water_report_at: float = game.run.simulation_time
	test.check(game.run.knowledge.nodes.has("known:water_01") and game.run.scouts.is_empty() and max_distance > 12.0 and locked_away, "Scout goes beyond its initial range, confirms distant water, then returns")
	test.check(game.run.to_dict() == restored.run.to_dict() and game.run.colony.piles.home.workers.invariant_holds(), "Distant search and return continue deterministically after save/load")
	var known := Controller.new(6241)
	var distant: WorldNodeState = known.run.world.nodes.water_01
	distant.position = Vector2(37, 20)
	known.run.world.nodes = {"carb_exposed": known.run.world.nodes.carb_exposed, "water_01": distant}
	test.check(known.dispatch_scout("home", 0.0), "First scout searches a near known-source fixture")
	for tick: int in 800:
		if known.run.knowledge.nodes.has("known:carb_exposed"):
			break
		known.advance(0.25)
	test.check(known.run.knowledge.nodes.has("known:carb_exposed"), "First scout reports carbohydrate")
	test.check(known.dispatch_scout("home", 0.0), "Second scout starts after carbohydrate is known")
	for tick: int in 2400:
		if known.run.knowledge.nodes.has("known:water_01"):
			break
		known.advance(0.25)
	test.check(known.run.knowledge.nodes.has("known:water_01") and known.run.knowledge.nodes.has("known:carb_exposed") and known.run.scouts.is_empty(), "Scout passes a known carbohydrate source and keeps searching for new water")
	var empty := Controller.new(93)
	empty.run.world.nodes.clear()
	test.check(empty.dispatch_scout("home", 0.0), "Empty-world scout can start before a tiny reachable-region fixture")
	var agent: ScoutAgent = empty.run.scouts.scout_1
	agent.path = [Vector2(20, 20), Vector2(21, 20)]
	agent.cursor = 1
	agent.mission_target = Vector2(21, 20)
	empty.run.world.bounds = Rect2(20, 20, 2, 1)
	empty.run.world.terrain = [{"id": "tiny", "bounds": [20.0, 20.0, 2.0, 1.0], "exposure": 0.0, "traversable": true, "movement_cost": 1.0}]
	empty.advance(10.0)
	test.check(empty.run.scouts.is_empty() and empty.run.colony.piles.home.workers_available == 40 and empty.run.knowledge.nodes.is_empty(), "Exhausted reachable ground returns scout and releases its worker without a false report")
	print("[SCOUT] distant water report at %.2fs, known-source pass-through and exhausted-ground return verified" % water_report_at)
	return true
