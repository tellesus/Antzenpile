extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const CONFIG = preload("res://data/resources/default_brood.tres")


func run(test: Object) -> bool:
	var game := Controller.new(3030)
	var pile: PileState = game.run.colony.piles.home
	test.check(pile.nursery_state == "primitive" and pile.nursery_brood_capacity() == 8 and pile.nursery_occupied_space() == 8 and pile.nursery_care_capacity() == 8, "Primitive Nursery starts with explicit eight-brood space and care")
	var before: Dictionary = game.run.to_dict()
	var old_save: Dictionary = before.duplicate(true)
	old_save.colony.piles[0].erase("nursery_state")
	old_save.colony.piles[0].erase("nursery_progress_seconds")
	var restored := Controller.new()
	test.check(restored.restore_snapshot(old_save) and restored.run.to_dict() == before, "Older version-5 pile saves gain Primitive Nursery state")
	var invalid: Dictionary = before.duplicate(true)
	invalid.colony.piles[0].nursery_state = "unknown"
	test.check(not restored.restore_snapshot(invalid) and restored.run.to_dict() == before, "Invalid Nursery state rejects atomically")
	test.check(not game.start_brood("home") and game.run.to_dict() == before, "Occupied Nursery cannot start another cohort")
	test.check(pile.workers.create_commitment("test:care", "other", "care") and pile.workers.allocate("test:care", 39), "Care fixture leaves one available worker")
	game.advance(0.25)
	test.check(pile.nursery_care_capacity() == 4 and pile.brood_cohorts[0].care == 0.5 and pile.brood_cohorts[0].progress_seconds == 0.0, "One available worker supports only half the cohort and pauses progression")
	test.check(pile.workers.allocate("test:care", 1), "Care fixture can commit the last worker")
	game.advance(0.25)
	test.check(pile.nursery_care_capacity() == 0 and pile.brood_cohorts[0].care == 0.0 and pile.brood_cohorts[0].progress_seconds == 0.0, "No available care stops the cohort")
	test.check(pile.workers.release("test:care", 2), "Two workers return through the ledger")
	game.advance(0.25)
	test.check(pile.nursery_care_capacity() == 8 and pile.brood_cohorts[0].care == 1.0 and pile.brood_cohorts[0].progress_seconds == 0.25 and pile.workers.invariant_holds(), "Two available workers restore full care without a new pool")
	var mid: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	test.check(restored.restore_snapshot(mid) and restored.run.to_dict() == game.run.to_dict(), "Nursery and care state continue exactly after save")

	var root := Root.new()
	root.simulation = game
	var summary: Dictionary = root.inward_status("home")
	test.check(summary.nursery_state == "primitive" and summary.nursery_occupied_space == CONFIG.starting_count and summary.nursery_brood_capacity == CONFIG.primitive_nursery_brood_capacity and summary.nursery_care_capacity == 8 and not summary.has("world"), "INWARD receives detached space and care values")
	summary.nursery_occupied_space = 0
	test.check(pile.nursery_occupied_space() == 8, "Presentation changes cannot alter Nursery occupancy")
	root.free()
	var view := View.new()
	test.get_root().add_child(view)
	view.selected_id = "nursery"
	view._status = {"queens": 1, "brood": [], "brood_batch_count": 8, "nursery_brood_capacity": 8, "nursery_occupied_space": 8}
	test.check(view.activate_at(view._brood_rect().get_center()) and not view._feedback.is_empty(), "INWARD explains Lay Brood when detached free space is insufficient")
	view.free()

	test.check(pile.workers.release("test:care", 38) and pile.workers.retire_commitment("test:care"), "Care fixture releases all workers")
	test.check(pile.deposit_resource("carbohydrate", 20.0), "Maturation fixture funds larval care")
	game.advance(CONFIG.egg_seconds + CONFIG.larva_seconds + CONFIG.pupa_seconds)
	test.check(pile.brood_cohorts.is_empty() and pile.nursery_occupied_space() == 0 and pile.brood_matured_total == 8 and pile.workers_total == 48, "Maturation frees Nursery space and conserves living workers")
	test.check(game.start_brood("home") and pile.nursery_occupied_space() == 8 and pile.brood_cohorts[0].id == "brood_2", "A repeat cohort fills free Primitive Nursery space")
	return true
