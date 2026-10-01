extends RefCounted
## Long ordinary-command run across growth, exterior ecology and recurring weather.

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const NURSERY = preload("res://data/resources/default_nursery_development.tres")


func run(test: Object) -> bool:
	var game := Controller.new(3030)
	var pile: PileState = game.run.colony.piles.home
	var root := Root.new()
	root.simulation = game
	test.check(game.dispatch_scout("home", 0.0) and game.dispatch_scout("home", PI), "Post-slice run dispatches two carbohydrate scouts")
	if not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:carb_exposed") and game.run.knowledge.nodes.has("known:carb_sheltered"), 150.0):
		test.check(false, "Both carbohydrate reports reach the colony")
		root.free()
		return false
	test.check(game.create_trail("home", "known:carb_exposed") and game.create_trail("home", "known:carb_sheltered"), "Player commits both exposed and sheltered carbohydrate trails")
	test.check(game.dispatch_scout("home", 2.0), "Player searches for protein")
	if not _until(game, func() -> bool: return game.run.rain.phase == "raining", 100.0):
		test.check(false, "First rain waits for successful route traffic")
		root.free()
		return false
	var rain_one_at: float = game.run.simulation_time
	test.check(game.start_food_exchange("home"), "Food Exchange is an available early project")
	if not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:protein_01"), 150.0):
		test.check(false, "Protein scout returns")
		root.free()
		return false
	test.check(game.create_trail("home", "known:protein_01"), "Player funds the protein trail")
	var costs: Dictionary = NURSERY.costs()
	if not _until(game, func() -> bool: return pile.resources.carbohydrate >= costs.carbohydrate and pile.resources.protein >= costs.protein and pile.resources.water >= costs.water and pile.workers_available >= NURSERY.workers_required, 160.0):
		test.check(false, "Exterior returns fund Nursery development")
		root.free()
		return false
	test.check(game.start_nursery_development("home"), "Player commits food and labor to Nursery development")
	var nursery_at: float = game.run.simulation_time
	var stores_at_nursery: Dictionary = pile.resources.duplicate()
	test.check(game.dispatch_scout("home", -PI / 2.0), "Player searches for water during the Nursery project")
	if not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:water_01"), 150.0):
		test.check(false, "Water scout returns before growth runs out")
		root.free()
		return false
	test.check(game.create_trail("home", "known:water_01"), "Player funds water collection")
	if not _until(game, func() -> bool: return pile.nursery_state == "developed", 120.0):
		test.check(false, "Nursery project completes")
		root.free()
		return false
	var developed_at: float = game.run.simulation_time
	test.check(pile.brood_cohorts.size() == 1 and game.start_brood("home") and pile.brood_cohorts.size() == 2, "Developed Nursery starts an overlapping aggregate brood cohort")
	test.check(pile.workers.invariant_holds() and pile.nursery_occupied_space() == 16, "Overlap stays within explicit care and worker limits")
	game.advance(450.0 - game.run.simulation_time)
	test.check(game.run.world.nodes.protein_picnic.active and not game.run.knowledge.nodes.has("known:protein_picnic"), "Picnic protein appears in hidden reality before a scout reports it")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot) and copy.run.to_dict() == game.run.to_dict(), "Complex run with two brood cohorts and several routes restores exactly")
	for tick: int in 100:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Complex run continues exactly for 100 fixed ticks after reload")
	test.check(game.dispatch_scout("home", PI / 4.0) and game.dispatch_scout("home", PI / 6.0), "Player searches toward the temporary food after its appearance")
	var picnic_known: bool = _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:protein_picnic"), 130.0)
	test.check(picnic_known, "A scout returns evidence of the temporary protein source")
	if not picnic_known:
		root.free()
		return false
	var picnic_at: float = game.run.simulation_time
	test.check(game.create_trail("home", "known:protein_picnic"), "Player invests in the temporary food window")
	test.check(_until(game, func() -> bool: return game.run.trails.routes.route_5.delivered_total > 0.0, 80.0), "Temporary protein reaches home through aggregate traffic")
	game.advance(maxf(0.0, 651.0 - game.run.simulation_time))
	test.check(not game.run.world.nodes.protein_picnic.active and game.run.knowledge.nodes.has("known:protein_picnic"), "Source disappears while colony memory remains")
	test.check(_until(game, func() -> bool: return game.run.trails.routes.route_5.status == "depleted", 30.0), "Ordinary empty return reports the expired source")
	var available_before_recall: int = pile.workers_available
	test.check(game.set_trail_workers("route_5", 0) and game.run.trails.routes.route_5.status == "inactive" and pile.workers_available == available_before_recall + 5, "Player recalls idle workers from a stale temporary-source route")
	test.check(_until(game, func() -> bool: return game.run.rain.fronts_completed >= 2, 200.0), "A second front visits the established colony")
	var rain_two_at: float = game.run.simulation_time
	game.advance(maxf(0.0, 1050.0 - game.run.simulation_time))
	test.check(game.run.world.nodes.protein_picnic.active and not game.run.knowledge.temporal_hint("known:protein_picnic").possible_recurrence, "Physical recurrence alone does not teach the colony")
	test.check(game.investigate_known_source("home", "known:protein_picnic"), "Player deliberately investigates the remembered source")
	test.check(_until(game, func() -> bool: return game.run.scouts.is_empty(), 120.0), "All scouts return before the final review")
	var hint: Dictionary = game.run.knowledge.temporal_hint("known:protein_picnic")
	test.check(hint.possible_recurrence and hint.label.contains("uncertain"), "Returned evidence makes recurrence tentative rather than omniscient")
	test.check(pile.brood_matured_total >= 16 and pile.workers_total >= 56 and pile.workers.invariant_holds(), "Overlapping brood yields a larger conserved workforce")
	var outward: Dictionary = root.outward_status("home")
	var inward: Dictionary = root.inward_status("home")
	test.check(not outward.has("world") and not outward.has("schedule") and not inward.has("world") and outward.resources == inward.resources, "Both normal modes share approved stores without hidden truth")
	test.check(_nonnegative(pile.resources), "All three stores stay finite and nonnegative")
	print("[POST-SLICE] rain1=%.2f nursery_start=%.2f nursery_done=%.2f picnic_report=%.2f rain2_done=%.2f final=%.2f brood=%d workers=%d available=%d routes=%d reports=%d nursery_stores=%s final_stores=%s" % [rain_one_at, nursery_at, developed_at, picnic_at, rain_two_at, game.run.simulation_time, pile.brood_matured_total, pile.workers_total, pile.workers_available, game.run.trails.routes.size(), game.run.knowledge.observations.size(), stores_at_nursery, pile.resources])
	root.free()
	return true


func _nonnegative(resources: Dictionary) -> bool:
	for amount: float in resources.values():
		if not is_finite(amount) or amount < 0.0:
			return false
	return true


func _until(game: SimulationController, predicate: Callable, limit_seconds: float) -> bool:
	for tick: int in roundi(limit_seconds / 0.25):
		if predicate.call():
			return true
		game.advance(0.25)
	return predicate.call()
