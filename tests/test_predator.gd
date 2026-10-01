extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const CONFIG = preload("res://data/ecology/backyard_predator.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")


func run(test: Object) -> bool:
	_test_returned_alarm(test)
	_test_saturation_and_full_loss(test)
	_test_cargo_and_traits(test)
	return true


func _fixture() -> SimulationController:
	var game := Controller.new(3043)
	game.dispatch_scout("home", PI / 4.0)
	for tick: int in 1000:
		if game.run.knowledge.nodes.has("known:aphid_01"):
			break
		game.advance(0.25)
	game.advance(maxf(0.0, 300.0 - game.run.simulation_time))
	game.create_trail("home", "known:aphid_01")
	return game


func _snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func _until_loss(game: SimulationController) -> void:
	for tick: int in 1000:
		if game.run.predator.kills_total > 0:
			return
		game.advance(0.25)


func _test_returned_alarm(test: Object) -> void:
	var game := _fixture()
	var pile: PileState = game.run.colony.piles.home
	var route: TrailRouteState = game.run.trails.routes.route_1
	var root := Root.new()
	root.simulation = game
	var before: int = pile.workers_total
	_until_loss(game)
	test.check(game.run.predator.kills_total == 1 and pile.workers_total == before - 1 and pile.workers.lost_total == 1 and route.allocated_workers == 4 and route.active_workers == 4, "Ordinary honeydew traffic suffers a ledger-accounted ambush casualty")
	test.check(root.inward_status("home").workers_total == before and root.trail_summaries("home")[0].allocated_workers == 5 and root.trail_summaries("home")[0].active_workers == 5 and route.reported_losses == 0, "Normal counts retain unresolved travelers until their expected return")
	var risk: Variant = null
	for signal_data: Dictionary in root.sensory_snapshot("home"):
		if signal_data.source_knowledge_id == "known:aphid_01":
			risk = signal_data.risk
	test.check(risk == null and not root.outward_status("home").has("predator"), "Physical attack does not immediately leak alarm or hidden zone")
	var available: int = pile.workers_available
	test.check(game.set_trail_workers(route.id, 5) and pile.workers_available == available and route.allocated_workers == 4, "Repeated expected labor target cannot silently replace an unreported casualty")
	test.check(game.set_trail_workers(route.id, 6) and pile.workers_available == available - 1 and route.allocated_workers == 5, "Explicit target increase recruits only the extra expected worker")
	var saved: Dictionary = _snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Private casualty and ambush recovery save exactly")
	for tick: int in 1000:
		if route.reported_losses > 0:
			break
		game.advance(0.25)
		copy.advance(0.25)
	test.check(route.reported_losses == 1 and route.last_loss_time > 0.0 and root.inward_status("home").workers_total == pile.workers_total and root.trail_summaries("home")[0].reported_losses == 1, "Home return delivers loss and updates colony population knowledge")
	test.check(copy.run.to_dict() == game.run.to_dict() and route.delivered_total > 0.0 and not route.reported_depleted, "Survivors deliver real cargo and exact continuation without conflating danger and depletion")
	var alarm: bool = false
	for signal_data: Dictionary in root.sensory_snapshot("home"):
		if signal_data.source_knowledge_id == "known:aphid_01":
			alarm = signal_data.risk == "reported_loss"
	test.check(alarm, "Remembered source receives returned-loss alarm")
	var view: OutwardView = View.new()
	test.get_root().add_child(view)
	view.trail_set_command = root.set_trail_target
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = "signal:known:aphid_01"
	view._pointer_press(view._trail_button_rect("trail_cancel").get_center(), "mouse")
	test.check(route.desired_workers == 0, "Mouse Stop Traffic blocks new departures after alarm")
	game.advance(100.0)
	test.check(route.allocated_workers == 0 and route.active_workers == 0 and pile.workers.count("trail:" + route.id) == -1, "Recall releases survivors through real travel and ledger settlement")
	var attacks_after_recall: int = game.run.predator.kills_total
	game.advance(100.0)
	test.check(game.run.predator.kills_total == attacks_after_recall, "Stopped route causes no further casualties")
	game.dispatch_scout("home", PI)
	game.advance(300.0)
	test.check(game.create_trail("home", "known:carb_sheltered"), "Player can put labor on a remembered alternative source")
	game.advance(100.0)
	test.check(game.run.predator.kills_total == attacks_after_recall and game.run.trails.routes.route_2.delivered_total > 0.0, "Alternative source provides meaningful avoidance with successful cargo")
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = "signal:known:carb_sheltered"
	view._pointer_press(view._trail_button_rect("trail_cancel").get_center(), "touch")
	test.check(game.run.trails.routes.route_2.desired_workers == 0, "Touch Stop Traffic uses the same semantic recall path")
	view.queue_free()
	root.free()
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(60.0)
	test.check(game.run.to_dict() == paused, "Pause freezes losses, reports and predator recovery")
	game.toggle_pause()
	test.check(copy.restore_snapshot(_snapshot(game)), "Returned alarm restores")
	game.advance(60.0)
	copy.set_time_scale(4)
	copy.advance(15.0)
	copy.set_time_scale(1)
	test.check(copy.run.to_dict() == game.run.to_dict(), "Post-alarm continuation is identical across speeds")
	for field: String in ["kills", "future", "private", "adapted", "report_time", "ledger"]:
		var invalid: Dictionary = saved.duplicate(true)
		match field:
			"kills": invalid.predator.kills_total += 1
			"future": invalid.predator.last_attack_tick = str(game.run.clock.tick_count + 10000)
			"private": invalid.trails.cohorts[0].lost_workers = 2
			"adapted": invalid.trails.cohorts[0].adapted_lost_workers = 1
			"report_time": invalid.trails.routes[0].last_loss_time = 99999.0
			"ledger": invalid.trails.routes[0].allocated_workers += 1
		var prior: Dictionary = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == prior, "Invalid encounter snapshot rejects atomically: " + field)
	var legacy: Dictionary = _snapshot(_fixture())
	for record: Dictionary in legacy.trails.routes:
		record.erase("reported_losses")
		record.erase("last_loss_time")
	legacy.trails.cohorts = []
	legacy.erase("predator")
	test.check(copy.restore_snapshot(legacy) and copy.run.predator.kills_total == 0, "Older version-5 snapshots default to no encounters")


