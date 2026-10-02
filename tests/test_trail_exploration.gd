extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const Root = preload("res://src/core/game_root.gd")
const Reports = preload("res://tests/test_knowledge.gd")


func fixture() -> SimulationController:
	var game := Controller.new(6262)
	game.dispatch_scout("home", 0.0)
	for tick: int in 400:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:carb_exposed"):
			break
	assert(game.create_trail("home", "known:carb_exposed"))
	for tick: int in 400:
		game.advance(0.25)
		if game.run.trails.segments.segment_1.route_familiarity >= game.scouting.config.established_trail_familiarity:
			break
	assert(game.run.trails.routes.route_1.delivered_total > 0)
	game.scouting.config = game.scouting.config.duplicate()
	game.scouting.config.trail_exploration_share = 1.0
	return game


func run(test: Object) -> bool:
	var game := fixture()
	var precise: Observation = Reports.new().evidence("scout_1", 10)
	precise.closest_distance = Vector2(2, 3).length()
	precise.uncertainty_radius = 0.25 + precise.closest_distance * 0.5
	var restored_evidence := Observation.new()
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(precise.to_dict(), "", true, true))
	test.check(restored_evidence.restore(decoded, game.run.world, game.run.colony, game.run.simulation_time) and restored_evidence.to_dict() == precise.to_dict(), "Legacy float32-distance-derived sensory uncertainty restores without a final-bit mismatch")
	var ledger: WorkerLedger = game.run.colony.piles.home.workers
	var route: TrailRouteState = game.run.trails.routes.route_1
	var trail_workers: int = ledger.count("trail:route_1")
	game.set_exploration(1)
	game.advance(0.25)
	var agent: ScoutAgent = game.run.scouts.values()[0]
	var id: String = agent.id
	test.check(agent.trunk_route_id == route.id and agent.trunk_path.back() == route.estimated_destination.round(), "Standing explorer captures an established colony-estimated trunk")
	test.check(agent.position == game.run.colony.piles.home.position and agent.phase == "departing" and ledger.count(id) == 1 and ledger.count("trail:route_1") == trail_workers, "Trunk explorer starts at home in its own commitment without borrowing trail labor")
	var truth: Vector2 = game.run.world.nodes.carb_exposed.position
	game.run.world.nodes.carb_exposed.position = Vector2(38, 38)
	test.check(agent.trunk_path.back() == route.estimated_destination.round(), "Changing hidden truth cannot refresh a captured trunk destination")
	game.run.world.nodes.carb_exposed.position = truth
	game.advance(0.5)
	test.check(agent.phase == "following_trail" and agent.position != game.run.colony.piles.home.position and agent.position != agent.trunk_path.back(), "Trunk travel advances gradually rather than spawning at its endpoint")
	test.check(is_equal_approx(agent.position.distance_to(game.run.colony.piles.home.position), 0.3125), "Established trunk gives the authored travel benefit while preserving elapsed movement")
	var root := Root.new()
	root.simulation = game
	for summary: Dictionary in root.scout_mission_summaries("home"):
		if summary.id == id:
			test.check(summary.course.is_empty() and not summary.has("trunk_path"), "Away trunk travel exposes departure facts only")
	root.free()
	var copy := Controller.new()
	var saved: Dictionary = Snapshot.new().snapshot(game)
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Mid-trunk fractional travel restores exactly")
	var before: Dictionary = copy.run.to_dict()
	for change: Dictionary in [{"trunk_route_id": "route_missing"}, {"trunk_path": [[20,20],[39,39]]}, {"standing": false}, {"elapsed": 1.0}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.scouts[0].merge(change, true)
		test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == before, "Malformed trunk identity/geometry/phase rejects atomically")
	game.toggle_pause()
	before = game.run.to_dict()
	game.advance(10)
	test.check(game.run.to_dict() == before, "Pause freezes physical trunk travel")
	game.toggle_pause()
	game.set_trail_workers(route.id, 0)
	copy.set_trail_workers(route.id, 0)
	var branched: bool = false
	for tick: int in 300:
		game.advance(0.25)
		copy.advance(0.25)
		if game.run.scouts.has(id) and agent.phase == "exploring":
			branched = true
			break
	test.check(branched and agent.return_path.has(agent.trunk_path.back()) and agent.elapsed == 0, "Explorer reaches the real trail end then begins its search budget despite withdrawal")
	test.check(copy.run.to_dict() == game.run.to_dict(), "Mid-trunk restore continues exactly through withdrawal and branching")
	game.advance(3)
	test.check(agent.position.distance_to(agent.trunk_path.back()) > 0 and game.run.exploration.coverage.is_empty(), "Branch searches beyond the end while its new coverage remains private")
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Mid-branch travel restores")
	game.set_exploration(0)
	copy.set_exploration(0)
	before = game.run.to_dict()
	test.check(agent.phase == "returning" and agent.path.back() == game.run.colony.piles.home.position and agent.path.has(agent.trunk_path.back()) and ledger.count(id) == 1, "Recall retraces the branch and rejoins its captured trunk before home release")
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Mid-return trunk recall restores")
	for scale: int in [4,16,64]:
		var a := Controller.new()
		var b := Controller.new()
		assert(a.restore_snapshot(Snapshot.new().snapshot(game)) and b.restore_snapshot(Snapshot.new().snapshot(game)))
		a.advance(60)
		b.set_time_scale(scale)
		b.advance(60.0 / scale)
		b.set_time_scale(1)
		test.check(a.run.to_dict() == b.run.to_dict() and not a.run.scouts.has(id) and a.run.colony.piles.home.workers.invariant_holds(), "Branch/trunk return and release continue exactly at %dx" % scale)
	game.advance(60)
	test.check(not game.run.scouts.has(id) and not game.run.exploration.coverage.is_empty() and game.run.scout_missions[id].course.size() > 0 and ledger.available == ledger.total, "Real home return delivers coarse course/coverage and releases both recalled labor groups")
	var risky := fixture()
	risky.run.trails.routes.route_1.foreign_reports = 1 # Returned policy input; not a hidden encounter.
	risky.set_exploration(1)
	risky.advance(0.25)
	test.check(risky.run.scouts.values()[0].trunk_route_id.is_empty(), "Returned danger/contact evidence prevents automatic use of a risky trunk")
	var depleted := fixture()
	depleted.run.world.nodes.carb_exposed.quantity = 0
	for tick: int in 400:
		depleted.advance(0.25)
		if depleted.run.trails.routes.route_1.reported_depleted:
			break
	depleted.set_exploration(1)
	depleted.advance(0.25)
	test.check(depleted.run.trails.routes.route_1.reported_depleted and depleted.run.scouts.values()[0].trunk_route_id == "route_1", "A returned-depleted destination can still provide remembered infrastructure for new exploration")
	return true
