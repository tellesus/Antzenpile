extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const SensoryFixture = preload("res://tests/test_observations.gd")
const GameRoot = preload("res://src/core/game_root.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")


func run(test: Object) -> bool:
	var game: SimulationController = SensoryFixture.new().fixture()
	var ledger: WorkerLedger = game.run.colony.piles.home.workers
	test.check(not game.create_trail("home", "known:carb_exposed") and game.run.trails.routes.is_empty() and ledger.available == 39, "Private scout evidence cannot create route")
	game.advance(85.0)
	test.check(game.run.knowledge.nodes.has("known:carb_exposed") and game.run.scouts.is_empty(), "Known destination available after scout return")
	var known: KnownNode = game.run.knowledge.nodes["known:carb_exposed"]
	var estimate: Vector2 = known.estimated_position
	var before: Dictionary = game.run.to_dict()
	test.check(not game.create_trail("missing", known.id) and not game.create_trail("home", "unknown") and game.run.to_dict() == before, "Unknown origin or destination rejects atomically")
	var rng_before: int = game.run.rng.state
	test.check(game.create_trail("home", known.id) and ledger.available == 35, "Initial route reserves five workers")
	var route: TrailRouteState = game.run.trails.routes.route_1
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	test.check(route.id != segment.id and route.segment_id == segment.id and segment.route_id == route.id and segment.start == Vector2(20, 20) and segment.end == estimate, "Route and segment have distinct stable identity and captured estimate")
	test.check(route.desired_workers == 5 and route.allocated_workers == 5 and route.active_workers == 0 and ledger.count("trail:route_1") == 5 and segment.pheromone_strength == 0 and segment.route_familiarity == 0, "Labor and future chemistry fields remain separate")
	test.check(game.run.rng.state == rng_before, "Route creation uses no RNG")
	before = game.run.to_dict()
	test.check(not game.create_trail("home", known.id) and game.run.to_dict() == before, "Duplicate active route rejects atomically")
	test.check(not game.set_trail_workers(route.id, 41) and game.run.to_dict() == before and not game.trails.last_error.is_empty(), "Labor shortage rejects exact target atomically")
	test.check(not game.set_trail_workers(route.id, 1.5) and not game.set_trail_workers("missing", 2) and game.run.to_dict() == before, "Invalid target and route reject atomically")
	test.check(ledger.create_commitment("test_internal", "internal", "test") and ledger.allocate("test_internal", 3), "Independent job reserves workers")
	test.check(game.set_trail_workers(route.id, 7) and ledger.count("trail:route_1") == 7 and ledger.available == 30 and ledger.count("test_internal") == 3, "Increasing allocation preserves independent pool")
	test.check(game.set_trail_workers(route.id, 2) and ledger.available == 35 and ledger.count("trail:route_1") == 2, "Reduction returns exact difference")
	test.check(game.set_trail_workers(route.id, 0) and ledger.available == 37 and ledger.count("trail:route_1") == -1 and route.status == "inactive" and game.run.trails.segments.has(segment.id), "Cancellation releases workers but preserves route and segment")
	test.check(game.create_trail("home", known.id) and game.run.trails.next_route_id == 2 and game.run.trails.routes.route_1 == route and game.run.trails.segments.segment_1 == segment and route.allocated_workers == 5, "Reopening reuses identity and initial investment")
	var saved: Dictionary = game.run.to_dict()
	var restored := Controller.new()
	test.check(restored.run.restore(JSON.parse_string(JSON.stringify(saved, "", true, true))) and restored.run.to_dict() == saved, "Trail and ledger full-precision JSON round trip")
	for index: int in range(100):
		game.advance(0.25)
		restored.advance(0.25)
		test.check(game.run.to_dict() == restored.run.to_dict(), "Trail continuation matches after reload %d" % index)
	var invalid: Dictionary = saved.duplicate(true)
	invalid.trails.routes[0].allocated_workers += 1
	# The continuation above moved time forward; compare each rejected restore to its current state.
	before = restored.run.to_dict()
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Mismatched route allocation rejects atomically")
	invalid = saved.duplicate(true)
	invalid.trails.segments[0].pheromone_strength = 1.2
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Out-of-range chemical state rejects atomically")
	invalid = saved.duplicate(true)
	invalid.trails.segments[0].end[0] += 1
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Mismatched segment estimate rejects atomically")
	invalid = saved.duplicate(true)
	invalid.trails.segments[0].route_id = "route_99"
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Wrong segment owner rejects atomically")
	invalid = saved.duplicate(true)
	invalid.trails.routes.clear()
	invalid.trails.segments.clear()
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Orphan trail commitment rejects atomically")
	var root := GameRoot.new()
	root.simulation = game
	var summaries: Dictionary = root.outward_status("home")
	test.check(summaries.trails.size() == 1 and summaries.trails[0].allocated_workers == 5 and not summaries.trails[0].has("estimated_destination"), "Normal UI gets detached labor summary without geometry")
	summaries.trails[0].allocated_workers = 999
	test.check(route.allocated_workers == 5, "Presentation mutation cannot change route")
	var view := Outward.new()
	test.get_root().add_child(view)
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = view._signals[0].id
	view.trail_create_command = root.create_trail_for
	view.trail_set_command = root.set_trail_target
	var more: Vector2 = view._trail_button_rect("trail_more").get_center()
	test.check(view._button_at(more) == "trail_more", "Selected route exposes adjustment hit target")
	view._pointer_press(more, "mouse")
	test.check(route.allocated_workers == 6 and ledger.count("trail:route_1") == 6, "OUTWARD adjustment uses semantic allocation command")
	view._status = root.outward_status("home")
	view._pointer_press(view._trail_button_rect("trail_cancel").get_center(), "touch")
	test.check(route.status == "recalling" and route.desired_workers == 0 and ledger.count("trail:route_1") == route.active_workers, "OUTWARD cancellation waits for travelling labor")
	view._status = root.outward_status("home")
	view._pointer_press(view._trail_button_rect("trail_create").get_center(), "mouse")
	test.check(route.status == "active" and route.allocated_workers == 5, "OUTWARD investment reopens preserved route")
	view.free()
	root.free()
	game.run.world.nodes.carb_exposed.position = Vector2(35, 35)
	game.run.world.nodes.carb_exposed.quantity = 0
	game.run.world.nodes.carb_exposed.active = false
	known.estimated_position = Vector2(31, 25)
	test.check(segment.end == estimate and game.run.rng.state == restored.run.rng.state, "Hidden truth and later estimate cannot silently move invested route")
	return true
