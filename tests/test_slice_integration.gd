extends RefCounted
## One uninterrupted, command-driven run through the authored slice.

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")


func _advance_until(game: SimulationController, condition: Callable, limit_seconds: float) -> bool:
	for tick: int in roundi(limit_seconds / SimulationClock.TICK_INTERVAL):
		if condition.call():
			return true
		game.advance(SimulationClock.TICK_INTERVAL)
	return condition.call()


func run(test: Object) -> bool:
	var game := Controller.new(3030)
	var pile: PileState = game.run.colony.piles.home
	var root := Root.new()
	root.simulation = game
	test.check(root.sensory_snapshot("home").is_empty(), "Slice begins without player-facing knowledge of hidden food")
	test.check(game.dispatch_scout("home", 0.0) and game.dispatch_scout("home", PI), "Player can send east and west scouts")
	game.advance(12.0)
	test.check(root.sensory_snapshot("home").is_empty() and game.run.knowledge.nodes.is_empty(), "Scouts' nearby chemical evidence stays private before their return")
	test.check(_advance_until(game, func() -> bool: return game.run.knowledge.nodes.has("known:carb_exposed") and game.run.knowledge.nodes.has("known:carb_sheltered"), 100.0), "Returned scouts establish both carbohydrate traces")
	var discovered_at: float = game.run.simulation_time
	if game.run.knowledge.nodes.size() < 2:
		root.free()
		return true
	test.check(root.sensory_snapshot("home").size() >= 2, "OUTWARD presents delivered knowledge")
	test.check(game.create_trail("home", "known:carb_exposed") and game.create_trail("home", "known:carb_sheltered"), "Player can invest in exposed and sheltered carbohydrate trails")
	test.check(game.dispatch_scout("home", 2.0), "Player can search for protein while trails operate")
	test.check(_advance_until(game, func() -> bool: return game.run.rain.phase == "raining", 90.0), "Both useful trails trigger rain after returning cargo")
	var rain_at: float = game.run.simulation_time
	test.check(game.run.trails.routes.size() == 2 and pile.resources.carbohydrate > 10.0 and pile.workers.invariant_holds(), "Trail deliveries increase stores without duplicating workers")
	test.check(game.start_food_exchange("home"), "Trail-fed stores fund Food Exchange development")
	var development_at: float = game.run.simulation_time
	test.check(_advance_until(game, func() -> bool: return game.run.knowledge.nodes.has("known:protein_01"), 150.0), "Protein scout returns a usable resource trace")
	var protein_at: float = game.run.simulation_time
	if game.run.knowledge.nodes.has("known:protein_01"):
		test.check(game.create_trail("home", "known:protein_01"), "Player commits a protein trail to support larval growth")
	test.check(_advance_until(game, func() -> bool: return pile.food_exchange_state == "developed", 100.0), "Food Exchange completes after its committed build time")
	var developed_at: float = game.run.simulation_time
	test.check(root.music_state("home").development_level == 1, "Developed Food Exchange activates the semantic second music layer")
	test.check(_advance_until(game, func() -> bool: return pile.brood_matured_total == 8, 500.0), "Supported brood matures into eight living workers")
	var emerged_at: float = game.run.simulation_time
	test.check(pile.workers_total == 48 and pile.workers.invariant_holds(), "End-of-slice growth conserves ledger-owned workers")
	test.check(game.run.rain.phase == "finished" and game.run.trails.routes.size() >= 2, "Rain concludes once with useful routes still present")
	var outward: Dictionary = root.outward_status("home")
	var inward: Dictionary = root.inward_status("home")
	test.check(outward.rain_phase == "finished" and inward.food_exchange_state == "developed" and inward.brood_matured_total == 8, "Both views reflect end-of-slice semantic state")
	test.check(not outward.has("world") and not outward.has("terrain") and not inward.has("world") and not inward.has("terrain"), "Normal presentation remains detached from hidden world truth")
	test.check(game.run.to_dict().version == RunState.SNAPSHOT_VERSION, "Completed slice remains in the current save schema")
	print("[SLICE] carb=%.2fs rain=%.2fs build=%.2fs protein=%.2fs developed=%.2fs emergence=%.2fs routes=%d signals=%d" % [discovered_at, rain_at, development_at, protein_at, developed_at, emerged_at, game.run.trails.routes.size(), game.run.knowledge.nodes.size()])
	root.free()
	return true
