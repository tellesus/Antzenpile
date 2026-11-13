extends "res://tests/evaluate_source_choices.gd"
func _run():
	var rows: Array[Dictionary] = []
	for seed_value: int in [482817, 591, 202603]:
		for climate: bool in [false, true]:
			var game := Controller.new(seed_value)
			game.set_exploration(5)
			var row: Dictionary = {"seed": seed_value, "climate_care": climate, "strained_seconds": 0.0, "save_exact": false}
			while game.run.simulation_time < 2400:
				var pile: PileState = game.run.colony.piles.home
				if game.run.clock.tick_count % 20 == 0:
					_choices(game)
					if pile.midden.revealed:
						game.set_sanitation_workers("home", 1 if pile.midden.state == "developed" else 2)
						game.start_midden("home")
					if climate and pile.nursery_state == "developed" and pile.humidity.carers == 0 and pile.workers_available >= 5:
						game.set_humidity_workers("home", 1)
				game.advance(0.25)
				row.strained_seconds += 0.25 if pile.humidity.larval_rate() < 1.0 else 0
				assert(pile.workers.invariant_holds() and pile.resources.water >= 0)
				if game.run.simulation_time == 1200:
					var copy := Controller.new()
					var restored: bool = copy.restore_snapshot(Snapshot.new().snapshot(game))
					assert(restored)
					copy.advance(4)
					game.advance(4)
					row.save_exact = copy.run.to_dict() == game.run.to_dict()
					if not row.save_exact:
						printerr("Humidity continuation mismatch: ", seed_value)
						quit(1)
						return
			var pile: PileState = game.run.colony.piles.home
			row["moisture"] = pile.humidity.moisture / 10000.0
			row["climate_workers"] = pile.humidity.carers
			row["climate_water_used"] = pile.humidity.water_used_units / 100000.0
			row["workers"] = pile.workers_total
			row["brood_emerged"] = pile.brood_matured_total
			row["adult_losses"] = pile.workers.lost_total
			row["stores"] = pile.resources.duplicate()
			if climate:
				assert(pile.humidity.carers == 1 and pile.humidity.larval_rate() == 1 and pile.brood_matured_total > 8)
			rows.append(row)
	var output := FileAccess.open("res://docs/evidence/card066_humidity.json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "platform": OS.get_name(),
		"duration_seconds": 2400, "policy": "Same unfunded returned-source-choice policy as 065 with real nursery/brood/sanitation costs, compare zero climate workers with one developed-Nursery carer when five workers remain available. No injected knowledge/resources or suppressed deaths.", "rows": rows}, "\t", true, true))
	print("[HUMIDITY-EVALUATION] ", JSON.stringify(rows))
	quit()
