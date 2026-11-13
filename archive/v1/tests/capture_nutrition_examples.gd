extends "res://tests/evaluate_nursery_expansion.gd"
const Pressure = preload("res://src/presentation/colony_pressure.gd")
func _run():
	var rows: Array[Dictionary] = []
	for scenario: String in ["backyard_slice", "garden_edge"]:
		var root := Root.new()
		root.simulation = Controller.new(482817, scenario)
		root.set_exploration(5)
		var row: Dictionary = {"expand_enabled": true, "events": []}
		while root.simulation.run.simulation_time < 3600 and Pressure.food_shortages(root.inward_status("home")).is_empty():
			if root.simulation.run.clock.tick_count % 20 == 0: policy(root,row)
			root.simulation.advance(0.25)
		var summary: Dictionary = root.inward_status("home")
		if Pressure.food_shortages(summary).is_empty(): failed = true
		var path: String = "res://.godot/card078_%s_nutrition.json" % scenario
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(root.simulation.run.to_dict(), "", true, true))
		rows.append({"scenario": scenario, "seed": 482817, "time": summary.time, "missing": Pressure.food_shortages(summary),
			"stores": summary.resources, "cohorts": summary.brood.size(), "capacity": summary.nursery_brood_capacity,
			"workers_conserved": root.simulation.run.colony.piles.home.workers.invariant_holds()})
		root.free()
	FileAccess.open("res://docs/evidence/card078_nutrition.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"policy":"Same paid expanded-colony command policy as 077; stop at first actual nutrient shortage. No injected food/knowledge or suppressed danger.","rows":rows},"\t",true,true))
	print("[NUTRITION-EXAMPLES] ", JSON.stringify(rows))
	quit(1 if failed else 0)
