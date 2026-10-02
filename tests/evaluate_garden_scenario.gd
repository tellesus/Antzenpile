extends "res://tests/evaluate_source_choices.gd"

func _run():
	var rows: Array[Dictionary] = []
	for seed_value: int in [482817,591,202603]:
		var game := Controller.new(seed_value,"garden_edge")
		game.set_exploration(5)
		var row: Dictionary = {"seed":seed_value,"save_exact":false,"first_food":-1.0,"first_water":-1.0}
		while game.run.simulation_time < 2400:
			var pile: PileState = game.run.colony.piles.home
			if game.run.clock.tick_count % 20 == 0:
				_choices(game)
				if pile.midden.revealed:
					game.set_sanitation_workers("home",1 if pile.midden.state == "developed" else 2)
					game.start_midden("home")
				if pile.nursery_state == "developed" and pile.humidity.carers == 0 and pile.workers_available >= 5: game.set_humidity_workers("home",1)
			game.advance(0.25)
			for node: KnownNode in game.run.knowledge.nodes.values():
				var category: String = node.definition_id
				if category == "carbohydrate" and row.first_food < 0: row.first_food = game.run.simulation_time
				if category == "water" and row.first_water < 0: row.first_water = game.run.simulation_time
			if not pile.workers.invariant_holds():
				printerr("Garden worker conservation failed"); quit(1); return
			if game.run.simulation_time == 1200:
				var copy := Controller.new()
				if not copy.restore_snapshot(Snapshot.new().snapshot(game)):
					printerr("Garden restore failed"); quit(1); return
				copy.advance(4); game.advance(4)
				row.save_exact = copy.run.to_dict() == game.run.to_dict()
				if not row.save_exact:
					printerr("Garden continuation failed"); quit(1); return
		var pile: PileState = game.run.colony.piles.home
		row["workers"] = pile.workers_total
		row["brood_emerged"] = pile.brood_matured_total
		row["adult_losses"] = pile.workers.lost_total
		row["stores"] = pile.resources.duplicate()
		row["nursery"] = pile.nursery_state
		row["climate_carers"] = pile.humidity.carers
		row["known_sources"] = game.run.knowledge.nodes.size()
		rows.append(row)
	var output := FileAccess.open("res://docs/evidence/card071_garden.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"platform":OS.get_name(),"duration_seconds":2400,
		"policy":"Unfunded returned-source alternatives from 065, real Nursery/brood/sanitation/climate costs, no injected knowledge/resources or suppressed threat deaths. Authored positions vary; rates unchanged.","rows":rows},"\t",true,true))
	print("[GARDEN-EVALUATION] ",JSON.stringify(rows))
	quit()
