extends SceneTree
## Ordinary unfunded exploration plus explicitly labeled hazard-removal counterfactuals.
const Controller = preload("res://src/core/simulation_controller.gd")
var rows: Array[Dictionary] = []
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for seed_value: int in [482817, 104729, 8675309]:
			for policy: String in ["general", "respond_to_absence", "cleared_counterfactual"]:
				_trial(scenario, seed_value, policy)
	var file := FileAccess.open("res://.godot/card097_exploration.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "failures": failures}, "\t"))
	print("[SCOUT-SURVIVAL] %d unfunded/counterfactual trials, %d failures" % [rows.size(), failures])
	quit(1 if failures else 0)


func _trial(scenario: String, seed_value: int, policy: String) -> void:
	var game := Controller.new(seed_value, scenario)
	game.advance(300.0)
	if policy == "cleared_counterfactual":
		# A physical no-ambusher comparison, not a claimed funded intervention.
		game.run.predator.resistance = 0
		game.run.predator.defeated_at = 300.0
	game.set_exploration(5)
	var first_missing: float = -1
	var source_times: Dictionary = {}
	var midpoint: Dictionary
	var copy := Controller.new()
	for tick: int in 6000:
		game.advance(0.25)
		for known: KnownNode in game.run.knowledge.nodes.values():
			if not source_times.has(known.definition_id): source_times[known.definition_id] = game.run.simulation_time
		if first_missing < 0 and game.run.missing_scouts("home") > 0:
			first_missing = game.run.simulation_time
			if policy == "respond_to_absence":
				game.set_exploration(2)
				game.set_exploration_bias(PI)
		if tick == 2999:
			midpoint = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
			if not copy.restore_snapshot(midpoint):
				failures += 1
		elif tick > 2999:
			copy.advance(0.25)
			if copy.run.exploration.target != game.run.exploration.target:
				copy.set_exploration(game.run.exploration.target)
				copy.set_exploration_bias(game.run.exploration.bias)
		if not game.run.colony.piles.home.workers.invariant_holds(): failures += 1
	if game.run.to_dict() != copy.run.to_dict(): failures += 1
	var row: Dictionary = {"scenario": scenario, "seed": seed_value, "policy": policy,
		"first_resource_times": source_times, "first_missing_at": first_missing,
		"physical_scout_losses": game.run.scout_losses.get("home", 0),
		"known_missing": game.run.missing_scouts("home"), "away": game.run.scouts.size(),
		"workers": game.run.colony.piles.home.workers_total, "known_sources": game.run.knowledge.nodes.size(),
		"exact_saved_continuation": game.run.to_dict() == copy.run.to_dict()}
	rows.append(row)
	print(row)
