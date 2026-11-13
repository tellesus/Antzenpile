extends "res://tests/evaluate_collective_exploration.gd"
## Developer measurement; inherited returned-evidence policy, no resource injections.
func _run():
	var rows: Array[Dictionary] = []
	for seed_value: int in [482817, 591, 202603]:
		for cleanup: bool in [false, true]:
			var game := Controller.new(seed_value)
			game.set_exploration(5)
			var row: Dictionary = {"seed": seed_value, "cleanup": cleanup, "revealed_at": -1.0,
				"build_started_at": -1.0, "developed_at": -1.0, "peak_burden": 0.0,
				"strained_seconds": 0.0, "save_exact": false}
			while game.run.simulation_time < 2400:
				var pile: PileState = game.run.colony.piles.home
				if game.run.clock.tick_count % 20 == 0:
					_policy(game, "standing_trunks", row)
					if cleanup and pile.midden.revealed:
						game.set_sanitation_workers("home", 1 if pile.midden.state == "developed" else 2)
						if game.start_midden("home"):
							row.build_started_at = game.run.simulation_time
				game.advance(0.25)
				row.peak_burden = maxf(row.peak_burden, pile.midden.burden_units / 100000.0)
				row.strained_seconds += 0.25 if pile.midden.larval_rate() < 1.0 else 0.0
				if pile.midden.revealed and row.revealed_at < 0:
					row.revealed_at = game.run.simulation_time
				if pile.midden.state == "developed" and row.developed_at < 0:
					row.developed_at = game.run.simulation_time
				assert(pile.workers.invariant_holds() and pile.midden.generated_units == pile.midden.isolated_units + pile.midden.burden_units)
				if game.run.simulation_time == 1200:
					var copy := Controller.new()
					var restored: bool = copy.restore_snapshot(Snapshot.new().snapshot(game))
					assert(restored)
					copy.advance(4)
					game.advance(4)
					row.save_exact = copy.run.to_dict() == game.run.to_dict()
					assert(row.save_exact)
			var pile: PileState = game.run.colony.piles.home
			row["workers"] = pile.workers_total
			row["brood_emerged"] = pile.brood_matured_total
			row["stores"] = pile.resources.duplicate()
			row["burden"] = pile.midden.burden_units / 100000.0
			row["isolated"] = pile.midden.isolated_units / 100000.0
			row["cleaners"] = pile.midden.cleaners
			row["state"] = pile.midden.state
			if cleanup:
				assert(row.developed_at >= 0 and pile.brood_matured_total > 8)
			rows.append(row)
	var evidence: Dictionary = {"engine": Engine.get_version_info().string, "platform": OS.get_name(),
		"duration_seconds": 2400, "policy": "Five standing scouts, one route per returned basic resource, returned-positive rechecks; real stores pay Food Exchange, Nursery, brood and Midden. Compare no cleanup with two basic cleaners, then one developed cleaner. No injected food, workers, knowledge or danger suppression.", "rows": rows}
	var output := FileAccess.open("res://docs/evidence/card064_sanitation.json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(evidence, "\t", true, true))
	print("[SANITATION-EVALUATION] ", JSON.stringify(rows))
	quit()
