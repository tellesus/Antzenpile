extends "res://tests/evaluate_brood_health.gd"
## Same paid gathering/preventive sanitation; split ordinary colonies before a real front.
func _run() -> void:
	var rows: Array[Dictionary] = []
	var failures: int = 0
	for scenario: String in ["backyard_slice", "garden_edge"]:
		var prepared := Controller.new(482817, scenario)
		prepared.set_exploration(5)
		var setup: Dictionary = {"cleanup_at": -1.0}
		while prepared.run.simulation_time < 3500:
			if prepared.run.clock.tick_count % 20 == 0: _health_policy(prepared, "prevention", setup)
			prepared.advance(0.25)
		var saved: Dictionary = Snapshot.new().snapshot(prepared)
		for effort: int in [0, 1, 4]:
			var game := Controller.new()
			if not game.restore_snapshot(saved): failures += 1; break
			var row: Dictionary = {"scenario":scenario, "seed":482817, "response_workers":effort, "response_at":-1.0, "warm_seconds":0.0, "hot_seconds":0.0, "cooling_water":0.0, "save_exact":true}
			game.set_humidity_workers("home",0)
			while game.run.simulation_time < 4400:
				if game.run.clock.tick_count % 20 == 0: _thermal_policy(game, effort, row)
				game.advance(0.25)
				var pile: PileState = game.run.colony.piles.home
				var condition: String = game.heat.summary("home").condition
				row.warm_seconds += 0.25 if condition == "warm" else 0.0
				row.hot_seconds += 0.25 if condition == "hot" else 0.0
				if condition == "warm" and row.response_at < 0:
					FileAccess.open("res://.godot/card100_%s_%d_warm.json" % [scenario, effort], FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(), "", true, true))
				if condition == "hot": FileAccess.open("res://.godot/card100_%s_%d_hot.json" % [scenario, effort], FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(), "", true, true))
				if not pile.workers.invariant_holds() or pile.resources.values().any(func(value): return value < 0): failures += 1; break
				if game.run.clock.tick_count == 15600:
					var copy := Controller.new()
					if not copy.restore_snapshot(Snapshot.new().snapshot(game)): failures += 1; row.save_exact = false; break
					for tick: int in 40:
						if game.run.clock.tick_count % 20 == 0:
							_thermal_policy(game, effort, row)
							_thermal_policy(copy, effort, row.duplicate(true))
						game.advance(0.25); copy.advance(0.25)
					if game.run.to_dict() != copy.run.to_dict(): failures += 1; row.save_exact = false; break
			var pile: PileState = game.run.colony.piles.home
			row.cooling_water = pile.temperature.water_used_units / 100000.0
			row.final = {"thermal": game.heat.summary("home"), "workers":pile.workers_total, "carers":pile.humidity.carers, "water":pile.resources.water, "nursery":pile.nursery_state, "emerged":pile.brood_matured_total, "known_sources":game.run.knowledge.nodes.size()}
			rows.append(row)
			print("[NURSERY-HEAT] ",JSON.stringify(row))
	FileAccess.open("res://.godot/card100_heat.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"platform":OS.get_name(),"policy":"Ordinary card099 returned-gathering/preventive sanitation setup through 3500s, split into zero/one/four shared climate workers. Turn climate off before front; assign selected effort at observed warm Nursery, retain ordinary gathering/cleanup/guest responses. Existing rain stays active. No injected stores, temperature or paid jobs. Midfront command/save continuation checked.","failures":failures,"rows":rows},"\t",true,true))
	quit(1 if failures else 0)

func _thermal_policy(game: SimulationController, effort: int, row: Dictionary) -> void:
	_policy(game, "standing_trunks", row)
	if game.run.guest.reported_losses > 0 and game.run.guest.phase == "tolerated": game.start_guest_rejection()
	var pile: PileState = game.run.colony.piles.home
	if pile.midden.revealed:
		game.set_sanitation_workers("home", 1 if pile.midden.state == "developed" else 2)
		if pile.midden.state == "primitive": game.start_midden("home")
	var condition: String = game.heat.summary("home").condition
	if row.response_at >= 0 or condition != "steady":
		if game.set_humidity_workers("home", effort) and row.response_at < 0: row.response_at = game.run.simulation_time
	else:
		game.set_humidity_workers("home",0)
