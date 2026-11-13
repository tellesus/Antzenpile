extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))

func fixture(seed_value: int = 3043) -> SimulationController:
	var game := Controller.new(seed_value, "roadside")
	game.dispatch_scout("home", 0.0)
	for tick: int in 6000:
		if game.run.knowledge.nodes.has("known:carb_exposed"): break
		game.advance(0.25)
	for id: String in game.run.scouts.keys(): game.recall_scout(id)
	for tick: int in 6000:
		if game.run.scouts.is_empty(): break
		game.advance(0.25)
	var first: float = SurfaceImpactState.first_tick(seed_value) * 0.25
	game.advance(maxf(0.0, first - 3.0 - game.run.simulation_time))
	game.create_trail("home", "known:carb_exposed")
	return game

func returned(seed_value: int = 3043) -> SimulationController:
	var game := fixture(seed_value)
	for tick: int in 500:
		if not game.run.trails.routes.route_1.impact_report.is_empty(): break
		game.advance(0.25)
	return game

func run(test: Object) -> bool:
	var game := fixture()
	var root := Root.new(); root.simulation = game
	test.check(game.run.knowledge.nodes.has("known:carb_exposed") and game.run.trails.routes.has("route_1"), "Real Roadside scout establishes an exposed gathering route")
	for tick: int in 200:
		if game.run.surface_impact.kills_total > 0: break
		game.advance(0.25)
	var route: TrailRouteState = game.run.trails.routes.route_1
	test.check(game.run.surface_impact.kills_total > 0 and route.reported_losses == 0 and route.impact_report.is_empty(), "Physical impact kills actual travelers before colony evidence arrives")
	test.check(not str(root.sensory_snapshot("home")).contains("threat:") and root.trail_summaries("home")[0].allocated_workers == 5, "Private impact loss is concealed in expected workforce and sensory view")
	var twin := Controller.new()
	test.check(twin.restore_snapshot(snapshot(game)), "Impact in-flight casualties restore with independent cause accounting")
	game.toggle_pause(); var paused: Dictionary = game.run.to_dict(); game.advance(200)
	test.check(game.run.to_dict() == paused, "Pause freezes disturbance cycle and travel")
	game.toggle_pause()
	for tick: int in 200:
		if not route.impact_report.is_empty(): break
		game.advance(0.25); twin.advance(0.25)
	test.check(game.run.to_dict() == twin.run.to_dict() and not route.impact_report.is_empty(), "Surviving physical return delivers dated impact evidence and exact saved continuation")
	test.check(route.reported_impact_losses > 0 and route.attack_reports == 0 and game.run.predator.kills_total == 0, "Impact losses never masquerade as predation")
	test.check(str(root.sensory_snapshot("home")).contains("surface") and root.trail_summaries("home")[0].surface_warning, "Returned witness produces a selectable coarse disturbance trace")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.journey_response.set_force("route_1", 24) and not game.journey_response.defend("route_1") and not game.journey_response.set_goal("route_1", "hunt") and game.run.to_dict() == before, "Unassailable disturbance rejects fighting and hunting atomically")
	var view := View.new(); view._status = root.outward_status("home")
	test.check(not view._can_mobilize(root.trail_summaries("home")[0]), "Delivered impact panel cannot offer hidden force controls")
	test.check(game.set_trail_workers("route_1", 0), "Player withdraws gatherers through their real owner")
	for tick: int in 200:
		if route.allocated_workers == 0: break
		game.advance(0.25)
	test.check(route.allocated_workers == 0 and game.run.colony.piles.home.workers.invariant_holds(), "Withdrawal returns survivors without refunding dead workers")
	test.check(game.journey_response.investigate("route_1"), "Returned losses fund a cautious physical survey")
	game.advance(4)
	test.check(twin.restore_snapshot(snapshot(game)), "Private disturbed-ground sensing restores before return")
	for tick: int in 300:
		if not game.run.journey_response.active(): break
		game.advance(0.25); twin.advance(0.25)
	test.check(game.run.to_dict() == twin.run.to_dict() and game.run.journey_response.reports.route_1.finding == "surface", "Paid survey recognizes disturbed ground only on actual passage and reports at home")
	var saved: Dictionary = snapshot(game)
	var bad: Dictionary = saved.duplicate(true); bad.surface_impact.kills_total += 1
	test.check(not twin.restore_snapshot(bad), "Forged environmental casualty totals reject atomically")
	bad = saved.duplicate(true); bad.trails.routes[0].reported_impact_losses = 0
	test.check(not twin.restore_snapshot(bad), "Relabeling impact casualties as predation rejects")
	bad = saved.duplicate(true); bad.surface_impact.serial += 1
	test.check(not twin.restore_snapshot(bad), "Future physical impact history rejects")
	test.check(game.journey_response.investigate_approach("route_1"), "Player pays for a physically different course")
	for tick: int in 500:
		if not game.run.journey_response.active(): break
		game.advance(0.25)
	test.check(game.run.journey_response.approach.reports.route_1.outcome == "found", "Alternative avoids the impact footprint without defeating an imaginary enemy")
	var losses: int = game.run.surface_impact.kills_total
	var cargo: float = route.delivered_total
	test.check(game.set_trail_workers("route_1", 5), "Gathering resumes deliberately on the longer course")
	test.check(twin.restore_snapshot(snapshot(game)), "Changed course and returned impact history save together")
	game.advance(220); twin.advance(220)
	test.check(game.run.to_dict() == twin.run.to_dict() and game.run.surface_impact.kills_total == losses and route.delivered_total > cargo, "Next real impact does not harm rerouted gathering; paid harvest continues")
	var legacy := Controller.new(3043, "roadside"); var old: Dictionary = snapshot(legacy); old.erase("surface_impact")
	test.check(legacy.restore_snapshot(old) and not legacy.run.surface_impact.enabled, "Old saves retain their previous environment instead of silently adding hazards")
	# A lone traveler cannot deliver a witness, even though the physical cause is known privately.
	var lone := fixture(); lone.set_trail_workers("route_1", 1)
	for tick: int in 300:
		if lone.run.trails.routes.route_1.reported_losses > 0: break
		lone.advance(0.25)
	var missing: TrailRouteState = lone.run.trails.routes.route_1
	test.check(missing.missing_workers == 1 and missing.impact_report.is_empty() and missing.attack_reports == 0, "Wholly lost impact group becomes missing at expected return without a fabricated witness")
	test.check(twin.restore_snapshot(snapshot(lone)), "Complete environmental loss reconciles and restores")
	for seed_value: int in [71, 3030, 3043]:
		var ordinary := returned(seed_value)
		var ordinary_route: TrailRouteState = ordinary.run.trails.routes.route_1
		test.check(not ordinary_route.impact_report.is_empty() and ordinary_route.reported_impact_losses > 0 and ordinary.run.predator.kills_total == 0, "Ordinary seed %d carries actual impact evidence home" % seed_value)
		ordinary.set_trail_workers("route_1", 0); ordinary.advance(30)
		var historical: Dictionary = ordinary_route.impact_report.duplicate(true)
		ordinary.advance(200)
		test.check(ordinary_route.impact_report == historical and twin.restore_snapshot(snapshot(ordinary)), "Quiet later impacts cannot refresh remote colony evidence (%d)" % seed_value)
	view.free(); root.free()
	return true
