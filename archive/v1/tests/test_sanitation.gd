extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const CONFIG = preload("res://data/resources/default_sanitation.tres")


func fixture(burden: int = CONFIG.strain_units) -> SimulationController:
	var game := Controller.new(64)
	var pile: PileState = game.run.colony.piles.home
	# Unit fixture, separate from the unfunded gameplay measurement.
	pile.midden.generated_units = burden
	pile.midden.revealed = true
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 100)
	return game


func run(test: Object) -> bool:
	_test_accounting_and_staff(test)
	_test_pressure(test)
	_test_development_and_restore(test)
	_test_view(test)
	return true


func _test_accounting_and_staff(test: Object) -> void:
	var game := Controller.new()
	var pile: PileState = game.run.colony.piles.home
	var initial: Dictionary = game.run.to_dict()
	test.check(not game.set_sanitation_workers("home", 2) and not game.start_midden("home") and initial == game.run.to_dict(), "Latent need cannot hire cleaners or develop")
	game.advance(400)
	test.check(pile.midden.revealed and pile.midden.burden_units > 0 and pile.midden.cleaners == 0, "Ordinary colony activity reveals Midden need")
	test.check(not game.start_midden("home"), "Real starting stores cannot pay for development")
	initial = game.run.to_dict()
	for invalid: Variant in [-1, 1.5, 9, "2", null]:
		test.check(not game.set_sanitation_workers("home", invalid) and game.run.to_dict() == initial, "Invalid cleaner allocation rejects atomically")
	test.check(not game.set_sanitation_workers("missing", 2) and game.run.to_dict() == initial, "Unknown pile rejects cleanup")
	test.check(game.set_sanitation_workers("home", 2) and pile.workers.count("sanitation:home") == 2, "Basic isolation commits real ledger workers")
	var burden: int = pile.midden.burden_units
	game.advance(60)
	test.check(pile.midden.burden_units < burden and pile.midden.generated_units == pile.midden.isolated_units + pile.midden.burden_units, "Cleanup reduces burden and conserves all generated material")
	game.advance(300)
	test.check(pile.midden.burden_units == 0 and pile.midden.isolated_units == pile.midden.generated_units, "Cleanup clamps to available refuse without creating resource credits")
	var total: int = pile.workers_total
	var available: int = pile.workers_available
	test.check(game.set_sanitation_workers("home", 0) and pile.workers_available == available + 2 and pile.workers_total == total and pile.workers.count("sanitation:home") == -1, "Internal cleanup releases immediately and retires empty job")
	test.check(pile.workers.create_commitment("test:busy", "other", "test") and pile.workers.allocate("test:busy", pile.workers_available), "Fixture commits available workers")
	initial = game.run.to_dict()
	test.check(not game.set_sanitation_workers("home", 1) and game.run.to_dict() == initial, "Scarce workers cannot be borrowed from another job")
	test.check(pile.workers.invariant_holds(), "Sanitation preserves population conservation")


func _test_pressure(test: Object) -> void:
	for burden: int in [CONFIG.reveal_units, CONFIG.strain_units, CONFIG.heavy_units]:
		var game := fixture(burden)
		var pile: PileState = game.run.colony.piles.home
		var cohort: BroodCohort = pile.brood_cohorts[0]
		cohort.stage = "larva"
		var rate: float = pile.midden.larval_rate()
		var stores: Dictionary = pile.resources.duplicate()
		game.brood.tick(1.0)
		test.check(cohort.progress_seconds == rate and cohort.care == 1.0 and cohort.nutrition == 1.0, "Sanitation slows larval development separately from care and nutrition")
		var protein_cost: float = preload("res://data/resources/default_brood.tres").protein_per_larva_second * cohort.count * rate
		test.check(is_equal_approx(stores.protein - pile.resources.protein, protein_cost), "Slowed progress consumes proportional food without extra tax")
		cohort.stage = "egg"
		cohort.progress_seconds = 0
		game.brood.tick(1.0)
		test.check(cohort.progress_seconds == 1.0, "Sanitation pressure does not slow eggs")
		cohort.stage = "pupa"
		cohort.progress_seconds = 0
		game.brood.tick(1.0)
		test.check(cohort.progress_seconds == 1.0 and pile.brood_lost_total == 0, "Sanitation adds neither pupal slowdown nor mortality")
	var game := fixture(CONFIG.strain_units + 100)
	var pile: PileState = game.run.colony.piles.home
	test.check(game.set_sanitation_workers("home", 5), "Cleaners assigned during strain")
	game.advance(0.25)
	test.check(pile.midden.larval_rate() == 1.0, "Isolation relieves strain as soon as burden crosses back below threshold")


