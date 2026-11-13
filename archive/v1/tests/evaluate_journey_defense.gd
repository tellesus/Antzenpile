extends SceneTree
const Fixture = preload("res://tests/test_ambusher_defense.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var records: Array[Dictionary] = []
	for seed_value: int in [3043,591,482817]:
		var baseline: SimulationController = Fixture.new().ready_game(seed_value)
		var saved: Dictionary = Fixture.new().snapshot(baseline)
		var defended := Controller.new(); var recalled := Controller.new(); var untreated := Controller.new()
		for game: SimulationController in [defended,recalled,untreated]:
			if not game.restore_snapshot(saved): failed = true
		if not defended.journey_response.defend("route_1") or not recalled.journey_response.defend("route_1"): failed = true
		recalled.advance(6); recalled.journey_response.recall()
		var duration: float = 6
		while defended.run.journey_response.active() or recalled.run.journey_response.active():
			defended.advance(0.25); recalled.advance(0.25); duration += 0.25
		# Equal physical times before reopening each ordinary route.
		defended.advance(6); untreated.advance(duration)
		var result: Dictionary = {"seed":seed_value,"defense":defended.run.journey_response.defense.outcomes.route_1.duplicate(),"withdrawal":recalled.run.journey_response.defense.outcomes.route_1.duplicate()}
		for item: Array in [["defended",defended],["withdrawn",recalled],["untreated",untreated]]:
			var game: SimulationController = item[1]
			var route: TrailRouteState = game.run.trails.routes.route_1
			var kills: int = game.run.predator.kills_total
			var cargo: float = route.delivered_total
			if not game.set_trail_workers("route_1",5): failed = true
			game.advance(180)
			result[item[0]] = {"travel_losses":game.run.predator.kills_total - kills,"net_cargo":route.delivered_total - cargo,"rival_workers":game.run.rival.workers.count("rival:trail")}
		if result.defense.outcome != "secured" or result.defended.travel_losses != 0 or result.defended.net_cargo <= 0 or result.untreated.travel_losses == 0 or result.withdrawn.travel_losses == 0: failed = true
		records.append(result)
	print("[DEFENSE-EVALUATION] ",JSON.stringify(records)," failed=",failed)
	var file: FileAccess = FileAccess.open("res://.godot/card084_evidence.json",FileAccess.WRITE)
	if file == null: failed = true
	else: file.store_string(JSON.stringify(records,"\t")); file.close()
	quit(1 if failed else 0)
