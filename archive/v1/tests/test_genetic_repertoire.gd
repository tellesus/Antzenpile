extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")


func run(test: Object) -> bool:
	var game := Controller.new(3901)
	var pile: PileState = game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 150.0)
	game.advance(360.0)
	test.check(game.start_adaptation("home", "lean") and pile.genetics.established.is_empty() and pile.genetics.living.is_empty(), "Selection captures a brood bundle without establishing genes or changing adults")
	test.check(pile.trial_cohort().inherited_traits == ["lean"], "Trial brood records its own captured phenotype")
	game.advance(360.0)
	test.check(pile.genetics.established == ["lean"] and pile.genetics.living == {"lean": 8}, "Surviving trial establishes repertoire and one disjoint adult bundle")
	test.check(game.start_brood("home") and pile.brood_cohorts[0].inherited_traits == ["lean"], "Ordinary brood captures established possibilities when laid")
	game.advance(360.0)
	test.check(pile.genetics.living == {"lean": 16} and pile.adapted_workers_total == 16, "Inherited adult emergence reconciles compatibility totals")
	var saved: Dictionary = snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Typed aggregate genetics survives exact JSON save restoration")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.colony.piles[0].erase("genetics")
	for record: Dictionary in legacy.colony.piles[0].brood_cohorts:
		record.erase("inherited_traits")
	test.check(copy.restore_snapshot(legacy) and copy.run.to_dict() == game.run.to_dict(), "Pre-repertoire saves infer foraging bundles without changing old phenotype")
	for mutation: String in ["double", "wrong", "unestablished", "duplicate", "dead"]:
		var invalid: Dictionary = saved.duplicate(true)
		match mutation:
			"double": invalid.colony.piles[0].genetics.living.lean = 17
			"wrong": invalid.colony.piles[0].genetics.established = ["load"]
			"unestablished": invalid.colony.piles[0].genetics.living.load = 8
			"duplicate": invalid.colony.piles[0].genetics.established = ["lean", "lean"]
			"dead": invalid.colony.piles[0].genetics.lost.lean = 1
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Inconsistent genetic save rejects atomically: " + mutation)
	var before: Dictionary = pile.to_dict()
	test.check(not pile.lose_workers("available", 1, 0, "Wrong subset", "lean") and pile.to_dict() == before, "Exact bundle mortality rejects a mismatched subset before mutation")
	test.check(pile.lose_workers("available", 3, 2, "Known loss") and pile.genetics.living == {"lean": 14} and pile.genetics.lost == {"lean": 2} and pile.workers.lost_total == 3, "Mixed mortality removes each ant from exactly one aggregate phenotype")
	test.check(copy.restore_snapshot(snapshot(game)), "Partial aggregate bundle mortality remains saveable")
	var root := Root.new()
	root.simulation = game
	var summary: Dictionary = root.inward_status("home")
	test.check(summary.genetic_repertoire == [{"id": "lean", "expressed": 14, "fraction": 14.0 / 61.0}], "Normal repertoire projects established genes and expected adult expression only")
	summary.genetic_repertoire[0].expressed = 900
	test.check(pile.genetics.count_trait("lean") == 14, "Normal genetic projection is detached from authoritative bundle state")
	root.free()
	_test_unreturned(test)
	return true


func _test_unreturned(test: Object) -> void:
	var game: SimulationController = load("res://tests/test_predator.gd").new()._fixture()
	game.set_trail_workers("route_1", 0)
	var pile: PileState = game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 200.0)
	game.advance(360.0)
	test.check(game.start_adaptation("home", "lean"), "Returned-genetics fixture begins an ordinary trial")
	game.advance(360.0)
	test.check(pile.lose_workers("available", 48, 0, "Known baseline losses") and game.set_trail_workers("route_1", 5), "Returned-genetics fixture sends an entirely expressed workforce")
	for tick: int in 500:
		if game.run.predator.kills_total > 0:
			break
		game.advance(0.25)
	var root := Root.new()
	root.simulation = game
	test.check(pile.genetics.count_trait("lean") == 7 and root.inward_status("home").genetic_repertoire[0].expressed == 8, "Physical adapted casualty stays absent from normal expression until home evidence")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)) and copy.run.to_dict() == game.run.to_dict(), "Private joint casualty evidence saves exactly during the journey")
	game.set_trail_workers("route_1", 0)
	game.advance(100.0)
	test.check(root.inward_status("home").genetic_repertoire[0].expressed == 7, "Delivered journey loss changes expected adult expression")
	root.free()


func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
