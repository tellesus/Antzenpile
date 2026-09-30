extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const TransitFixture = preload("res://tests/test_transit.gd")
const Root = preload("res://src/core/game_root.gd")
const Segment = preload("res://src/sim/trails/trail_segment_state.gd")
const CONFIG = preload("res://data/trails/default_trails.tres")


func run(test: Object) -> bool:
	_test_carbohydrate_recovery(test)
	_test_non_carbohydrate_stall(test)
	_test_weak_source(test)
	return true


func _test_carbohydrate_recovery(test: Object) -> void:
	var game: SimulationController = TransitFixture.new().learned_game()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.create_trail("home", "known:carb_exposed"), "Known route commits labor before an energy payment")
	var route: TrailRouteState = game.run.trails.routes.route_1
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	var length: float = segment.start.distance_to(segment.end)
	game.run.world.terrain[1].movement_cost = 1.25
	var terrain_cost: float = Segment.terrain_cost_for(game.run.world, segment.start, segment.end)
	var energy_cost: float = CONFIG.round_trip_energy_cost(5, length, terrain_cost)
	test.check(terrain_cost == 1.25 and energy_cost > CONFIG.round_trip_energy_cost(5, length, 1.0), "Higher physical terrain cost raises the aggregate trip cost")
	test.check(CONFIG.round_trip_energy_cost(8, 2.0 * length, terrain_cost) > 2.0 * energy_cost, "More workers and greater distance increase traffic energy demand")
	pile.resources.carbohydrate = 0.0
	game.advance(0.25)
	test.check(route.status == "active" and not route.energy_limited and game.run.trails.cohorts.size() == 1 and game.run.trails.cohorts.cohort_1.unpaid_energy_cost == energy_cost and pile.resources.carbohydrate == 0.0, "Carbohydrate recovery trip carries an exact unpaid energy cost")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot) and copy.run.to_dict() == game.run.to_dict(), "Emergency trip saves its unpaid cost exactly")
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.trails.cohorts[0].unpaid_energy_cost = energy_cost + 1.0
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Inflated energy debt rejects without changing a restored run")
	for index: int in 2 * CONFIG.leg_ticks(length):
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict() and route.delivered_total >= 5.0 - energy_cost and pile.resources.carbohydrate > 0.0, "Cargo pays the energy shortfall and restores the pile after save continuation")
	test.check(pile.workers.invariant_holds(), "Recovery travel preserves worker conservation")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.trails.routes[0].erase("energy_limited")
	legacy.trails.cohorts[0].erase("unpaid_energy_cost")
	var old_save := Controller.new()
	test.check(old_save.restore_snapshot(legacy) and not old_save.run.trails.routes.route_1.energy_limited and old_save.run.trails.cohorts.cohort_1.unpaid_energy_cost == 0.0, "Older version-5 route saves default new fields safely")


func _test_non_carbohydrate_stall(test: Object) -> void:
	var game := Controller.new(3030)
	test.check(game.dispatch_scout("home", 2.0), "Scout can seek a protein source")
	game.advance(200.0)
	test.check(game.run.knowledge.nodes.has("known:protein_01"), "Protein is learned before route investment")
	if not game.run.knowledge.nodes.has("known:protein_01"):
		return
	test.check(game.create_trail("home", "known:protein_01"), "Protein route can commit workers")
	var pile: PileState = game.run.colony.piles.home
	var route: TrailRouteState = game.run.trails.routes.route_1
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	var energy_cost: float = CONFIG.round_trip_energy_cost(5, segment.start.distance_to(segment.end), Segment.terrain_cost_for(game.run.world, segment.start, segment.end))
	pile.resources.carbohydrate = 0.0
	game.advance(0.25)
	test.check(route.status == "active" and route.energy_limited and game.run.trails.cohorts.is_empty() and pile.resources.carbohydrate == 0.0 and pile.workers.count("trail:route_1") == 5, "Low energy stalls non-carbohydrate travel without losing committed labor")
	var root := Root.new()
	root.simulation = game
	var summary: Dictionary = root.trail_summaries("home")[0]
	test.check(summary.energy_limited and not summary.has("terrain_cost") and not summary.has("energy_cost") and not summary.has("estimated_destination"), "Normal view receives only the observed energy stall")
	summary.energy_limited = false
	test.check(route.energy_limited, "Presentation cannot clear an authoritative stall")
	root.free()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot) and copy.run.to_dict() == game.run.to_dict(), "Energy-limited route saves and restores exactly")
	test.check(pile.deposit_resource("carbohydrate", energy_cost) and copy.run.colony.piles.home.deposit_resource("carbohydrate", energy_cost), "New carbohydrate can fund both routes")
	game.advance(0.25)
	copy.advance(0.25)
	test.check(not route.energy_limited and game.run.trails.cohorts.size() == 1 and pile.resources.carbohydrate == 0.0 and game.run.to_dict() == copy.run.to_dict(), "Retry launches once, pays once and continues exactly after reload")
	test.check(pile.workers.invariant_holds(), "Energy shortage and retry preserve worker conservation")


func _test_weak_source(test: Object) -> void:
	var game: SimulationController = TransitFixture.new().learned_game()
	game.run.world.nodes.carb_exposed.quantity = 0.01
	test.check(game.create_trail("home", "known:carb_exposed"), "Weak-source fixture invests a route")
	var before: float = game.run.colony.piles.home.resources.carbohydrate
	game.advance(25.0)
	test.check(game.run.trails.routes.route_1.status == "depleted" and game.run.colony.piles.home.resources.carbohydrate < before and game.run.trails.routes.route_1.delivered_total == 0.01, "Weak source yields less carbohydrate than the trip consumes")
	var exhausted: SimulationController = TransitFixture.new().learned_game()
	exhausted.run.world.nodes.carb_exposed.quantity = 0.01
	exhausted.run.colony.piles.home.resources.carbohydrate = 0.0
	test.check(exhausted.create_trail("home", "known:carb_exposed"), "Empty pile may still test a weak carbohydrate source")
	exhausted.advance(50.0)
	test.check(exhausted.run.trails.routes.route_1.status == "depleted" and exhausted.run.colony.piles.home.resources.carbohydrate == 0.0 and exhausted.run.trails.routes.route_1.delivered_total == 0.0, "Insufficient cargo settles no store and never makes carbohydrate negative")
