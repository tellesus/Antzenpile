extends "res://tests/evaluate_nursery_expansion.gd"
## Same returned-evidence paid-growth policy, with one Grow intent and no repeat laying.
func _run():
	var rows: Array[Dictionary] = []
	for scenario: String in ["backyard_slice", "garden_edge"]:
		var root := Root.new()
		root.simulation = Controller.new(482817, scenario)
		root.set_exploration(5)
		root.set_brood_intent("grow")
		var row: Dictionary = {"scenario":scenario, "seed":482817, "standing_growth":true, "expand_enabled":true, "events":[], "captures":{}, "waits":{}, "save_exact":false}
		while root.simulation.run.simulation_time < 3600:
			if root.simulation.run.clock.tick_count % 20 == 0:
				policy(root,row)
				var summary: Dictionary = root.inward_status("home")
				var waiting: String = summary.brood_production.waiting
				row.waits[waiting] = row.waits.get(waiting,0) + 5
				if waiting not in row.captures:
					FileAccess.open("res://.godot/card079_%s_%s.json" % [scenario,waiting],FileAccess.WRITE).store_string(JSON.stringify(root.simulation.run.to_dict(),"",true,true))
					row.captures[waiting] = summary.time
			root.simulation.advance(0.25)
			var pile: PileState = root.simulation.run.colony.piles.home
			if not pile.workers.invariant_holds() or pile.resources.values().any(func(value): return value < 0): failed = true; break
			if root.simulation.run.simulation_time == 1200:
				var copy := Root.new(); copy.simulation = Controller.new()
				if not copy.simulation.restore_snapshot(Snapshot.new().snapshot(root.simulation)): failed = true; copy.free(); break
				for tick: int in 240:
					if root.simulation.run.clock.tick_count % 20 == 0:
						policy(root,row); policy(copy,{"standing_growth":true,"expand_enabled":true,"events":[]})
					root.simulation.advance(0.25); copy.simulation.advance(0.25)
				row.save_exact = root.simulation.run.to_dict() == copy.simulation.run.to_dict()
				copy.free()
				if not row.save_exact: failed = true; break
		var summary: Dictionary = root.inward_status("home")
		row.final = {"workers":summary.workers_total,"emerged":summary.brood_matured_total,"brood_lost":summary.brood_losses,"stores":summary.resources,"cohorts":summary.brood.size(),"expansion":summary.nursery_expansion.state,"brood_production":summary.brood_production,"traits":summary.genetic_repertoire}
		if summary.brood_matured_total <= 8 or row.events.any(func(event): return event.action == "lay brood"): failed = true
		FileAccess.open("res://.godot/card079_%s_final.json" % scenario,FileAccess.WRITE).store_string(JSON.stringify(root.simulation.run.to_dict(),"",true,true))
		print("[STANDING-BROOD] ", scenario, " ", JSON.stringify(row.final)," waits=",JSON.stringify(row.waits)," exact=",row.save_exact)
		rows.append(row); root.free()
	FileAccess.open("res://docs/evidence/card079_growth.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"policy":"075/077 returned-evidence paid-growth policy with Grow set once and manual lay calls removed. No food/knowledge injection or suppressed danger. Two original environments, seed 482817, 3600 simulated seconds. Wait durations sample every five seconds, excluding continuation branch.","rows":rows},"\t",true,true))
	quit(1 if failed else 0)
