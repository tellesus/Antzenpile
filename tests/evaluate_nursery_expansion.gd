extends "res://tests/evaluate_expanded_colony.gd"
## Paid paired trials; same returned-evidence policy with/without one expansion.

func _run():
	var rows: Array[Dictionary] = []
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for seed_value: int in [482817, 591]:
			for expanding: bool in [false, true]:
				var root := Root.new()
				root.simulation = Controller.new(seed_value, scenario)
				root.set_exploration(5)
				var row: Dictionary = {"scenario": scenario, "seed": seed_value, "expand_enabled": expanding, "events": [], "captures": {}, "save_exact": false, "food_short_seconds": 0.0}
				while root.simulation.run.simulation_time < 3600:
					if root.simulation.run.clock.tick_count % 20 == 0:
						var summary: Dictionary = root.inward_status("home")
						if summary.brood.any(func(cohort): return cohort.nutrition < 1.0): row.food_short_seconds += 5.0
						if expanding:
							if summary.nursery_expansion.state == "available": _save_phase(root, row, "available")
							if summary.nursery_expansion.state == "developing": _save_phase(root, row, "building")
							if summary.brood.size() == 4: _save_phase(root, row, "four_cohorts")
						policy(root, row)
					root.simulation.advance(0.25)
					var pile: PileState = root.simulation.run.colony.piles.home
					if not pile.workers.invariant_holds() or pile.resources.values().any(func(value): return value < 0):
						printerr("Expansion conservation failed"); failed = true; break
					if root.simulation.run.simulation_time == 1200:
						var copy := Root.new()
						copy.simulation = Controller.new()
						if not copy.simulation.restore_snapshot(Snapshot.new().snapshot(root.simulation)):
							printerr("Expansion ordinary restore failed"); failed = true; copy.free(); break
						for tick: int in 240:
							if root.simulation.run.clock.tick_count % 20 == 0:
								policy(root, row)
								policy(copy, {"events": [], "expand_enabled": expanding})
							root.simulation.advance(0.25); copy.simulation.advance(0.25)
						row.save_exact = root.simulation.run.to_dict() == copy.simulation.run.to_dict()
						copy.free()
						if not row.save_exact: failed = true; break
				var summary: Dictionary = root.inward_status("home")
				row["final"] = {"workers": summary.workers_total, "emerged": summary.brood_matured_total,
					"stores": summary.resources, "brood_capacity": summary.nursery_brood_capacity, "cohorts": summary.brood.size(),
					"expansion": summary.nursery_expansion.state, "returned_losses": root.returned_losses("home"),
					"cleaners": summary.midden.cleaners, "climate_carers": summary.humidity.carers}
				if expanding and summary.nursery_expansion.state != "developed": failed = true
				rows.append(row)
				print("[NURSERY-EXPANSION] ", scenario, " seed=", seed_value, " expand=", expanding, " ", JSON.stringify(row.final), " exact=",row.save_exact)
				root.free()
	var file := FileAccess.open("res://docs/evidence/card077_expansion.json", FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "platform": OS.get_name(), "duration_seconds": 3600,
		"policy": "075 detached-evidence paid-growth/source/pressure policy, paired with/without the revealed Nursery expansion. No resource/knowledge injection or suppressed threats. Food-short time is five-second sampling excluding the 60-second continuation branch.", "rows": rows}, "\t", true, true))
	quit(1 if failed else 0)

func policy(root: Node, row: Dictionary) -> void:
	super.policy(root, row)
	if row.get("expand_enabled", false) and root.inward_status("home").nursery_expansion.state == "available":
		_event(root, row, "expand Nursery", root.start_nursery_expansion())

func _save_phase(root: Node, row: Dictionary, phase: String) -> void:
	if row.captures.has(phase): return
	var path: String = "res://.godot/card077_%s_%d_%s.json" % [row.scenario, row.seed, phase]
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(root.simulation.run.to_dict(), "", true, true))
	row.captures[phase] = root.inward_status("home").time
