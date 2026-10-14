extends "res://tests/evaluate_nursery_heat.gd"
## Real authored front, saved ordinary colony, existing returned-source policy.
func _run() -> void:
	var rows: Array[Dictionary] = []
	var failures: int = 0
	for scenario: String in ["backyard_slice", "garden_edge"]:
		var game := Controller.new()
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card100_%s_4_warm.json" % scenario))
		if not game.restore_snapshot(source): failures += 1; continue
		var row: Dictionary = {"scenario":scenario,"seed":482817,"response_at":source.clock.time,"hot_dry_ticks":0,"pulses":[],"save_exact":true}
		for id: String in ["known:carb_sheltered", "known:aphid_01"]:
			if game.run.knowledge.nodes.has(id): game.create_trail("home", id)
		var recorder: Callable = func(id,amount): row.pulses.append({"at":game.run.simulation_time,"source":id,"amount":amount,"hot_dry":HeatSystem.hot_dry(game.run)})
		game.ecology.resource_pulsed.connect(recorder)
		var saved: Dictionary = Snapshot.new().snapshot(game)
		var copy := Controller.new()
		if not copy.restore_snapshot(saved): failures += 1; continue
		var end: float = 4350.0
		while game.run.simulation_time < end:
			if game.run.clock.tick_count % 20 == 0:
				_thermal_policy(game,1,row)
				_thermal_policy(copy,1,row.duplicate(true))
			row.hot_dry_ticks += 1 if HeatSystem.hot_dry(game.run) else 0
			game.advance(0.25); copy.advance(0.25)
			if game.run.to_dict() != copy.run.to_dict() or not game.run.colony.piles.home.workers.invariant_holds(): failures += 1; row.save_exact = false; break
		row.final = {"known_sources":game.run.knowledge.nodes.size(),"water_source":game.run.world.nodes.water_01.quantity,"home_water":game.run.colony.piles.home.resources.water,"air":game.heat.home_air(),"thermal":game.heat.summary("home")}
		print("[HOT-DRY-ECOLOGY] ",JSON.stringify(row))
		game.ecology.resource_pulsed.disconnect(recorder)
		rows.append(row)
	FileAccess.open("res://.godot/card101_ecology.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"platform":OS.get_name(),"policy":"Two previously ordinary paid card100 prefront/warm colonies, continued through the real front with one climate worker, actual paid gathering of both remembered alternative carbohydrate producers, existing rechecks/cleanup/guest response and actual rain. Physical pulse record is developer evidence, never UI data. Full per-tick JSON-restored continuation/conservation checked.","failures":failures,"rows":rows},"\t",true,true))
	quit(1 if failures else 0)
