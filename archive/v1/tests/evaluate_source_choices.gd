extends "res://tests/evaluate_collective_exploration.gd"
func _run():
	var rows: Array[Dictionary] = []
	for seed_value: int in [482817, 591, 202603]:
		for aware: bool in [false, true]:
			var game := Controller.new(seed_value)
			game.set_exploration(5)
			var row: Dictionary = {"seed": seed_value, "alternatives": aware, "lowest_carbohydrate": 10.0, "save_exact": false}
			while game.run.simulation_time < 2400:
				var pile: PileState = game.run.colony.piles.home
				if game.run.clock.tick_count % 20 == 0:
					if aware:
						_choices(game)
					else:
						_policy(game, "standing_trunks", row)
					if pile.midden.revealed:
						game.set_sanitation_workers("home", 1 if pile.midden.state == "developed" else 2)
						game.start_midden("home")
				game.advance(0.25)
				row.lowest_carbohydrate = minf(row.lowest_carbohydrate, pile.resources.carbohydrate)
				assert(pile.workers.invariant_holds())
				if game.run.simulation_time == 1200:
					var copy := Controller.new()
					var restored: bool = copy.restore_snapshot(Snapshot.new().snapshot(game))
					assert(restored)
					copy.advance(4)
					game.advance(4)
					row.save_exact = copy.run.to_dict() == game.run.to_dict()
					if not row.save_exact:
						FileAccess.open("res://.godot/sources_live.json", FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(), "\t", true, true))
						FileAccess.open("res://.godot/sources_copy.json", FileAccess.WRITE).store_string(JSON.stringify(copy.run.to_dict(), "\t", true, true))
						printerr("Source policy continuation mismatch: ", seed_value, " alternatives=", aware)
						quit(1)
						return
			var pile: PileState = game.run.colony.piles.home
			row["stores"] = pile.resources.duplicate()
			row["workers"] = pile.workers_total
			row["adult_losses"] = pile.workers.lost_total
			row["brood_emerged"] = pile.brood_matured_total
			row["routes"] = game.run.trails.routes.size()
			row["protection"] = game.run.honeydew.protection_workers
			rows.append(row)
	var file := FileAccess.open("res://docs/evidence/card065_sources.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"duration_seconds": 2400, "engine": Engine.get_version_info().string,
		"platform": OS.get_name(), "policy": "Ordinary stores/scouts; fixed initial source versus returned-known alternatives. Alternative policy stops reported empty nonrecurring food and foreign routes, funds known food sources with four home carers reserved, tends harvested honeydew, and deliberately sustains its reported risky traffic up to ten gatherers. Both fund chambers/brood/sanitation from real stores. No hidden source decisions or rate changes.", "rows": rows}, "\t", true, true))
	print("[SOURCE-CHOICES] ", JSON.stringify(rows))
	quit()

func _choices(game: SimulationController) -> void:
	var pile: PileState = game.run.colony.piles.home
	game.start_food_exchange("home")
	game.start_nursery_development("home")
	game.start_brood("home")
	var used: Array[String] = []
	for route: TrailRouteState in game.run.trails.routes.values():
		var kind: String = game.run.knowledge.nodes[route.destination_knowledge_id].definition_id
		var hint: Dictionary = game.run.knowledge.temporal_hint(route.destination_knowledge_id)
		if route.foreign_reports > 0:
			game.set_trail_workers(route.id, 0)
			continue
		if route.reported_depleted:
			game.set_investigation_priority(route.destination_knowledge_id, true)
			if kind == "carbohydrate" and not hint.possible_recurrence:
				game.set_trail_workers(route.id, 0)
			else:
				game.trails.set_recovery_watch(route.id, true)
		if route.desired_workers > 0:
			used.append(kind)
	var ids: Array = game.run.knowledge.nodes.keys()
	ids.sort()
	for id: String in ids:
		var kind: String = game.run.knowledge.nodes[id].definition_id
		if kind not in PileState.RESOURCE_IDS or kind != "carbohydrate" and kind in used:
			continue
		var route: TrailRouteState = game.run.trails.find_route("home", id)
		if route != null and (route.foreign_reports > 0 or route.reported_depleted and not game.run.knowledge.recovery_report(id, route.last_empty_report_at)):
			continue
		if game.run.knowledge.temporal_hint(id).last_return_empty:
			continue
		if pile.workers_available >= 9 and game.create_trail("home", id):
			used.append(kind)
	if game.run.honeydew.relationship == "exploited" and pile.workers_available >= 10:
		game.start_honeydew_tending("home")
	var honeydew: TrailRouteState = game.run.trails.find_route("home", "known:" + game.ecology.HONEYDEW.source_id)
	if honeydew != null and honeydew.status == "active" and game.run.honeydew.relationship == "tended":
		var needed: int = maxi(0, 10 - honeydew.allocated_workers)
		if pile.workers_available >= needed + 4:
			game.set_trail_workers(honeydew.id, 10)
