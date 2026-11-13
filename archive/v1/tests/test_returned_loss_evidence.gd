extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const PredatorFixture = preload("res://tests/test_predator.gd")
const SwarmFixture = preload("res://tests/test_swarm.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Scent = preload("res://src/presentation/outward/trail_visual.gd")
const Evidence = preload("res://src/presentation/returned_loss_evidence.gd")


func run(test: Object) -> bool:
	var fixture := PredatorFixture.new()
	var game: SimulationController = fixture._fixture()
	var root := Root.new()
	root.simulation = game
	var route: TrailRouteState = game.run.trails.routes.route_1
	fixture._until_loss(game)
	var cohort: TransitCohort = game.run.trails.cohorts.values()[0]
	test.check(cohort.witnessed_attack and route.attack_reports == 0 and Evidence.lines(root.trail_summaries("home")[0], game.run.simulation_time).is_empty(), "Survivor alarm remains private during travel")
	var saved: Dictionary = fixture._snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Private sensory witness and casualty restore exactly")
	for tick: int in 1000:
		if route.reported_losses > 0:
			break
		game.advance(0.25)
		copy.advance(0.25)
	var lines: Array[String] = Evidence.lines(root.trail_summaries("home")[0], game.run.simulation_time)
	test.check(route.attack_reports == 1 and route.last_witness_time == route.last_loss_time and lines[0].contains("Sudden attack") and lines[1].contains("journey"), "Home survivor reports a witnessed sudden attack along its journey")
	test.check(game.run.to_dict() == copy.run.to_dict() and not route.reported_depleted, "Witness delivery preserves continuation and resource availability")
	for tick: int in 1400:
		if route.attack_reports >= 2:
			break
		game.advance(0.25)
	lines = Evidence.lines(root.trail_summaries("home")[0], game.run.simulation_time)
	test.check(route.attack_reports >= 2 and lines[0].contains("Repeated attacks"), "Repeated delivered attacks strengthen route evidence")
	game.set_trail_workers(route.id, 0)
	game.advance(100.0)
	var evidence_before: Array[String] = Evidence.lines(root.trail_summaries("home")[0], game.run.simulation_time)
	game.advance(20.0)
	lines = Evidence.lines(root.trail_summaries("home")[0], game.run.simulation_time)
	test.check(lines[0] == evidence_before[0] and lines[2] != evidence_before[2], "Historical danger stays remembered while report age grows")
	_test_view(test, root)
	var returned: Dictionary = fixture._snapshot(game)
	for field: String in ["attack", "fighting", "missing", "future", "type"]:
		var invalid: Dictionary = returned.duplicate(true)
		match field:
			"attack": invalid.trails.routes[0].attack_reports = invalid.trails.routes[0].reported_losses + 1
			"fighting": invalid.trails.routes[0].fighting_reports = 1
			"missing": invalid.trails.routes[0].missing_workers = invalid.trails.routes[0].reported_losses
			"future": invalid.trails.routes[0].last_witness_time = game.run.simulation_time + 1.0
			"type": invalid.trails.routes[0].attack_reports = true
		var before: Dictionary = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Impossible witness history rejects atomically: " + field)
	var legacy: Dictionary = returned.duplicate(true)
	for item: Dictionary in legacy.trails.routes:
		for key: String in ["attack_reports", "fighting_reports", "missing_workers", "last_witness_time"]:
			item.erase(key)
	for item: Dictionary in legacy.trails.cohorts:
		item.erase("witnessed_attack")
		item.erase("witnessed_fighting")
	test.check(copy.restore_snapshot(legacy) and copy.run.trails.routes.route_1.attack_reports == 0 and Evidence.lines(copy.run.trails.routes.route_1.to_dict(), copy.run.simulation_time)[0].contains("cause unknown"), "Legacy losses do not retroactively reveal a predator")
	root.free()
	_test_missing(test)
	_test_fighting(test)
	return true


func _test_missing(test: Object) -> void:
	var fixture := PredatorFixture.new()
	var game: SimulationController = fixture._fixture()
	game.set_trail_workers("route_1", 1)
	fixture._until_loss(game)
	var route: TrailRouteState = game.run.trails.routes.route_1
	var cohort: TransitCohort = game.run.trails.cohorts.values()[0]
	test.check(cohort.worker_count == 0 and not cohort.witnessed_attack and not cohort.witnessed_fighting and route.missing_workers == 0, "Wholly lost party has no returning witness or immediate missing report")
	var invalid: Dictionary = fixture._snapshot(game)
	invalid.trails.cohorts[0].witnessed_attack = true
	var copy := Controller.new()
	test.check(not copy.restore_snapshot(invalid), "A dead party cannot carry a survivor report")
	for tick: int in 600:
		if route.reported_losses > 0:
			break
		game.advance(0.25)
	var lines: Array[String] = Evidence.lines(route.to_dict(), game.run.simulation_time)
	test.check(route.missing_workers == 1 and route.attack_reports == 0 and route.last_witness_time == 0.0 and lines[0] == "Workers missing · cause unknown", "Expected return yields missing evidence without revealing the actual killer")
	test.check(copy.restore_snapshot(fixture._snapshot(game)), "Unwitnessed missing evidence restores")
	test.check(game.set_trail_workers("route_1", 5), "Player can reinvest after a missing report")
	for tick: int in 1400:
		if route.attack_reports > 0:
			break
		game.advance(0.25)
	lines = Evidence.lines(route.to_dict(), game.run.simulation_time)
	test.check(route.attack_reports > 0 and route.missing_workers == 1 and lines[1].contains("missing without witnesses"), "Later witnesses do not rewrite an earlier unwitnessed disappearance")
	test.check(copy.restore_snapshot(fixture._snapshot(game)), "Mixed missing and witnessed losses save consistently")


func _test_fighting(test: Object) -> void:
	var game: SimulationController = SwarmFixture.new().forming_fixture()
	var route: TrailRouteState = game.run.trails.routes.route_1
	game.set_trail_workers(route.id, 9)
	for tick: int in 1600:
		if game.run.swarm.phase == "finished":
			break
		game.advance(0.25)
	game.set_trail_workers(route.id, 0)
	game.advance(100.0)
	var lines: Array[String] = Evidence.lines(route.to_dict(), game.run.simulation_time)
	test.check(route.reported_rival_losses > 0 and route.fighting_reports > 0 and route.attack_reports == 0 and lines[0] == "Foreign-ant fighting reported", "Surviving combat parties report foreign fighting rather than an unidentified predator")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(PredatorFixture.new()._snapshot(game)), "Foreign-fighting witness history restores")


func _test_view(test: Object, root: Node) -> void:
	var view: OutwardView = View.new()
	test.get_root().add_child(view)
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view._placed = Panorama.project(view._signals, 0.0, view.get_viewport_rect().size)
	var before: Dictionary = root.simulation.run.to_dict()
	var markers: Array[Dictionary] = Scent.alarm_markers(view._status.trails, view._placed, view.get_viewport_rect().size)
	test.check(markers.size() == 1 and markers[0].center != view._placed[0].center, "Alarm belongs to the abstract journey rather than its food cloud")
	for kind: String in ["mouse", "touch"]:
		view._pointer_press(markers[0].center, kind)
		view._pointer_release(markers[0].center, kind)
		test.check(view.selected_id == "signal:known:aphid_01" and view._evidence_offset() == 48.0, "Journey alarm selects its evidence context: " + kind)
	test.check(root.simulation.run.to_dict() == before, "Inspecting evidence does not alter gameplay")
	var summary: Dictionary = root.trail_summaries("home")[0]
	summary.attack_reports = 0
	test.check(root.trail_summaries("home")[0].attack_reports > 0 and not summary.has("position") and not summary.has("predator"), "Returned evidence projection is detached and excludes hidden threat state")
	view.free()
