extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Ledger = preload("res://src/sim/colony/worker_ledger.gd")


func run(test: Object) -> bool:
	_test_ledger(test)
	_test_population_saves(test)
	_test_adaptation(test)
	return true


func _snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func _test_ledger(test: Object) -> void:
	var ledger := Ledger.new()
	test.check(ledger.add_living_workers("available", 40, "Founding") and ledger.create_commitment("outside", "other", "fixture") and ledger.allocate("outside", 8), "Mortality fixture uses disjoint real worker pools")
	test.check(ledger.remove_living_workers("outside", 3, "Encounter") and ledger.total == 37 and ledger.available == 32 and ledger.count("outside") == 5 and ledger.lost_total == 3 and ledger.invariant_holds(), "Committed losses debit pool and living total and record loss once")
	var before: Dictionary = ledger.to_dict()
	test.check(ledger.remove_living_workers("outside", 0, "No loss") and ledger.to_dict() == before, "Zero loss is a no-op")
	for args: Array in [["outside", 6], ["available", -1], ["available", 1.5], ["missing", 1], ["available", true]]:
		test.check(not ledger.remove_living_workers(args[0], args[1], "Invalid") and ledger.to_dict() == before, "Invalid mortality is atomic: %s" % [args])
	test.check(ledger.release("outside", 5) and ledger.retire_commitment("outside") and ledger.add_living_workers("available", 8, "Brood") and ledger.total == 45 and ledger.lost_total == 3, "Returns and births do not change cumulative losses")
	var copy := Ledger.new()
	test.check(copy.restore(JSON.parse_string(JSON.stringify(ledger.to_dict()))) and copy.to_dict() == ledger.to_dict(), "Ledger losses survive JSON restore")
	var capped: Dictionary = ledger.to_dict()
	capped.lost_total = Ledger.MAX_COUNT
	test.check(copy.restore(capped), "Ledger accepts largest exact historical loss counter")
	before = copy.to_dict()
	test.check(not copy.remove_living_workers("available", 1, "Overflow") and copy.to_dict() == before, "Loss counter overflow rejects before population mutation")
	var old: Dictionary = ledger.to_dict()
	old.erase("lost_total")
	test.check(copy.restore(old) and copy.lost_total == 0, "Older ledger records default loss history to zero")


func _test_population_saves(test: Object) -> void:
	var game := Controller.new(3045)
	var pile: PileState = game.run.colony.piles.home
	test.check(pile.lose_workers("available", 7, 0, "Known colony loss") and pile.workers_total == 33 and pile.workers.lost_total == 7, "Pile death API permits legitimate loss below founding population")
	test.check(pile.workers.create_commitment("test_loss", "other", "fixture") and pile.workers.allocate("test_loss", 10) and pile.lose_workers("test_loss", 4, 0, "Committed loss"), "Pile loss API removes only requested commitment workers")
	test.check(pile.workers.count("test_loss") == 6 and pile.workers_available == 23 and pile.workers_total == 29 and pile.workers.lost_total == 11 and pile.workers.invariant_holds(), "Surviving commitment and available labor remain disjoint")
	test.check(pile.workers.release("test_loss", 6) and pile.workers.retire_commitment("test_loss"), "Commitment owner returns surviving workers")
	var saved: Dictionary = _snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Post-loss version-5 run restores atomically")
	for field: String in ["missing", "negative", "fractional", "insufficient"]:
		var invalid: Dictionary = saved.duplicate(true)
		match field:
			"missing": invalid.colony.piles[0].workers.erase("lost_total")
			"negative": invalid.colony.piles[0].workers.lost_total = -1
			"fractional": invalid.colony.piles[0].workers.lost_total = 10.5
			"insufficient": invalid.colony.piles[0].workers.lost_total = 10
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Invalid population-loss history rejects atomically: " + field)
	var before: Dictionary = pile.to_dict()
	test.check(not pile.lose_workers("available", 1, 1, "No adapted adult") and not pile.lose_workers("available", 1, 2, "Invalid subset") and not pile.lose_workers("available", 100, 0, "Over-loss") and not pile.lose_workers("available", 1, 0, "") and pile.to_dict() == before, "Pile validation fails before either ledger or adaptation mutation")
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(60.0)
	test.check(game.run.to_dict() == paused, "Pause freezes a post-loss run")
	game.toggle_pause()
	copy.set_time_scale(4)
	game.advance(10.0)
	copy.advance(2.5)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Post-loss continuation matches save and speed")
	var legacy: Dictionary = _snapshot(Controller.new(3046))
	legacy.colony.piles[0].workers.erase("lost_total")
	legacy.colony.piles[0].erase("adapted_workers_lost")
	test.check(copy.restore_snapshot(legacy) and copy.run.colony.piles.home.workers.lost_total == 0 and copy.run.colony.piles.home.adapted_workers_lost == 0, "Old version-5 run remains compatible with no-death defaults")


