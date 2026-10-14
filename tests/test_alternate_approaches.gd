extends RefCounted
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
func run(test: Object) -> bool:
	var game: SimulationController = Defense.new().ready_game()
	var initial: Dictionary = Defense.new().snapshot(game)
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	var distance: float = segment.length()
	var food: float = game.run.colony.piles.home.resources.carbohydrate
	test.check(game.journey_response.investigate_approach("route_1"), "Paused route funds three-worker alternate investigation")
	test.check(game.run.colony.piles.home.resources.carbohydrate < food and segment.waypoints.is_empty(), "Departure pays but does not establish a course prematurely")
	test.check(not game.set_trail_workers("route_1", 5), "Gatherers cannot restart under an unresolved course survey")
	var twin := Controller.new()
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Private candidate restores before it is known")
	for tick: int in 1200:
		if not game.run.journey_response.active(): break
		game.advance(0.25); twin.advance(0.25)
		test.check(game.run.to_dict() == twin.run.to_dict(), "Actual longer survey continues exactly")
		if game.run.journey_response.active(): test.check(game.run.trails.segments.segment_1.waypoints.is_empty(), "Course stays unchanged until physical return")
	var report: Dictionary = game.run.journey_response.approach.reports.route_1
	test.check(report.outcome == "found", "Full returned survey establishes a physically clear alternate")
	segment = game.run.trails.segments.segment_1
	test.check(segment.waypoints.size() == 2 and segment.length() > distance, "Installed infrastructure follows a genuinely longer path")
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Returned alternative restores without replacing threat history")
	var root := Root.new(); root.simulation = game
	test.check(not root.journey_alarm(game.run.trails.routes.route_1) and game.run.predator.defeated_at == 0, "Returned course settles urgency without claiming the predator died")
	var kills: int = game.run.predator.kills_total
	var cargo: float = game.run.trails.routes.route_1.delivered_total
	test.check(game.set_trail_workers("route_1", 5), "Player deliberately resumes gathering on the new approach")
	game.advance(20)
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Active longer-route travelers restore")
	game.advance(120); twin.advance(120)
	test.check(game.run.to_dict() == twin.run.to_dict() and game.run.predator.kills_total == kills and game.run.trails.routes.route_1.delivered_total > cargo, "New course delivers food without crossing the old predator")
	var established: Dictionary = Defense.new().snapshot(game)
	var broken: Dictionary = established.duplicate(true); broken.journey_response.approach.established_at.clear()
	test.check(not twin.restore_snapshot(broken), "Changed course requires a returned establishment record")
	broken = established.duplicate(true); broken.journey_response.erase("approach")
	test.check(not twin.restore_snapshot(broken), "Removing establishment state cannot legitimize an unreported course")
	game = Controller.new(); game.restore_snapshot(initial)
	game.journey_response.investigate_approach("route_1"); game.advance(3); game.journey_response.recall()
	while game.run.journey_response.active(): game.advance(0.25)
	test.check(game.run.trails.segments.segment_1.waypoints.is_empty() and game.run.journey_response.approach.reports.route_1.outcome == "unconfirmed", "Early recall never certifies an unwalked approach")
	# Narrow authored offset physically encounters the same attacker, rather than guaranteeing a bypass.
	game = Controller.new(); game.restore_snapshot(initial); game.journey_response.investigate_approach("route_1")
	game.run.journey_response.approach.candidate.waypoints = [Vector2(24,23),Vector2(31,29)]
	while game.run.journey_response.active(): game.advance(0.25)
	test.check(game.run.journey_response.approach.reports.route_1.outcome == "danger" and game.run.trails.segments.segment_1.waypoints.is_empty(), "Witnessed candidate danger leaves the old course unchanged")
	game = Controller.new(); game.restore_snapshot(initial); game.journey_response.investigate_approach("route_1")
	var obstacle: Vector2 = game.run.journey_response.approach.candidate.waypoints[0]
	game.run.world.terrain.push_front({"id":"approach_obstacle","bounds":[obstacle.x-1,obstacle.y-1,2,2],"exposure":0.0,"traversable":false,"movement_cost":1.0})
	while game.run.journey_response.active(): game.advance(0.25)
	test.check(game.run.journey_response.approach.reports.route_1.outcome == "unconfirmed" and game.run.trails.segments.segment_1.waypoints.is_empty(), "Actual blocked ground turns investigators back without establishing a course")
	root.free(); return true
