extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const CONFIG = preload("res://data/ecology/backyard_rival.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")


func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func fixture() -> SimulationController:
	var game := Controller.new(3048)
	game.dispatch_scout("home", 0.0)
	game.advance(100.0)
	game.advance(570.0)
	game.create_trail("home", "known:carb_exposed")
	return game


func run(test: Object) -> bool:
	var game := Controller.new(3048)
	var rival: RivalState = game.run.rival
	var food: WorldNodeState = game.run.world.nodes[CONFIG.food_id]
	var leg: int = TRAILS.leg_ticks(CONFIG.pile_position.distance_to(food.position))
	var player_population: int = game.run.colony.workers_total
	game.advance(599.75)
	test.check(rival.direction == "dormant" and rival.workers.total == 30 and rival.workers.available == 30 and food.quantity == 0.0 and not food.active, "Rival population exists privately without activity before its authored start")
	game.advance(0.25)
	test.check(rival.direction == "outbound" and rival.remaining_ticks == leg and rival.workers.count("rival:trail") == 6 and rival.workers.available == 24 and game.run.colony.workers_total == player_population, "Rival reserves six of its own ledger workers without changing player population")
	game.advance(leg * 0.25)
	test.check(rival.direction == "inbound" and rival.cargo == 6.0 and rival.stored_carbohydrate == 0.0 and food.quantity == 54.0, "Rival collects at its food endpoint and retains cargo during return travel")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)) and copy.run.to_dict() == game.run.to_dict(), "Rival in-flight cargo saves exactly")
	game.advance(leg * 0.25)
	copy.advance(leg * 0.25)
	test.check(rival.cargo == 0.0 and rival.stored_carbohydrate == 6.0 and rival.pheromone > 0.1 and copy.run.to_dict() == game.run.to_dict(), "Loaded rival home arrival deposits cargo and establishes foreign chemistry")
	test.check(food.quantity == 57.0, "Authored renewable food physically replenishes alongside rival harvesting")
	var other := Controller.new(3048)
	test.check(other.run.rival.workers.available == 30 and other.run.world.nodes[CONFIG.food_id].quantity == 0.0, "Rival state and food are isolated across fresh runs")
	game = fixture()
	var route: TrailRouteState = game.run.trails.routes.route_1
	var root := Root.new()
	root.simulation = game
	for tick: int in 100:
		if game.run.rival.contacts_total > 0:
			break
		game.advance(0.25)
	test.check(game.run.rival.contacts_total == 1 and route.foreign_reports == 0 and game.run.trails.cohorts.values()[0].foreign_contact, "Player travelers physically sample foreign trail chemistry privately")
	test.check(not root.sensory_snapshot("home")[0].foreign_contact and not root.outward_status("home").has("rival"), "Private contact reveals no rival signal, population or network")
	var private_save: Dictionary = snapshot(game)
	test.check(copy.restore_snapshot(private_save), "Private foreign contact saves before delivery")
	for tick: int in 200:
		if route.foreign_reports > 0:
			break
		game.advance(0.25)
		copy.advance(0.25)
	test.check(route.foreign_reports == 1 and route.last_foreign_time == game.run.simulation_time and root.sensory_snapshot("home")[0].foreign_contact and copy.run.to_dict() == game.run.to_dict(), "Home return delivers contact once and survives exact continuation")
	var summary: Dictionary = root.trail_summaries("home")[0]
	test.check(summary.foreign_reports == 1 and not summary.has("rival_position") and not summary.has("foreign_workers") and not summary.has("start"), "Approved contact summary carries only historical colony evidence")
	var view: OutwardView = View.new()
	test.get_root().add_child(view)
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = "signal:known:carb_exposed"
	view.trail_set_command = root.set_trail_target
	view._pointer_press(view._trail_button_rect("trail_cancel").get_center(), "touch")
	test.check(route.desired_workers == 0, "Touch Stop Traffic lets the player avoid returned foreign contact")
	game.advance(30.0)
	var contacts_after_recall: int = game.run.rival.contacts_total
	game.advance(60.0)
	test.check(game.run.rival.contacts_total == contacts_after_recall and route.allocated_workers == 0, "Recall blocks further crossings and releases travelers")
	game.dispatch_scout("home", PI)
	game.advance(100.0)
	test.check(game.create_trail("home", "known:carb_sheltered"), "Player may invest a safe alternative")
	game.advance(60.0)
	test.check(game.run.rival.contacts_total == contacts_after_recall and game.run.trails.routes.route_2.delivered_total > 0.0, "Safe remembered route gathers food without foreign contact")
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = "signal:known:carb_sheltered"
	view._pointer_press(view._trail_button_rect("trail_cancel").get_center(), "mouse")
	test.check(game.run.trails.routes.route_2.desired_workers == 0, "Mouse uses the same traffic withdrawal command")
	view.free()
	root.free()
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(120.0)
	test.check(game.run.to_dict() == paused, "Pause freezes rival travel, cargo and chemistry")
	game.toggle_pause()
	test.check(copy.restore_snapshot(snapshot(game)), "Returned foreign history saves")
	game.advance(60.0)
	copy.set_time_scale(4)
	copy.advance(15.0)
	copy.set_time_scale(1)
	test.check(copy.run.to_dict() == game.run.to_dict(), "Rival and player continuation match across simulation speed")
	for field: String in ["contacts", "time", "workers", "cargo", "chemical", "private_flag"]:
		var invalid: Dictionary = private_save.duplicate(true)
		match field:
			"contacts": invalid.rival.contacts_total += 1
			"time": invalid.trails.routes[0].last_foreign_time = 99999.0
			"workers": invalid.rival.workers.commitments["rival:trail"].count = 7
			"cargo": invalid.rival.cargo = 7.0
			"chemical": invalid.rival.pheromone = 1.1
			"private_flag": invalid.trails.cohorts[0].foreign_contact = "yes"
		var before: Dictionary = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Invalid foreign snapshot rejects atomically: " + field)
	var legacy: Dictionary = snapshot(other)
	legacy.erase("rival")
	for index: int in range(legacy.world.nodes.size() - 1, -1, -1):
		if legacy.world.nodes[index].id == CONFIG.food_id:
			legacy.world.nodes.remove_at(index)
	test.check(copy.restore_snapshot(legacy), "Older version-5 world without rival state/source loads")
	copy.advance(700.0)
	test.check(copy.run.rival.direction == "dormant" and copy.run.rival.contacts_total == 0, "Absent old-world food node keeps the optional rival dormant")
	_test_lost_report(test)
	return true


func _test_lost_report(test: Object) -> void:
	var game := Controller.new(3043)
	game.dispatch_scout("home", PI / 4.0)
	game.advance(250.0)
	game.advance(420.0)
	test.check(game.create_trail("home", "known:aphid_01") and game.set_trail_workers("route_1", 1), "Singleton foreign-report fixture invests a known crossing")
	game.advance(0.25)
	var cohort: TransitCohort = game.run.trails.cohorts.values()[0]
	var route: TrailRouteState = game.run.trails.routes.route_1
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	cohort.direction = "inbound"
	cohort.remaining_ticks = roundi(TRAILS.leg_ticks(segment.start.distance_to(segment.end)) * 0.54)
	game.advance(0.25)
	test.check(cohort.foreign_contact and cohort.worker_count == 0, "A carrier can sense foreign chemistry and die before reporting it")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Lost private foreign evidence saves as an expected-return record")
	game.advance(30.0)
	copy.advance(30.0)
	test.check(route.foreign_reports == 0 and route.reported_losses == 1 and game.run.rival.unreturned_contacts == 1 and game.run.to_dict() == copy.run.to_dict(), "Wholly lost group yields missing workers without omniscient foreign identity")
