extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const CONFIG = preload("res://data/ecology/backyard_guest.tres")


func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func until_tick(game: SimulationController, target: int) -> void:
	for tick: int in target - game.run.clock.tick_count:
		game.advance(0.25)


func loss_fixture() -> SimulationController:
	var game := Controller.new(5050)
	until_tick(game, CONFIG.first_tick + CONFIG.damage_ticks - 1)
	return game


func run(test: Object) -> bool:
	var game := Controller.new(5050)
	var root := Root.new()
	root.simulation = game
	var before: Dictionary = game.run.to_dict()
	test.check(not game.start_guest_rejection() and not game.stop_guest_rejection() and game.run.to_dict() == before, "Absent guest commands reject atomically")
	test.check(root.guest_summary("home").is_empty(), "Hidden guest has no initial node or evil cue")
	until_tick(game, CONFIG.first_tick - 1)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Pre-entry save with longer existing world history restores")
	game.advance(0.25)
	copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.guest.observation == "tolerated" and game.run.guest.reported_losses == 0, "Real entry becomes a tolerated observation without announcing its hidden cost")
	var summary: Dictionary = root.guest_summary("home")
	test.check(not summary.has("integration_ticks") and not summary.has("damage_ticks") and not summary.has("population") and not summary.has("phase"), "Detached guest context excludes integration, damage schedule and true population")
	game.advance((CONFIG.damage_ticks - 1) * 0.25)
	var pile: PileState = game.run.colony.piles.home
	test.check(pile.brood_lost_total == 1 and pile.brood_cohorts[0].count == 7 and game.run.guest.observation == "loss" and pile.workers_total == 40, "First detected brood loss has uncertain cause and never removes adults")
	game.advance(CONFIG.damage_ticks * 0.25)
	test.check(game.run.guest.observation == "foreign" and root.inward_status("home").brood_losses == 2 and pile.brood_cohorts[0].count == 6, "Repeated nursery loss yields internal foreignness evidence")
	test.check(copy.restore_snapshot(snapshot(game)), "Partially consumed brood saves with conserved lifetime accounting")
	var busy: bool = pile.workers.create_commitment("test:busy", "other", "test") and pile.workers.allocate("test:busy", pile.workers_available - 3)
	test.check(busy, "Labor shortage fixture leaves three available workers")
	before = game.run.to_dict()
	test.check(not game.start_guest_rejection() and game.run.to_dict() == before, "Insufficient rejection labor rejects without partial commitment or state mutation")
	var freed: bool = pile.workers.release("test:busy", pile.workers.count("test:busy")) and pile.workers.retire_commitment("test:busy")
	test.check(freed, "Labor shortage fixture returns committed workers")
	var view: InwardView = View.new()
	test.get_root().add_child(view)
	view._status = root.inward_status("home")
	view.selected_id = "guest"
	view.guest_rejection_command = root.set_guest_rejection
	test.check(view.node_at(view.positions(view.get_viewport_rect().size).guest, view.get_viewport_rect().size) == "" and view.node_at(view.positions(view.get_viewport_rect().size).guest, view.get_viewport_rect().size, true) == "guest", "Guest hit target exists only when colony has an entry observation")
	var available: int = pile.workers_available
	test.check(view.activate_at(view._guest_rect().get_center()) and pile.workers_available == available - CONFIG.rejection_workers and pile.workers.count("rejection:home") == CONFIG.rejection_workers, "Shared pointer command reserves real workers for rejection")
	var odor: int = game.run.guest.integration_ticks
	game.advance(4.0)
	test.check(game.run.guest.integration_ticks == odor and game.run.guest.rejection_ticks == 16, "Rejection halts odor acquisition and takes real simulation time")
	view._status = root.inward_status("home")
	test.check(view.activate_at(view._guest_rect().get_center()) and pile.workers_available == available, "Stop Rejection returns the committed internal workers")
	game.advance(5.0)
	test.check(game.run.guest.integration_ticks > odor and game.run.guest.rejection_ticks == 16, "Toleration resumes acquisition while preserving completed rejection effort")
	test.check(game.start_guest_rejection(), "Evidence permits restarting a paid-in-labor effort")
	before = game.run.to_dict()
	test.check(not game.start_guest_rejection() and game.run.to_dict() == before, "Duplicate effort cannot allocate another four workers")
	var mid: Dictionary = snapshot(game)
	test.check(copy.restore_snapshot(mid), "Mid-rejection save preserves acquired odor, work and ledger ownership")
	game.advance(60.0)
	copy.advance(60.0)
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.guest.phase == "purged" and root.guest_summary("home").observation == "purged" and pile.workers_available == available, "Aggregate purge releases workers and exact continuation preserves its observed outcome")
	var losses: int = pile.brood_lost_total
	game.advance(400.0)
	test.check(pile.brood_lost_total == losses and pile.workers.invariant_holds(), "Purged population cannot consume later brood or duplicate worker release")
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 100.0)
	game.advance(360.0)
	test.check(pile.brood_cohorts.is_empty() and pile.brood_matured_total == 8 - losses and pile.workers_total == 48 - losses, "Partial cohort emerges only its surviving workers, conserving immature losses")
	test.check(game.start_brood("home") and pile.brood_cohorts[0].id == "brood_2" and copy.restore_snapshot(snapshot(game)), "Partial emergence uses monotonic IDs and permits a valid new cohort")
	for field: String in ["ledger", "losses", "count", "started", "integration", "evidence", "progress", "unearned_purge"]:
		var invalid: Dictionary = mid.duplicate(true)
		match field:
			"ledger": invalid.colony.piles[0].workers.commitments["rejection:home"].count = 3
			"losses": invalid.guest.reported_losses += 1
			"count": invalid.colony.piles[0].brood_cohorts[0].count += 1
			"started": invalid.colony.piles[0].brood_started_total += 1
			"integration": invalid.guest.integration_ticks = CONFIG.integration_ticks + 1
			"evidence": invalid.guest.observation = "purged"
			"progress": invalid.guest.rejection_ticks = invalid.guest.rejection_duration_ticks
			"unearned_purge":
				invalid.guest.reported_losses = 0
				invalid.guest.phase = "purged"
				invalid.guest.observation = "purged"
				invalid.guest.rejection_ticks = invalid.guest.rejection_duration_ticks
		before = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Malformed guest history rejects atomically: " + field)
	view.free()
	root.free()
	_test_total_trial_loss(test)
	_test_clock_and_legacy(test)
	return true


