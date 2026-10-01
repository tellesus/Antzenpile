extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Contact = preload("res://tests/test_rival_contact.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")


func _until(game: SimulationController, condition: Callable, ticks: int = 1000) -> bool:
	for tick: int in ticks:
		if condition.call():
			return true
		game.advance(0.25)
	return condition.call()


func forming_fixture() -> SimulationController:
	var game: SimulationController = Contact.new().fixture()
	_until(game, func() -> bool: return game.run.swarm.active())
	return game


func run(test: Object) -> bool:
	var game := forming_fixture()
	var route: TrailRouteState = game.run.trails.routes.route_1
	var state: SwarmState = game.run.swarm
	var root := Root.new()
	root.simulation = game
	test.check(state.phase == "forming" and route.foreign_reports == 2 and state.route_id == route.id and state.position.x == 28.0, "Sustained real foreign traffic forms a stationary crossing swarm after delivered contact")
	var held: int = 0
	var reporters: int = 0
	for cohort: TransitCohort in game.run.trails.cohorts.values():
		if cohort.swarm_engaged:
			held += cohort.worker_count
		if cohort.conflict_report == "contested":
			reporters += cohort.worker_count
	test.check(held == 4 and reporters == 1 and route.active_workers == 5 and game.run.colony.piles.home.workers.count("trail:route_1") == 5, "Messenger split preserves all five workers in one authoritative trail commitment")
	test.check(not state.rival_engaged and route.conflict_report == "" and root.trail_summaries("home")[0].conflict_report == "", "Enemy and messenger must travel; forming truth is absent from normal summary")
	var saved: Dictionary = Contact.new().snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Forming swarm and in-flight messenger save exactly")
	var earliest_message_ticks: int = 0
	for cohort: TransitCohort in game.run.trails.cohorts.values():
		if cohort.conflict_report == "contested":
			earliest_message_ticks = cohort.remaining_ticks
	for tick: int in earliest_message_ticks - 1:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(route.conflict_report == "" and game.run.to_dict() == copy.run.to_dict(), "Conflict cannot appear before the messenger's remaining return travel")
	game.advance(0.25)
	copy.advance(0.25)
	test.check(route.conflict_report == "contested" and route.foreign_reports == 3 and not route.reported_depleted and root.sensory_snapshot("home")[0].conflict_report == "contested", "Home-delivered messenger reports contested traffic without a false empty-source report")
	var view: OutwardView = View.new()
	test.get_root().add_child(view)
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = "signal:known:carb_exposed"
	view.trail_set_command = root.set_trail_target
	var target_before: int = route.desired_workers
	var available_before: int = game.run.colony.piles.home.workers_available
	view._pointer_press(view._trail_button_rect("trail_more").get_center(), "mouse")
	test.check(route.desired_workers == target_before + 4 and game.run.colony.piles.home.workers_available == available_before - 4, "Mouse +4 reinforcement commits real reserve labor")
	var now_held: int = 0
	for cohort: TransitCohort in game.run.trails.cohorts.values():
		if cohort.swarm_engaged:
			now_held += cohort.worker_count
	test.check(now_held <= held and route.allocated_workers - route.active_workers >= 4, "New reinforcements remain at home until ordinary departure and travel")
	test.check(_until(game, func() -> bool: return state.phase == "fighting"), "Rival travelers reach the junction and start combat")
	var fighting_save: Dictionary = Contact.new().snapshot(game)
	test.check(copy.restore_snapshot(fighting_save), "Mid-fight losses, cargo and report ownership save")
	for tick: int in 400:
		if state.phase == "finished":
			break
		game.advance(0.25)
		copy.advance(0.25)
	test.check(state.phase == "finished" and state.player_losses + state.rival_losses > 0 and game.run.to_dict() == copy.run.to_dict(), "Seeded aggregate combat resolves with conserved losses and exact continuation")
	test.check(game.run.rival.workers.total + game.run.rival.workers.lost_total == 30 and state.rival_losses == game.run.rival.workers.lost_total, "Foreign casualties debit the rival's own living population")
	test.check(game.run.colony.piles.home.workers.lost_total == state.player_losses and game.run.colony.piles.home.workers.invariant_holds(), "Player combat casualties preserve authoritative ledger conservation")
	game.set_trail_workers(route.id, 0)
	game.advance(50.0)
	test.check(route.conflict_report in ["secured", "withdrew"] and route.reported_rival_losses == state.player_losses and route.allocated_workers == 0, "Survivor home returns deliver battle outcome/losses and recall releases labor")
	test.check(copy.restore_snapshot(Contact.new().snapshot(game)), "Resolved battle with cumulative loss history restores")
	view.free()
	root.free()
	var withdrawal := forming_fixture()
	var withdrawal_root := Root.new()
	withdrawal_root.simulation = withdrawal
	var withdrawal_view: OutwardView = View.new()
	test.get_root().add_child(withdrawal_view)
	withdrawal_view._signals = withdrawal_root.sensory_snapshot("home")
	withdrawal_view._status = withdrawal_root.outward_status("home")
	withdrawal_view.selected_id = "signal:known:carb_exposed"
	withdrawal_view.trail_set_command = withdrawal_root.set_trail_target
	withdrawal_view._pointer_press(withdrawal_view._trail_button_rect("trail_cancel").get_center(), "touch")
	withdrawal.advance(0.25)
	test.check(withdrawal.run.swarm.phase == "finished" and withdrawal.run.swarm.player_losses == 0 and withdrawal.run.trails.routes.route_1.allocated_workers > 0, "Touch withdrawal ends recruitment before casualties but does not teleport participants home")
	withdrawal.advance(20.0)
	test.check(withdrawal.run.trails.routes.route_1.allocated_workers == 0 and withdrawal.run.trails.routes.route_1.conflict_report == "withdrew", "Withdrawn survivors deliver their result after real return travel")
	withdrawal_view.free()
	withdrawal_root.free()
	game = forming_fixture()
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(100.0)
	test.check(game.run.to_dict() == paused, "Pause freezes forming/fighting groups and message delivery")
	game.toggle_pause()
	test.check(copy.restore_snapshot(Contact.new().snapshot(game)), "Speed fixture restores swarm")
	game.advance(60.0)
	copy.set_time_scale(4)
	copy.advance(15.0)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Swarm formation/combat/returns are independent of simulation speed")
	for field: String in ["player_losses", "rival_losses", "position", "held", "report_time", "lost_cause"]:
		var invalid: Dictionary = saved.duplicate(true)
		match field:
			"player_losses": invalid.swarm.player_losses += 1
			"rival_losses": invalid.swarm.rival_losses += 1
			"position": invalid.swarm.position = [1.0, 1.0]
			"held": invalid.swarm.route_id = "route_missing"
			"report_time": invalid.trails.cohorts[0].conflict_observed_at = 99999.0
			"lost_cause": invalid.trails.cohorts[0].rival_losses = 1
		var before: Dictionary = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Invalid swarm snapshot rejects atomically: " + field)
	var legacy: Dictionary = Contact.new().snapshot(Controller.new())
	legacy.erase("swarm")
	test.check(copy.restore_snapshot(legacy) and copy.run.swarm.phase == "idle", "Older version-5 snapshots default to no swarm")
	_test_full_loss(test)
	return true