func _test_adaptation(test: Object) -> void:
	var game := Controller.new(3901)
	var pile: PileState = game.run.colony.piles.home
	for resource_id: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource_id, 150.0)
	test.check(game.dispatch_scout("home", 0.0), "Adapted mortality fixture scouts an ordinary source")
	game.advance(360.0)
	test.check(game.start_adaptation("home", "lean"), "Mortality fixture starts funded adaptation through ordinary command")
	game.advance(360.0)
	test.check(pile.adapted_workers_total == 8 and pile.workers_total == 56 and game.create_trail("home", "known:carb_exposed"), "Adapted adults and an ordinary route exist before loss")
	game.advance(0.25)
	var cohort: TransitCohort = game.run.trails.cohorts.cohort_1
	var captured_energy: float = cohort.energy_multiplier
	test.check(pile.lose_workers("available", 2, 1, "Mixed adult loss") and pile.adapted_workers_total == 7 and pile.adapted_workers_lost == 1 and pile.workers_total == 54, "Partial adapted loss preserves lifetime emergence without eight-ant live-count restriction")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(_snapshot(game)) and copy.run.to_dict() == game.run.to_dict(), "Captured departure phenotype restores after current adaptation share falls")
	test.check(pile.lose_workers("available", 7, 7, "Remaining adapted adults lost") and pile.adapted_workers_total == 0 and pile.adapted_workers_lost == 8 and pile.adaptation_repertoire == "lean" and pile.adaptation_fraction() == 0.0, "Repertoire persists when all adapted adults are gone")
	test.check(cohort.energy_multiplier == captured_energy and copy.restore_snapshot(_snapshot(game)), "Old journey keeps its captured phenotype after adapted adults die")
	var saved: Dictionary = _snapshot(game)
	for field: String in ["negative", "too_many", "noncohort", "repertoire"]:
		var invalid: Dictionary = saved.duplicate(true)
		match field:
			"negative": invalid.colony.piles[0].adapted_workers_lost = -1
			"too_many": invalid.colony.piles[0].adapted_workers_lost = 16
			"noncohort": invalid.colony.piles[0].adapted_workers_lost = 7
			"repertoire": invalid.colony.piles[0].adaptation_repertoire = ""
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Invalid adapted-loss history rejects: " + field)
	test.check(game.set_trail_workers("route_1", 0), "Mortality fixture recalls surviving route workers")
	game.advance(100.0)
	test.check(game.start_brood("home") and pile.brood_cohorts[0].adaptation_id == "lean", "Later brood still inherits repertoire with zero adapted adults alive")
	game.advance(180.0)
	test.check(copy.restore_snapshot(_snapshot(game)), "Inherited brood after loss saves mid-development")
	game.advance(180.0)
	copy.set_time_scale(4)
	copy.advance(45.0)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict() and pile.adapted_workers_total == 8 and pile.adapted_workers_lost == 8 and pile.workers_total == 55, "New emergence restores live adaptation share and exact post-loss continuation")