func _test_development_and_restore(test: Object) -> void:
	var game := fixture()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.set_sanitation_workers("home", 2), "Cleanup and excavation can coexist")
	var stores: Dictionary = pile.resources.duplicate()
	test.check(game.start_midden("home") and pile.workers.count("midden:home") == 4 and pile.workers_available == 34, "Development commits four distinct excavation workers")
	for resource: String in CONFIG.costs():
		test.check(is_equal_approx(stores[resource] - pile.resources[resource], CONFIG.costs()[resource]), "Development pays authored cost once: " + resource)
	var initial: Dictionary = game.run.to_dict()
	test.check(not game.start_midden("home") and game.run.to_dict() == initial, "Duplicate development rejects atomically")
	game.advance(40)
	var saved: Dictionary = Snapshot.new().snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "JSON midpoint restores cleanup and excavation accounting exactly")
	initial = copy.run.to_dict()
	copy.toggle_pause()
	var paused: Dictionary = copy.run.to_dict()
	copy.advance(30)
	test.check(copy.run.to_dict() == paused, "Pause freezes generation, cleanup, build and brood")
	copy.toggle_pause()
	for scale: int in [1, 4, 16, 64]:
		var replay := Controller.new()
		test.check(replay.restore_snapshot(saved), "Midpoint restores at speed " + str(scale))
		replay.set_time_scale(scale)
		replay.advance(40.0 / scale)
		replay.set_time_scale(1)
		if scale == 1:
			copy = replay
		test.check(replay.run.to_dict() == copy.run.to_dict(), "Sanitation continuation is identical at speed " + str(scale))
	game.advance(49.75)
	test.check(pile.midden.state == "developing" and pile.midden.progress_ticks == 359, "Construction benefit waits for full 90 seconds")
	var isolated: int = pile.midden.isolated_units
	game.advance(0.25)
	test.check(pile.midden.state == "developed" and pile.workers.count("midden:home") == -1 and pile.workers.count("sanitation:home") == 2 and pile.midden.isolated_units - isolated == 2000, "Completion releases excavators and doubles existing cleanup efficiency")
	initial = copy.run.to_dict()
	for field: String in ["isolated_units", "remainder_quarters", "cleaners", "revealed", "progress_ticks", "state"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.colony.piles[0].midden[field] = {"isolated_units": saved.colony.piles[0].midden.generated_units + 1, "remainder_quarters": 4, "cleaners": 9, "revealed": 1, "progress_ticks": CONFIG.build_ticks, "state": "unknown"}[field]
		test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == initial, "Invalid sanitation save rejects atomically: " + field)
	var bad: Dictionary = saved.duplicate(true)
	bad.colony.piles[0].workers.commitments["sanitation:home"].count = 1
	bad.colony.piles[0].workers.available += 1
	initial = copy.run.to_dict()
	test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == initial, "Save must reconcile cleaner commitment")
	bad = saved.duplicate(true)
	bad.colony.piles[0].workers.commitments["midden:away"] = bad.colony.piles[0].workers.commitments["midden:home"]
	bad.colony.piles[0].workers.commitments.erase("midden:home")
	test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == initial, "Cross-pile excavation cannot masquerade as valid labor")
	var legacy := Controller.new()
	var old: Dictionary = Snapshot.new().snapshot(legacy)
	old.colony.piles[0].erase("midden")
	test.check(legacy.restore_snapshot(old) and legacy.run.colony.piles.home.midden.generated_units == 0, "Legacy saves start sanitation at zero without retroactive burden")
	var occupied := fixture()
	pile = occupied.run.colony.piles.home
	test.check(pile.workers.create_commitment("test:busy", "other", "test") and pile.workers.allocate("test:busy", 37), "Development shortage fixture leaves three workers")
	initial = occupied.run.to_dict()
	test.check(not occupied.start_midden("home") and not occupied.start_midden("missing") and occupied.run.to_dict() == initial, "Unknown or understaffed development rejects without payment")
	var developed := Controller.new()
	test.check(developed.restore_snapshot(Snapshot.new().snapshot(game)), "Completed Midden and ongoing cleanup restore")
	game.advance(15)
	developed.advance(15)
	test.check(developed.run.to_dict() == game.run.to_dict(), "Developed cleanup continues exactly after JSON save")


func _test_view(test: Object) -> void:
	var game := fixture()
	var root := Root.new()
	root.simulation = game
	var view: InwardView = View.new()
	view.status_provider = root.inward_status.bind("home")
	view.sanitation_command = root.set_sanitation_workers
	view.midden_develop_command = root.start_midden
	test.get_root().add_child(view)
	view._process(0)
	var size: Vector2 = view.get_viewport_rect().size
	test.check(View.node_at(View.positions(size).midden, size) == "" and View.node_at(View.positions(size).midden, size, false, true) == "midden", "Midden organ is selectable only after need reveals it")
	test.check(view.activate_at(View.positions(size).midden) and view.selected_id == "midden", "Midden selection opens its own functional panel")
	for count: int in [1, 2, 5, 0]:
		test.check(view.activate_at(view._cleaner_rect(count).get_center()) and game.run.colony.piles.home.midden.cleaners == count, "Shared pointer path assigns cleaners: " + str(count))
	view._process(0)
	test.check(view.activate_at(view._midden_develop_rect().get_center()) and game.run.colony.piles.home.midden.state == "developing", "Separate development action builds Midden")
	var summary: Dictionary = root.inward_status("home")
	summary.midden.costs.water = 999
	summary.midden.burden = 0
	test.check(root.inward_status("home").midden.costs.water == CONFIG.water_cost and game.run.colony.piles.home.midden.burden_units > 0, "INWARD sanitation summary is detached from authored config and live material")
	view.free()
	root.free()
