extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const TransitFixture = preload("res://tests/test_transit.gd")
const TRAILS = preload("res://data/trails/default_trails.tres")


func run(test: Object) -> bool:
	_test_trial(test)
	_test_traits_and_routes(test)
	_test_ui(test)
	return true


func _fund(game: SimulationController) -> PileState:
	var pile: PileState = game.run.colony.piles.home
	for resource_id: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource_id, 150.0)
	game.advance(360.0)
	return pile


func _roundtrip(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func _test_trial(test: Object) -> void:
	var game := Controller.new(3901)
	var pile: PileState = game.run.colony.piles.home
	var before: Dictionary = game.run.to_dict()
	test.check(not game.start_adaptation("home", "lean") and game.run.to_dict() == before, "Occupied Primitive Nursery rejects a trial without changing stores or labor")
	pile = _fund(game)
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", "unknown") and game.run.to_dict() == before, "Unknown adaptation rejects atomically")
	pile.resources.protein = 11.0
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", "lean") and game.run.to_dict() == before, "Insufficient protein rejects the full trial atomically")
	pile.deposit_resource("protein", 10.0)
	var stores: Dictionary = pile.resources.duplicate()
	test.check(game.start_adaptation("home", "lean") and pile.trial_cohort() != null and pile.trial_cohort().id == "brood_2", "Trial creates one ordinary eight-ant cohort in Nursery space")
	test.check(pile.resources.carbohydrate == stores.carbohydrate - 12.0 and pile.resources.protein == stores.protein - 12.0 and pile.resources.water == stores.water - 6.0 and pile.workers.count("adaptation:home") == 2 and pile.workers.invariant_holds(), "Trial pays stores and reserves exactly two nurses through the ledger")
	test.check(pile.adaptation_repertoire == "" and pile.adapted_workers_total == 0 and pile.adaptation_fraction() == 0.0, "Genome choice has no adult expression before trial emergence")
	test.check(pile.workers.create_commitment("test:busy", "other", "busy") and pile.workers.allocate("test:busy", pile.workers_available), "Care fixture commits every worker except the two trial nurses")
	game.advance(0.25)
	test.check(pile.workers_available == 0 and pile.nursery_care_capacity() == 8 and pile.trial_cohort().care == 1.0 and pile.trial_cohort().progress_seconds == 0.25, "Dedicated nurses remain effective carers while unavailable for other work")
	test.check(pile.workers.release("test:busy", pile.workers.count("test:busy")) and pile.workers.retire_commitment("test:busy"), "Care fixture returns all borrowed labor through the ledger")
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", "load") and game.run.to_dict() == before, "One pending trial prevents a second choice or charge")
	var mid: Dictionary = _roundtrip(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(mid) and copy.run.to_dict() == game.run.to_dict(), "Mid-trial save preserves brood and nurse commitment exactly")
	var invalid: Dictionary = mid.duplicate(true)
	invalid.colony.piles[0].workers.commitments.erase("adaptation:home")
	invalid.colony.piles[0].workers.available += 2
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Missing trial nurses reject atomically")
	invalid = mid.duplicate(true)
	invalid.colony.piles[0].adaptation_repertoire = "load"
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Repertoire cannot be active while trial brood is immature")
	game.advance(180.0)
	copy.advance(180.0)
	test.check(game.run.to_dict() == copy.run.to_dict() and pile.trial_cohort().stage == "larva" and pile.adapted_workers_total == 0, "Egg stage and save continuation remain deterministic without premature effect")
	game.advance(180.0)
	copy.advance(180.0)
	test.check(game.run.to_dict() == copy.run.to_dict() and pile.trial_cohort() == null and pile.adaptation_repertoire == "lean" and pile.adapted_workers_total == 8, "Trait enters repertoire and eight workers only on emergence")
	test.check(pile.workers.count("adaptation:home") == -1 and pile.workers_total == 56 and pile.workers_available == 56 and pile.workers.invariant_holds(), "Trial nurses return and emerged workers enter ledger exactly once")
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", "load") and game.run.to_dict() == before, "Completed repertoire cannot be switched or charged again")
	test.check(game.start_brood("home") and pile.brood_cohorts[0].adaptation_id == "lean" and not pile.brood_cohorts[0].adaptation_trial, "Later ordinary brood inherits repertoire without new trial charge")
	game.advance(360.0)
	test.check(pile.adapted_workers_total == 16 and pile.workers_total == 64 and pile.adaptation_fraction() == 0.25, "Inherited cohort raises expressed workforce share only when it emerges")
	var legacy := Controller.new()
	var old: Dictionary = _roundtrip(Controller.new(3902))
	old.colony.piles[0].erase("adaptation_repertoire")
	old.colony.piles[0].erase("adapted_workers_total")
	for cohort: Dictionary in old.colony.piles[0].brood_cohorts:
		cohort.erase("adaptation_id")
		cohort.erase("adaptation_trial")
	test.check(legacy.restore_snapshot(old) and legacy.run.colony.piles.home.adaptation_repertoire == "" and legacy.run.colony.piles.home.adapted_workers_total == 0, "Older version-five saves default to no adaptation")
	invalid = _roundtrip(game)
	invalid.colony.piles[0].adapted_workers_total = 900
	before = game.run.to_dict()
	test.check(not game.restore_snapshot(invalid) and game.run.to_dict() == before, "Impossible adapted population rejects atomically")


func _test_traits_and_routes(test: Object) -> void:
	var pending: SimulationController = TransitFixture.new().learned_game()
	var waiting: PileState = _fund(pending)
	test.check(pending.start_adaptation("home", "lean"), "Pending-effect fixture begins a funded trial")
	pending.advance(359.75)
	test.check(waiting.trial_cohort() != null and waiting.trial_cohort().stage == "pupa" and waiting.adaptation_fraction() == 0.0, "Nearly emerged trial still leaves adult workforce at baseline")
	test.check(pending.create_trail("home", "known:carb_exposed"), "Known trail starts just before trial emergence")
	pending.advance(0.25)
	var old_cohort: TransitCohort = pending.run.trails.cohorts.cohort_1
	test.check(waiting.adaptation_fraction() > 0.0 and old_cohort.energy_multiplier == 1.0 and old_cohort.carry_multiplier == 1.0, "Cohort departing before emergence keeps baseline multipliers after brood emerges")
	var pending_save: Dictionary = _roundtrip(pending)
	var pending_copy := Controller.new()
	test.check(pending_copy.restore_snapshot(pending_save) and pending_copy.run.to_dict() == pending.run.to_dict(), "Baseline in-flight cohort remains valid after repertoire appears")
	var old_cohort_save: Dictionary = pending_save.duplicate(true)
	old_cohort_save.trails.cohorts[0].erase("energy_multiplier")
	old_cohort_save.trails.cohorts[0].erase("carry_multiplier")
	var older_copy := Controller.new()
	test.check(older_copy.restore_snapshot(old_cohort_save) and older_copy.run.trails.cohorts.cohort_1.energy_multiplier == 1.0 and older_copy.run.trails.cohorts.cohort_1.carry_multiplier == 1.0, "Older in-flight cohort fields default to baseline after repertoire emergence")
	for trait_id: String in ["lean", "load"]:
		var game: SimulationController = TransitFixture.new().learned_game()
		var pile: PileState = _fund(game)
		test.check(game.start_adaptation("home", trait_id), "Funded trial starts for " + trait_id)
		game.advance(360.0)
		var share: float = pile.adaptation_fraction()
		test.check(share == 8.0 / 56.0 and game.create_trail("home", "known:carb_exposed"), "Adapted share and route investment are available for " + trait_id)
		var before_carb: float = pile.resources.carbohydrate
		game.advance(0.25)
		var cohort: TransitCohort = game.run.trails.cohorts.cohort_1
		var segment: TrailSegmentState = game.run.trails.segments.segment_1
		var base: float = TRAILS.round_trip_energy_cost(cohort.worker_count, segment.start.distance_to(segment.end), TrailSegmentState.terrain_cost_for(game.run.world, segment.start, segment.end))
		var expected_energy: float = AdaptationRules.energy_multiplier(trait_id, share)
		var expected_carry: float = AdaptationRules.carry_multiplier(trait_id, share)
		test.check(is_equal_approx(cohort.energy_multiplier, expected_energy) and is_equal_approx(cohort.carry_multiplier, expected_carry), "Departure captures the expressed share for " + trait_id)
		test.check(is_equal_approx(before_carb - pile.resources.carbohydrate, base * expected_energy), "Travel energy changes in the documented direction for " + trait_id)
		var saved: Dictionary = _roundtrip(game)
		var copy := Controller.new()
		test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Adapted in-flight cohort restores exactly for " + trait_id)
		var invalid: Dictionary = saved.duplicate(true)
		invalid.trails.cohorts[0].carry_multiplier = 1.3 if trait_id == "lean" else 0.85
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Inconsistent captured trait multipliers reject for " + trait_id)
		game.advance(4.25)
		copy.advance(4.25)
		test.check(game.run.to_dict() == copy.run.to_dict(), "Adapted route continues exactly after save for " + trait_id)
		var first: TransitCohort = game.run.trails.cohorts.get("cohort_1")
		test.check(first != null and is_equal_approx(first.carry_multiplier, expected_carry), "In-flight carry multiplier stays captured for " + trait_id)
		if first != null and first.direction == "inbound":
			test.check(is_equal_approx(first.payload, first.worker_count * TRAILS.carry_per_worker * expected_carry), "Collected cargo uses captured capacity for " + trait_id)


func _test_ui(test: Object) -> void:
	var root := Root.new()
	root.simulation = Controller.new(3903)
	var pile: PileState = _fund(root.simulation)
	var ui := View.new()
	test.get_root().add_child(ui)
	ui.selected_id = "adaptation"
	ui._status = root.inward_status("home")
	ui.adaptation_command = root.queue_adaptation
	test.check(not ui._status.has("world") and not ui._status.has("position") and ui._adaptation_rect("lean").size == Vector2(260, 44) and ui._adaptation_rect("load").size == Vector2(260, 44), "Adaptation UI receives detached colony facts and touch-sized choices")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = AdaptationWeb.positions(ui.get_viewport_rect().size).load
	ui._unhandled_input(touch)
	test.check(ui.web_selection == "load" and pile.trial_cohort() == null, "Touch selects Load without purchasing brood")
	touch.position = ui._adaptation_rect("load").get_center()
	ui._unhandled_input(touch)
	test.check(pile.trial_cohort() == null and pile.queued_adaptation == "load" and ui._feedback.contains("changeable until laid"), "Touch choice queues a semantic trial without immediate laying")
	root.simulation.advance(0.25)
	ui._status = root.inward_status("home")
	var before: Dictionary = root.simulation.run.to_dict()
	test.check(not ui.activate_at(ui._adaptation_rect("lean").get_center()) and root.simulation.run.to_dict() == before, "Active trial hides further choice actions")
	ui.free()
	root.free()
