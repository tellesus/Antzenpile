extends SceneTree
## Developer evidence: ordinary stores/knowledge, identical returned-evidence policy.
const Controller = preload("res://src/core/simulation_controller.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const DURATION: float = 960.0
func _initialize():
	_run.call_deferred()
func _run():
	var rows: Array[Dictionary] = []
	for seed_value: int in [482817,591,202603]:
		for mode: String in ["manual", "standing", "standing_trunks"]:
			var row: Dictionary = _measure(seed_value, mode)
			if not row.save_exact:
				quit(1)
				return
			rows.append(row)
	var evidence: Dictionary = {"engine": Engine.get_version_info().string, "platform": OS.get_name(),
		"duration_seconds": DURATION, "policy": "Up to five scouts; one five-worker route per basic resource; recheck on new positive evidence; fund chamber/brood from real stores. No injected resources/knowledge.", "rows": rows}
	var output := FileAccess.open("res://docs/evidence/card062_exploration.json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(evidence, "\t", true, true))
	print("[EXPLORATION-EVALUATION] ", JSON.stringify(rows))
	quit()


func _measure(seed_value: int, mode: String) -> Dictionary:
	print("[MEASURE] ", seed_value, " ", mode)
	var game := Controller.new(seed_value)
	game.scouting.config = game.scouting.config.duplicate()
	if mode != "standing_trunks":
		game.scouting.config.trail_exploration_share = 0.0
	if mode != "manual":
		game.set_exploration(5)
	var row: Dictionary = {"seed": seed_value, "mode": mode, "first_water": -1.0, "first_emergence": -1.0,
		"trunk_missions": 0, "peak_detail": 0, "save_exact": false, "manual_launches": 0}
	var seen: Dictionary = {}
	var restore_checked: bool = false
	while game.run.simulation_time < DURATION:
		if game.run.clock.tick_count % 20 == 0:
			_policy(game, mode, row)
		game.advance(0.25)
		row.peak_detail = maxi(row.peak_detail, game.run.active_scout_count())
		for agent: ScoutAgent in game.run.scouts.values():
			if agent.id not in seen:
				seen[agent.id] = true
				row.trunk_missions += 1 if not agent.trunk_route_id.is_empty() else 0
		for known: KnownNode in game.run.knowledge.nodes.values():
			if known.definition_id == "water" and row.first_water < 0:
				row.first_water = known.first_delivered_at
		var pile: PileState = game.run.colony.piles.home
		if row.first_emergence < 0 and pile.workers_total > 40:
			row.first_emergence = game.run.simulation_time
		assert(pile.workers.invariant_holds() and game.run.active_scout_count() <= 8)
		if not restore_checked and game.run.simulation_time >= 480:
			var copy := Controller.new()
			assert(copy.restore_snapshot(Snapshot.new().snapshot(game)))
			copy.scouting.config = game.scouting.config.duplicate()
			copy.set_time_scale(16)
			copy.advance(0.5)
			copy.set_time_scale(1)
			game.advance(8)
			row.save_exact = copy.run.to_dict() == game.run.to_dict()
			if not row.save_exact:
				FileAccess.open("res://.godot/collective_live.json",FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(),"\t",true,true))
				FileAccess.open("res://.godot/collective_copy.json",FileAccess.WRITE).store_string(JSON.stringify(copy.run.to_dict(),"\t",true,true))
				push_error("Continuation mismatch: %d %s" % [seed_value,mode])
				quit(1)
				return row
			restore_checked = true
	row["known_sources"] = game.run.knowledge.nodes.size()
	row["standing_missions"] = 0 if mode == "manual" else seen.size()
	row["coverage_cells"] = game.run.exploration.coverage.size()
	row["workers"] = game.run.colony.piles.home.workers_total
	row["stores"] = game.run.colony.piles.home.resources.duplicate()
	row["nursery"] = game.run.colony.piles.home.nursery_state
	return row


func _policy(game: SimulationController, mode: String, row: Dictionary) -> void:
	if mode == "manual" and game.run.active_scout_count() < 5 and game.dispatch_scout("home"):
		row.manual_launches += 1
	var used: Array[String] = []
	for route: TrailRouteState in game.run.trails.routes.values():
		var resource: String = game.run.knowledge.nodes[route.destination_knowledge_id].definition_id
		used.append(resource)
		if route.reported_depleted:
			if mode != "manual":
				game.set_investigation_priority(route.destination_knowledge_id, true)
			if not game.run.knowledge.temporal_hint(route.destination_knowledge_id).last_return_empty:
				game.recheck_trail(route.id)
	var ids: Array = game.run.knowledge.nodes.keys()
	ids.sort()
	for id: String in ids:
		var resource: String = game.run.knowledge.nodes[id].definition_id
		if resource in PileState.RESOURCE_IDS and resource not in used and game.create_trail("home", id):
			used.append(resource)
	game.start_food_exchange("home")
	game.start_nursery_development("home")
	game.start_brood("home")
