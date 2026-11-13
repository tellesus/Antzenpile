extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Config = preload("res://data/resources/default_nursery_development.tres")
const Activity = preload("res://src/presentation/inward/colony_activity.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))

func needed() -> SimulationController:
	var game := Controller.new(77)
	var pile: PileState = game.run.colony.piles.home
	for id: String in PileState.RESOURCE_IDS: pile.deposit_resource(id, 1000)
	game.start_nursery_development("home")
	game.advance(90)
	game.set_humidity_workers("home", 1)
	game.start_brood("home")
	game.advance(370)
	game.start_brood("home")
	game.start_brood("home")
	return game

func run(test: Object) -> bool:
	var game := Controller.new(77)
	var before: Dictionary = game.run.to_dict()
	test.check(not game.start_nursery_expansion("home") and not game.start_nursery_expansion("missing") and game.run.to_dict() == before, "Unrevealed/unknown expansion rejects atomically")
	game = needed()
	var pile: PileState = game.run.colony.piles.home
	test.check(pile.brood_matured_total == 16 and pile.nursery_occupied_space() == 16 and pile.nursery_expansion_state == "latent", "Mature growth and full existing capacity precede need detection")
	var legacy: Dictionary = snapshot(game)
	legacy.colony.piles[0].erase("nursery_expansion")
	var legacy_copy := Controller.new()
	test.check(legacy_copy.restore_snapshot(legacy) and legacy_copy.run.colony.piles.home.nursery_brood_capacity() == 16, "Older saved developed Nursery restores without a free expansion")
	game.advance(0.25)
	test.check(pile.nursery_expansion_state == "available", "Fixed simulation detects full Nursery after demonstrated growth")
	pile.resources.carbohydrate = 0 # Isolate unaffordable rejection after real need detection.
	before = game.run.to_dict()
	test.check(not game.start_nursery_expansion("home") and game.run.to_dict() == before, "Unaffordable expansion never transfers labor or advances state")
	pile.deposit_resource("carbohydrate", 1000)
	var reserved: int = pile.workers_available - 7
	pile.workers.create_commitment("test:busy", "other", "busy")
	pile.workers.allocate("test:busy", reserved)
	before = game.run.to_dict()
	test.check(not game.start_nursery_expansion("home") and game.run.to_dict() == before, "Expansion requires eight available excavators before payment")
	pile.workers.release("test:busy", reserved)
	pile.workers.retire_commitment("test:busy")
	var costs_before: Dictionary = pile.resources.duplicate()
	test.check(game.start_nursery_expansion("home") and pile.workers.count("nursery_expansion:home") == 8 and is_equal_approx(costs_before.carbohydrate - pile.resources.carbohydrate, 60.0) and is_equal_approx(costs_before.protein - pile.resources.protein, 24.0) and is_equal_approx(costs_before.water - pile.resources.water, 12.0), "Expansion prepays real costs and ledger-accounted excavation exactly once")
	before = game.run.to_dict()
	test.check(not game.start_nursery_expansion("home") and game.run.to_dict() == before, "Duplicate expansion cannot charge or reserve again")
	game.toggle_pause()
	game.advance(20)
	test.check(pile.nursery_expansion_progress == 0.0, "Paused construction remains frozen")
	game.toggle_pause()
	game.advance(179.75)
	test.check(pile.nursery_brood_capacity() == 16 and pile.nursery_state == "developed" and pile.nursery_expansion_progress == 179.75 and pile.humidity.carers == 1 and pile.humidity.water_used_units > 0, "Existing capacity, brood and paid climate stay online while expansion is incomplete")
	before = game.run.to_dict()
	test.check(not game.start_brood("home") and game.run.to_dict() == before, "Incomplete expansion cannot supply a third cohort's space")
	var saved: Dictionary = snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Mid-expansion progress and excavation commitment restore exactly")
	var intact: Dictionary = copy.run.to_dict()
	for alteration: String in ["missing", "count", "owner", "cross_pile", "phase", "progress", "early"]:
		var invalid: Dictionary = saved.duplicate(true)
		var home: Dictionary = invalid.colony.piles[0]
		match alteration:
			"missing": home.workers.commitments.erase("nursery_expansion:home"); home.workers.available += 8
			"count": home.workers.commitments["nursery_expansion:home"].count = 7; home.workers.available += 1
			"owner": home.workers.commitments["nursery_expansion:home"].owner_id = "other"
			"cross_pile": home.workers.commitments["nursery_expansion:other"] = home.workers.commitments["nursery_expansion:home"]; home.workers.commitments.erase("nursery_expansion:home")
			"phase": home.nursery_expansion.state = "latent"; home.nursery_expansion.progress_seconds = 0
			"progress": home.nursery_expansion.progress_seconds = Config.expansion_seconds
			"early": home.nursery_state = "primitive"; home.nursery_progress_seconds = 0
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Malformed " + alteration + " expansion save rejects atomically")
	game.advance(0.25)
	copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict() and pile.nursery_brood_capacity() == 32 and pile.nursery_max_care_capacity() == 32 and pile.workers.count("nursery_expansion:home") == -1, "Completion enables doubled capacity and releases excavators exactly once after reload")
	test.check(game.start_brood("home") and game.start_brood("home") and pile.brood_cohorts.size() == 4 and pile.nursery_occupied_space() == 32 and not game.start_brood("home"), "Expanded Nursery supports four bounded cohorts but rejects a fifth")
	var grown := Controller.new()
	test.check(grown.restore_snapshot(snapshot(game)), "Completed four-cohort state has valid serialized capacity and lineage accounting")
	game.advance(60); grown.advance(60)
	test.check(game.run.to_dict() == grown.run.to_dict() and pile.workers.invariant_holds(), "Expanded brood and physiology preserve exact JSON continuation and worker conservation")
	var expanded_before: Dictionary = game.run.to_dict()
	test.check(not game.start_nursery_expansion("home") and game.run.to_dict() == expanded_before, "Completed expansion cannot charge or release labor again")
	var root := Root.new()
	root.simulation = game
	var summary: Dictionary = root.inward_status("home")
	test.check(Activity.brood_stages(summary).size() == 6 and "egg" in Activity.brood_stages(summary) and "larva" in Activity.brood_stages(summary), "Four-cohort visual groups remain represented within six glyphs")
	root.free()
	var care_reserve: int = pile.workers_available - 2
	pile.workers.create_commitment("test:care", "other", "care")
	pile.workers.allocate("test:care", care_reserve)
	game.advance(0.25)
	test.check(pile.nursery_care_capacity() == 8 and pile.brood_cohorts.any(func(cohort): return cohort.care < 1.0), "Expanded brood still needs real available care, rather than free capacity granting care")
	pile.workers.release("test:care", care_reserve)
	pile.workers.retire_commitment("test:care")
	var sticky := needed()
	sticky.advance(0.25)
	sticky.advance(370)
	test.check(sticky.run.colony.piles.home.nursery_expansion_state == "available" and sticky.run.colony.piles.home.nursery_occupied_space() < 16, "Detected expansion need remains available after brood turnover")
	var reference := Controller.new()
	reference.restore_snapshot(saved)
	reference.advance(0.25)
	for scale: int in [1, 4, 16, 64]:
		var paced := Controller.new()
		paced.restore_snapshot(saved)
		paced.set_time_scale(scale)
		paced.advance(0.25 / scale)
		paced.set_time_scale(1)
		test.check(paced.run.to_dict() == reference.run.to_dict(), "Expansion completion uses fixed ticks at " + str(scale) + "x")
	var view := View.new()
	test.get_root().add_child(view)
	test.check(not view._nursery_expand_rect().intersects(view._brood_rect()) and not view._nursery_expand_rect().intersects(view._button_rect("pause")) and view._nursery_expand_rect().size.y == 44, "Expansion, brood and clock retain separate touch targets")
	view.free()
	return true