func _test_total_trial_loss(test: Object) -> void:
	var game := Controller.new(5051)
	var pile: PileState = game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 100.0)
	game.advance(360.0)
	var started: bool = game.start_adaptation("home", "lean")
	test.check(started, "Guest trial fixture starts an ordinary funded adaptation cohort")
	pile.resources.protein = 0.0
	until_tick(game, CONFIG.first_tick + CONFIG.damage_ticks * 8 - 1)
	test.check(pile.brood_cohorts.is_empty() and pile.brood_lost_total == 8 and pile.adaptation_repertoire == "" and pile.workers_total == 48 and pile.workers_available == 48 and pile.workers.count("adaptation:home") == -1, "Wholly consumed trial releases nurses without expressing a trait or killing adults")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Empty Nursery after a wholly lost trial restores with conserved lifetime history")
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 100.0)
	test.check(game.start_adaptation("home", "load") and pile.trial_cohort().id == "brood_3", "Lost trial permits a fresh paid choice without reusing cohort identity")
	game.advance(60.0)
	test.check(game.start_guest_rejection(), "Long-integrated guest can still be rejected")
	test.check(game.run.guest.rejection_duration_ticks == 240, "Fully acquired colony odor increases clearing work to sixty seconds")
	game.advance(60.0)
	game.advance(360.0)
	test.check(pile.adaptation_repertoire == "load" and pile.adapted_workers_total > 0 and pile.adapted_workers_total < 8 and copy.restore_snapshot(snapshot(game)), "Surviving trial expresses a partial adapted workforce with valid saves")


func _test_clock_and_legacy(test: Object) -> void:
	var game := loss_fixture()
	game.toggle_pause()
	var before: Dictionary = game.run.to_dict()
	game.advance(100.0)
	test.check(game.run.to_dict() == before, "Pause freezes guest chemistry, damage and evidence")
	game.toggle_pause()
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Guest speed fixture restores")
	game.advance(120.0)
	copy.set_time_scale(4)
	copy.advance(30.0)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Guest progression is identical at one and four times speed")
	for scale: int in [16, 64]:
		var fast := Controller.new()
		var restored: bool = fast.restore_snapshot(snapshot(copy))
		var ordinary := Controller.new()
		var ordinary_restored: bool = ordinary.restore_snapshot(snapshot(copy))
		fast.set_time_scale(scale)
		fast.advance(60.0 / scale)
		fast.set_time_scale(1)
		ordinary.advance(60.0)
		test.check(restored and ordinary_restored and fast.run.to_dict() == ordinary.run.to_dict(), "Guest damage/recognition are equal at %dx speed" % scale)
	var legacy: Dictionary = snapshot(Controller.new())
	legacy.erase("guest")
	legacy.colony.piles[0].erase("brood_started_total")
	legacy.colony.piles[0].erase("brood_lost_total")
	legacy.colony.piles[0].brood_cohorts[0].erase("lost_count")
	test.check(copy.restore_snapshot(legacy) and copy.run.guest.phase == "absent" and copy.run.colony.piles.home.brood_started_total == 1, "Older version-5 saves infer original brood identity and no guest")
