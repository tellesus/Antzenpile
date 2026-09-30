extends RefCounted
## Longer authored-world run; commands follow the same path available to a player.

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
	test.check(game.dispatch_scout("home", 0.0) and game.dispatch_scout("home", PI), "Extended run starts with east and west scouts")
	game.advance(12.0)
	test.check(game.run.knowledge.nodes.is_empty() and root.sensory_snapshot("home").is_empty(), "Private early evidence stays out of OUTWARD")
	var carbohydrate_known: bool = _advance_until(game, func() -> bool: return game.run.knowledge.nodes.has("known:carb_exposed") and game.run.knowledge.nodes.has("known:carb_sheltered"), 150.0)
	test.check(carbohydrate_known, "Returned scouts locate both carbohydrate sources")
	if not carbohydrate_known:
		root.free()
		return true
	test.check(game.create_trail("home", "known:carb_exposed") and game.create_trail("home", "known:carb_sheltered"), "Player funds two carbohydrate trails")
	test.check(game.dispatch_scout("home", 2.0), "Player sends another scout toward protein")
	test.check(_advance_until(game, func() -> bool: return game.run.rain.phase == "raining", 100.0), "Resource traffic triggers the existing rain event")
	var development_at: float = game.run.simulation_time
	test.check(game.start_food_exchange("home") and pile.food_exchange_state == "developing" and pile.brood_cohorts[0].stage == "egg" and not game.run.knowledge.nodes.has("known:protein_01"), "Food Exchange remains an early project before protein discovery or brood pressure")
	test.check(_advance_until(game, func() -> bool: return game.run.knowledge.nodes.has("known:protein_01"), 150.0), "Protein scout returns knowledge")
	test.check(game.create_trail("home", "known:protein_01"), "Player funds protein collection")
	var first_emerged: bool = _advance_until(game, func() -> bool: return pile.brood_matured_total == 8, 500.0)
	test.check(first_emerged and pile.food_exchange_state == "developed" and root.music_state("home").development_level == 1 and pile.workers_total == 48, "Early Food Exchange and first brood complete with semantic music reward")
	if not first_emerged:
		root.free()
		return true
	var first_at: float = game.run.simulation_time
	test.check(game.start_brood("home") and pile.brood_cohorts[0].id == "brood_2", "Player begins another cycle after emergence")
	var stalled: bool = _advance_until(game, func() -> bool: return pile.brood_cohorts[0].stage == "larva" and pile.brood_cohorts[0].nutrition == 0.0, 500.0)
	test.check(stalled and pile.resources.water == 0.0 and pile.workers_total == 48, "Second cohort waits when stored water is exhausted")
	if not stalled:
		root.free()
		return true
	var stalled_at: float = game.run.simulation_time
	var stalled_progress: float = pile.brood_cohorts[0].progress_seconds
	game.advance(10.0)
	test.check(pile.brood_cohorts[0].progress_seconds == stalled_progress and pile.brood_matured_total == 8, "Water shortage holds growth without losing the cohort")
	test.check(game.dispatch_scout("home", -PI / 2.0), "Player searches north for water")
	game.advance(2.0)
	test.check(not game.run.knowledge.nodes.has("known:water_01"), "Water stays private while its scout is away")
	var water_known: bool = _advance_until(game, func() -> bool: return game.run.knowledge.nodes.has("known:water_01"), 500.0)
	test.check(water_known and root.sensory_snapshot("home").size() >= 4, "Returned water evidence becomes a player-facing signal")
	if not water_known:
		root.free()
		return true
	var water_at: float = game.run.simulation_time
	test.check(game.create_trail("home", "known:water_01"), "Player funds a trail from returned water knowledge")
	game.advance(0.25)
	var snapshot: Dictionary = game.run.to_dict()
	var copy := Controller.new()
	test.check(not game.run.trails.cohorts.is_empty() and copy.restore_snapshot(JSON.parse_string(JSON.stringify(snapshot, "", true, true))) and copy.run.to_dict() == snapshot, "Mid-second-cycle water travel restores exactly")
	for tick: int in 100:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Water-route continuation matches after 100 fixed ticks")
	var prior_ticks: int = game.run.clock.tick_count
	var second_emerged: bool = _advance_until(game, func() -> bool: return pile.brood_matured_total == 16, 1000.0)
	test.check(second_emerged and pile.workers_total == 56 and pile.workers.invariant_holds() and pile.resources.water > 0.0, "Water delivery supports a second emergence with conserved workers")
	if second_emerged:
		copy.advance(float(game.run.clock.tick_count - prior_ticks) * SimulationClock.TICK_INTERVAL)
		test.check(game.run.to_dict() == copy.run.to_dict(), "Saved extended run reaches the same second emergence")
	var inward: Dictionary = root.inward_status("home")
	var outward: Dictionary = root.outward_status("home")
	test.check(inward.brood_matured_total == 16 and inward.resources.water == pile.resources.water and outward.resources.water == pile.resources.water, "Both normal views receive approved updated colony stores")
	test.check(not inward.has("world") and not outward.has("world") and not outward.has("terrain"), "Extended presentation remains detached from hidden truth")
	print("[EXTENDED] develop=%.2fs first=%.2fs water_stall=%.2fs water_known=%.2fs second=%.2fs workers=%d stores=%s" % [development_at, first_at, stalled_at, water_at, game.run.simulation_time, pile.workers_total, pile.resources])
	root.free()
	return true