func _test_saturation_and_full_loss(test: Object) -> void:
	var game := _fixture()
	test.check(game.predator.encounter(CONFIG.position) and not game.predator.encounter(CONFIG.position), "Shared saturation permits only one attack at the same time")
	game.advance(29.75)
	test.check(not game.predator.encounter(CONFIG.position), "Predator stays saturated before the recovery boundary")
	game.advance(0.25)
	test.check(game.predator.encounter(CONFIG.position), "Predator can attack again at exact recovery boundary")
	game = _fixture()
	game.set_trail_workers("route_1", 20)
	_until_loss(game)
	game.advance(29.0)
	test.check(game.run.predator.kills_total == 1 and game.run.colony.piles.home.workers.lost_total == 1, "Multiple real cohorts cross the shared saturated zone without extra deaths")
	game = _fixture()
	var route: TrailRouteState = game.run.trails.routes.route_1
	test.check(game.set_trail_workers(route.id, 1), "One-worker trail fixture uses ordinary allocation")
	var root := Root.new()
	root.simulation = game
	_until_loss(game)
	var cohort: TransitCohort = game.run.trails.cohorts.values()[0]
	test.check(cohort.worker_count == 0 and cohort.lost_workers == 1 and cohort.payload == 0.0 and route.status == "inactive" and route.allocated_workers == 0, "Whole-cohort loss leaves only a bounded expected-return record")
	test.check(root.trail_summaries("home")[0].status == "active" and root.trail_summaries("home")[0].active_workers == 1, "Wholly lost travelers remain expected in normal view")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(_snapshot(game)), "Zero-traveler expectation saves without an orphan commitment")
	var invalid: Dictionary = _snapshot(game)
	invalid.trails.cohorts[0].lost_workers = 0
	test.check(not copy.restore_snapshot(invalid), "Zero travelers without a casualty expectation reject")
	var source_amount: float = game.run.world.nodes.aphid_01.quantity
	for tick: int in 1000:
		if route.reported_losses > 0:
			break
		game.advance(0.25)
		copy.advance(0.25)
	test.check(route.reported_losses == 1 and route.delivered_total == 0.0 and not route.reported_depleted and game.run.trails.cohorts.is_empty(), "Expected-return timeout reports missing worker without cargo or false source depletion")
	test.check(game.run.world.nodes.aphid_01.quantity >= source_amount and copy.run.to_dict() == game.run.to_dict(), "Lost expectation cannot harvest and continues exactly after save")
	root.free()


func _test_cargo_and_traits(test: Object) -> void:
	var game := _fixture()
	game.set_trail_workers("route_1", 0)
	var pile: PileState = game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 200.0)
	game.advance(360.0)
	test.check(game.start_adaptation("home", "load"), "Cargo fixture starts an ordinary adaptation trial")
	game.advance(360.0)
	test.check(pile.adapted_workers_total == 8 and game.set_trail_workers("route_1", 5), "Emerged adapted adults can join ordinary route traffic")
	game.advance(0.25)
	var cohort: TransitCohort = game.run.trails.cohorts.values()[0]
	var route: TrailRouteState = game.run.trails.routes.route_1
	var captured_carry: float = cohort.carry_multiplier
	# Place a loaded, already-returning aggregate at the encounter boundary.
	cohort.direction = "inbound"
	cohort.payload = 5 * TRAILS.carry_per_worker * captured_carry
	cohort.resource_id = "carbohydrate"
	var segment: TrailSegmentState = game.run.trails.segments[route.segment_id]
	cohort.remaining_ticks = roundi(TRAILS.leg_ticks(segment.start.distance_to(segment.end)) * 0.67)
	_until_loss(game)
	test.check(cohort.worker_count == 4 and cohort.payload == 4 * TRAILS.carry_per_worker * captured_carry and cohort.carry_multiplier == captured_carry, "Killed carrier loses cargo beyond survivor capacity and preserves departure phenotype")
	test.check(pile.adapted_workers_total + pile.adapted_workers_lost == 8 and cohort.adapted_lost_workers <= 1, "Seeded casualty selection conserves adapted lifetime population")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(_snapshot(game)), "Loaded casualty and captured phenotype restore")
	game.advance(80.0)
	copy.advance(80.0)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Adapted loaded traffic continues exactly across encounter save")
