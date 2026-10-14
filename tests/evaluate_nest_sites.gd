extends SceneTree
const Controller = preload("res://src/core/simulation_controller.gd")
var failed: bool = false
func _initialize() -> void: call_deferred("run_trials")
func policy(game: SimulationController) -> void:
	var used: Array[String] = []
	for route: TrailRouteState in game.run.trails.routes.values():
		used.append(game.run.knowledge.nodes[route.destination_knowledge_id].definition_id)
	var ids: Array = game.run.knowledge.nodes.keys(); ids.sort()
	for id: String in ids:
		var category: String = game.run.knowledge.nodes[id].definition_id
		if category not in PileState.RESOURCE_IDS or category in used: continue
		if game.create_trail("home",id): used.append(category)

func run_trials() -> void:
	var rows: Array[Dictionary] = []
	for scenario: String in ScenarioCatalog.IDS:
		for seed_value: int in [482817,591]:
			var game := Controller.new(seed_value,scenario)
			game.set_exploration(5)
			var copy: SimulationController = null
			var exact: bool = true
			var delivered_at: float = -1
			for tick: int in 14400:
				if tick % 40 == 0:
					policy(game)
					if copy != null: policy(copy)
				game.advance(0.25)
				if copy != null:
					copy.advance(0.25)
					exact = exact and game.run.to_dict() == copy.run.to_dict()
				if tick == 7199:
					copy = Controller.new()
					exact = exact and copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict())))
				if delivered_at < 0 and game.run.knowledge.nodes.has("known:nest_site_01"):
					delivered_at = game.run.simulation_time
			var kinds: Array[String] = []
			for node: KnownNode in game.run.knowledge.nodes.values():
				if node.definition_id not in kinds: kinds.append(node.definition_id)
			kinds.sort()
			var conserved: bool = game.run.colony.piles.home.workers.invariant_holds()
			var passed: bool = delivered_at >= 0 and exact and conserved and kinds == ["carbohydrate","nest_site","protein","water"]
			failed = failed or not passed
			var row: Dictionary = {"scenario":scenario,"seed":seed_value,"seconds":3600,"site_returned_at":delivered_at,"known_types":kinds,"known_nodes":game.run.knowledge.nodes.size(),"exact_saved_continuation":exact,"conserved":conserved,"passed":passed}
			rows.append(row); print("[NEST-SITE] ",row)
			if scenario == "backyard_slice" and seed_value == 482817:
				var file := FileAccess.open("res://.godot/card102_ordinary.json",FileAccess.WRITE)
				file.store_string(JSON.stringify(game.run.to_dict())); file.close()
	var file := FileAccess.open("res://.godot/card102_trials.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t")); file.close()
	quit(1 if failed else 0)
