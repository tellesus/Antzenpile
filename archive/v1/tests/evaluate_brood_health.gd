extends "res://tests/evaluate_collective_exploration.gd"
## Ordinary returned-evidence gathering; no injected health, stores or suppressed hazards.
func _run() -> void:
	var rows: Array[Dictionary] = []
	var failures: int = 0
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for seed_value: int in [482817, 591]:
			for response: String in ["neglect", "symptoms", "prevention"]:
				var game := Controller.new(seed_value, scenario)
				game.set_exploration(5)
				var row: Dictionary = {"scenario": scenario, "seed": seed_value, "response": response, "first_symptoms": -1.0, "first_health_loss": -1.0, "cleanup_at": -1.0, "peak_burden": 0, "save_exact": true}
				while game.run.simulation_time < 7200:
					var pile: PileState = game.run.colony.piles.home
					if game.run.clock.tick_count % 20 == 0: _health_policy(game, response, row)
					game.advance(0.25)
					var health: Dictionary = game.brood_health.summary("home")
					row.peak_burden = maxi(row.peak_burden, pile.brood_health.burden)
					if health.condition != "stable" and row.first_symptoms < 0:
						row.first_symptoms = game.run.simulation_time
						FileAccess.open("res://.godot/card099_%s_%d_%s_symptoms.json" % [scenario, seed_value, response], FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(), "", true, true))
					if health.losses > 0 and row.first_health_loss < 0: row.first_health_loss = game.run.simulation_time
					if not pile.workers.invariant_holds() or pile.brood_lost_total != pile.brood_health.losses + game.run.guest.reported_losses: failures += 1; break
					if game.run.clock.tick_count % 4800 == 0:
						var copy := Controller.new()
						if not copy.restore_snapshot(Snapshot.new().snapshot(game)):
							print("[RESTORE-FAIL] ", scenario, " ", seed_value, " ", response, " ", game.run.simulation_time)
							FileAccess.open("res://.godot/card099_failed_restore.json", FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(), "", true, true))
							row.save_exact = false; failures += 1; break
						for tick: int in 40:
							if game.run.clock.tick_count % 20 == 0:
								_health_policy(game, response, row)
								_health_policy(copy, response, row.duplicate(true))
							game.advance(0.25); copy.advance(0.25)
						if game.run.to_dict() != copy.run.to_dict():
							print("[CONTINUATION-FAIL] ", scenario, " ", seed_value, " ", response, " ", game.run.simulation_time)
							FileAccess.open("res://.godot/card099_left.json", FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(), "", true, true))
							FileAccess.open("res://.godot/card099_right.json", FileAccess.WRITE).store_string(JSON.stringify(copy.run.to_dict(), "", true, true))
							row.save_exact = false; failures += 1; break
				var pile: PileState = game.run.colony.piles.home
				row.final = {"health": game.brood_health.summary("home"), "workers": pile.workers_total, "emerged": pile.brood_matured_total, "guest_losses": game.run.guest.reported_losses, "known_sources": game.run.knowledge.nodes.size(), "midden": pile.midden.state, "refuse": pile.midden.burden_units / 100000.0, "stores": pile.resources.duplicate()}
				FileAccess.open("res://.godot/card099_%s_%d_%s_final.json" % [scenario, seed_value, response], FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(), "", true, true))
				print("[BROOD-HEALTH] ", JSON.stringify(row))
				rows.append(row)
	FileAccess.open("res://.godot/card099_health.json", FileAccess.WRITE).store_string(JSON.stringify({"engine": Engine.get_version_info().string, "platform": OS.get_name(), "duration_seconds": 7200, "policy": "Five general scouts, returned basic-resource gathering/rechecks, paid chamber growth and repeated manual brood; guest rejection on observed losses. Compare no cleanup, five cleaners plus paid Midden on first symptoms, and two basic/one developed cleaner from need reveal. No injected state/resources or removed hazards. Truth only records invariants/evidence.", "failures": failures, "rows": rows}, "\t", true, true))
	quit(1 if failures else 0)

func _health_policy(game: SimulationController, response: String, row: Dictionary) -> void:
	_policy(game, "standing_trunks", row)
	var guest: GuestState = game.run.guest
	if guest.reported_losses > 0 and guest.phase == "tolerated": game.start_guest_rejection()
	var pile: PileState = game.run.colony.piles.home
	var health: Dictionary = game.brood_health.summary("home")
	if response == "prevention" and pile.midden.revealed or response == "symptoms" and (health.condition != "stable" or row.cleanup_at >= 0):
		if game.set_sanitation_workers("home", (1 if pile.midden.state == "developed" else 2) if response == "prevention" else 5) and row.cleanup_at < 0: row.cleanup_at = game.run.simulation_time
		if pile.midden.state == "primitive": game.start_midden("home")
	if pile.nursery_state == "developed" and pile.humidity.larval_rate() < 1.0: game.set_humidity_workers("home", 1)
