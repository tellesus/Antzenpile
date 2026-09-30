extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const SensoryFixture = preload("res://tests/test_observations.gd")
const CONFIG = preload("res://data/trails/default_trails.tres")
const GameRoot = preload("res://src/core/game_root.gd")


func learned_game() -> SimulationController:
	var game: SimulationController = SensoryFixture.new().fixture()
	game.advance(85.0)
	return game


func steps(game: SimulationController, count: int) -> void:
	for index: int in count:
		game.advance(0.25)


func run(test: Object) -> bool:
	var game := learned_game()
	var pile: PileState = game.run.colony.piles.home
	var node: WorldNodeState = game.run.world.nodes.carb_exposed
	test.check(pile.resources == {"carbohydrate": 10.0, "protein": 5.0, "water": 10.0}, "Authored home reserves initialize three resource pools")
	test.check(game.create_trail("home", "known:carb_exposed"), "Known route starts economic loop")
	var route: TrailRouteState = game.run.trails.routes.route_1
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	var leg: int = CONFIG.leg_ticks(segment.start.distance_to(segment.end))
	var cost: float = CONFIG.round_trip_energy_cost(5, segment.start.distance_to(segment.end), TrailSegmentState.terrain_cost_for(game.run.world, segment.start, segment.end))
	var original_rng: int = game.run.rng.state
	steps(game, 1)
	test.check(game.run.trails.cohorts.size() == 1 and route.active_workers == 5 and game.run.trails.cohorts.cohort_1.direction == "outbound", "One aggregate batch departs after the first tick")
	steps(game, leg - 1)
	test.check(node.quantity == 100.0 and pile.resources.carbohydrate == 10.0 - cost and route.delivered_total == 0.0, "Only round-trip energy is debited before outbound arrival")
	steps(game, 1)
	test.check(node.quantity == 95.0 and pile.resources.carbohydrate == 10.0 - cost and game.run.trails.cohorts.cohort_1.direction == "inbound" and game.run.trails.cohorts.cohort_1.payload == 5.0, "Arrival collects once into an inbound cohort without another energy debit")
	steps(game, leg - 1)
	test.check(pile.resources.carbohydrate == 10.0 - cost and route.delivered_total == 0.0, "Cargo stays in transit until home arrival")
	steps(game, 1)
	test.check(pile.resources.carbohydrate == 15.0 - 2.0 * cost and route.delivered_total == 5.0 and node.quantity == 95.0, "Return deposits once and starts a later energy-paid cycle")
	test.check(game.run.rng.state == original_rng and pile.workers.invariant_holds() and pile.workers.count("trail:route_1") == 5, "Transit does not use RNG or create workers")
	test.check(is_equal_approx(node.quantity + pile.resources.carbohydrate + _cargo(game) + 2.0 * cost, 110.0), "World, cargo, pile and spent energy reconcile")
	var root := GameRoot.new()
	root.simulation = game
	var outward: Dictionary = root.outward_status("home")
	test.check(outward.resources.carbohydrate == pile.resources.carbohydrate and outward.trails[0].delivered_total == 5.0 and not outward.trails[0].has("payload") and not outward.trails[0].has("estimated_destination"), "Normal UI receives detached storage and reported route progress")
	outward.resources.carbohydrate = 999.0
	outward.trails[0].delivered_total = 999.0
	test.check(pile.resources.carbohydrate == 15.0 - 2.0 * cost and route.delivered_total == 5.0, "Presentation edits cannot change resource state")
	root.free()
	var outbound := learned_game()
	var outbound_pile: PileState = outbound.run.colony.piles.home
	test.check(outbound.create_trail("home", "known:carb_exposed"), "Recall fixture route created")
	steps(outbound, 1)
	test.check(outbound.set_trail_workers("route_1", 0) and outbound.run.trails.routes.route_1.status == "recalling" and outbound.run.trails.routes.route_1.active_workers == 5 and outbound_pile.workers_available == 35, "Cancellation retains workers already outbound")
	steps(outbound, 2 * leg - 1)
	test.check(outbound_pile.workers_available == 35 and outbound.run.trails.routes.route_1.status == "recalling", "Recall does not teleport workers before return")
	steps(outbound, 1)
	test.check(outbound_pile.workers_available == 40 and outbound_pile.resources.carbohydrate == 15.0 - cost and outbound.run.trails.routes.route_1.status == "inactive" and outbound.run.trails.cohorts.is_empty(), "Returning cohort deposits cargo, releases ledger and ends recall")
	steps(outbound, 100)
	test.check(outbound.run.trails.cohorts.is_empty() and outbound.run.world.nodes.carb_exposed.quantity == 95.0, "Cancelled route starts no later cycle")
	test.check(outbound.create_trail("home", "known:carb_exposed") and outbound.run.trails.next_route_id == 2, "Reinvestment after completed recall reuses route identity")
	var reduction := learned_game()
	reduction.create_trail("home", "known:carb_exposed")
	steps(reduction, 1)
	test.check(reduction.set_trail_workers("route_1", 2) and reduction.run.trails.routes.route_1.desired_workers == 2 and reduction.run.trails.routes.route_1.allocated_workers == 5, "Partial recall keeps three travelling workers committed")
	steps(reduction, 2 * leg)
	test.check(reduction.run.trails.routes.route_1.allocated_workers == 2 and reduction.run.colony.piles.home.workers_available == 38 and reduction.run.colony.piles.home.resources.carbohydrate < 15.0 and reduction.run.colony.piles.home.resources.carbohydrate > 10.0, "Only returned surplus workers become available")
	var buckets := learned_game()
	buckets.run.world.nodes.carb_exposed.quantity = 9.0
	test.check(buckets.create_trail("home", "known:carb_exposed") and buckets.set_trail_workers("route_1", 20), "Twenty workers committed for bucket contention")
	steps(buckets, 17)
	test.check(buckets.run.trails.cohorts.size() == 3 and buckets.run.trails.routes.route_1.active_workers == 20, "Departure interval creates 8/8/4 aggregate batches")
	var bucket_counts: Array[int] = []
	for cohort: TransitCohort in buckets.run.trails.cohorts.values():
		bucket_counts.append(cohort.worker_count)
	bucket_counts.sort()
	test.check(bucket_counts == [4, 8, 8], "Batch sizes are bounded and exhaust committed workers without duplication")
	steps(buckets, 140)
	var bucket_route: TrailRouteState = buckets.run.trails.routes.route_1
	test.check(buckets.run.world.nodes.carb_exposed.quantity == 0.0 and not buckets.run.world.nodes.carb_exposed.active and buckets.run.colony.piles.home.resources.carbohydrate < 19.0 and bucket_route.delivered_total == 9.0, "Contending arrivals collect only nine remaining units after energy expense")
	test.check(bucket_route.status == "depleted" and bucket_route.reported_depleted and bucket_route.active_workers == 0 and buckets.run.trails.cohorts.is_empty(), "Empty return reports unavailable source and stops departures")
	var depleted_snapshot: Dictionary = buckets.run.to_dict()
	steps(buckets, 100)
	test.check(buckets.run.trails.cohorts.is_empty() and buckets.run.world.nodes.carb_exposed.quantity == 0.0 and bucket_route.delivered_total == 9.0, "Depleted route remains idle without repeated empty trips")
	test.check(buckets.set_trail_workers("route_1", 0) and buckets.run.colony.piles.home.workers_available == 40 and buckets.create_trail("home", "known:carb_exposed") and not bucket_route.reported_depleted, "Full cancellation and reinvestment clear reported depletion")
	var stale := learned_game()
	stale.run.world.nodes.carb_exposed.position = Vector2(35, 35)
	var remembered: Vector2 = stale.run.knowledge.nodes["known:carb_exposed"].estimated_position
	test.check(stale.create_trail("home", "known:carb_exposed"), "Stale location still permits investment from knowledge")
	steps(stale, 2 * CONFIG.leg_ticks(stale.run.trails.segments.segment_1.start.distance_to(stale.run.trails.segments.segment_1.end)) + 1)
	test.check(stale.run.trails.routes.route_1.status == "depleted" and stale.run.trails.routes.route_1.delivered_total == 0.0 and stale.run.trails.segments.segment_1.end == remembered and stale.run.colony.piles.home.resources.carbohydrate == 10.0 - cost, "Moved hidden source costs energy without teleporting or leaking live coordinates")
	var saved_game := learned_game()
	saved_game.create_trail("home", "known:carb_exposed")
	steps(saved_game, 4)
	var saved: Dictionary = saved_game.run.to_dict()
	var restored := Controller.new()
	test.check(restored.run.restore(JSON.parse_string(JSON.stringify(saved, "", true, true))) and restored.run.to_dict() == saved, "Mid-outbound full-precision JSON round trip")
	var inbound := learned_game()
	inbound.create_trail("home", "known:carb_exposed")
	steps(inbound, leg + 1)
	var inbound_saved: Dictionary = inbound.run.to_dict()
	var inbound_copy := Controller.new()
	test.check(inbound.run.trails.cohorts.cohort_1.direction == "inbound" and inbound_copy.run.restore(JSON.parse_string(JSON.stringify(inbound_saved, "", true, true))), "Loaded cargo survives mid-inbound JSON restore")
	for index: int in range(leg + 3):
		steps(inbound, 1)
		steps(inbound_copy, 1)
		test.check(inbound.run.to_dict() == inbound_copy.run.to_dict(), "Inbound continuation deposits exactly once %d" % index)
	for index: int in range(100):
		steps(saved_game, 1)
		steps(restored, 1)
		test.check(saved_game.run.to_dict() == restored.run.to_dict(), "Mid-trip continuation matches tick %d" % index)
	var before: Dictionary = restored.run.to_dict()
	var invalid: Dictionary = saved.duplicate(true)
	invalid.trails.cohorts[0].worker_count += 1
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Cohort/route worker mismatch rejects atomically")
	invalid = saved.duplicate(true)
	invalid.trails.cohorts[0].remaining_ticks = 999
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Impossible remaining travel rejects atomically")
	invalid = inbound_saved.duplicate(true)
	invalid.trails.cohorts[0].payload = 99.0
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Cargo above carrying capacity rejects atomically")
	invalid = inbound_saved.duplicate(true)
	invalid.trails.cohorts[0].resource_id = "water"
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Cargo category inconsistent with source rejects atomically")
	invalid = saved.duplicate(true)
	invalid.colony.piles[0].resources.carbohydrate = -1
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Negative stored resource rejects atomically")
	var speeds: Array[SimulationController] = []
	for scale: int in [1, 4, 16, 64]:
		var copy := Controller.new()
		test.check(copy.run.restore(saved) and copy.set_time_scale(scale), "Scale fixture restores")
		for index: int in range(160):
			copy.advance(0.25 / scale)
		copy.set_time_scale(1)
		speeds.append(copy)
	for copy: SimulationController in speeds:
		test.check(copy.run.to_dict() == speeds[0].run.to_dict(), "Equal simulated duration gives equal transit outcome")
	test.check(depleted_snapshot.trails.cohorts.size() <= CONFIG.max_cohorts_per_route, "Cohort count remains bounded through depletion")
	return true


func _cargo(game: SimulationController) -> float:
	var total: float = 0.0
	for cohort: TransitCohort in game.run.trails.cohorts.values():
		total += cohort.payload
	return total