func _test_full_loss(test: Object) -> void:
	var game := forming_fixture()
	var route: TrailRouteState = game.run.trails.routes.route_1
	var held: TransitCohort
	for cohort: TransitCohort in game.run.trails.cohorts.values():
		if cohort.swarm_engaged:
			held = cohort
	var root := Root.new()
	root.simulation = game
	var expected: int = root.inward_status("home").workers_total
	# Exercise a mixed-cause cohort at the casualty API boundary; geometry is tested separately.
	held.predator_encountered = true
	test.check(game.predator.encounter(preload("res://data/ecology/backyard_predator.tres").position), "Mixed history records one physical predator casualty")
	game.trails.apply_loss(held, route, "predator")
	while held.worker_count > 0:
		game.trails.apply_loss(held, route, "rival")
		game.run.swarm.player_losses += 1
	test.check(held.worker_count == 0 and held.lost_workers == 4 and held.rival_losses == 3 and not held.swarm_engaged and held.conflict_report == "", "Wholly lost participants retain separate predator/rival casualties without a survivor report")
	test.check(root.inward_status("home").workers_total == expected and route.reported_losses == 0, "Normal counts retain unresolved fully lost combat travelers")
	game.set_trail_workers(route.id, 0)
	game.swarm.tick()
	var copy := Controller.new()
	test.check(copy.restore_snapshot(Contact.new().snapshot(game)), "Mixed predator/rival history and zero-traveler record restore")
	game.advance(30.0)
	copy.advance(30.0)
	test.check(game.run.to_dict() == copy.run.to_dict() and route.reported_losses == 4 and route.reported_rival_losses == 3 and route.conflict_report != "secured", "Expected-return loss report settles once without a fabricated victorious outcome")
	root.free()
