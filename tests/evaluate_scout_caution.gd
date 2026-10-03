extends SceneTree
const Controller = preload("res://src/core/simulation_controller.gd")
var baseline: Script
var rows: Array[Dictionary] = []
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ResourceLoader.exists(args[0]):
		printerr("Provide the previous card's ScoutSystem script as one res:// user argument")
		quit(1)
		return
	baseline = load(args[0])
	for seed_value: int in [3043, 104729, 8675309]:
		var prepared: SimulationController = load("res://tests/test_predator.gd").new()._fixture(seed_value)
		for tick: int in 1200:
			prepared.advance(0.25)
			if prepared.run.trails.routes.route_1.reported_losses > 0: break
		prepared.set_trail_workers("route_1", 0)
		prepared.advance(100.0)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(prepared.run.to_dict(), "", true, true))
		for policy: String in ["previous_card", "learned_caution"]:
			_trial(seed_value, policy, saved)
	var file := FileAccess.open("res://.godot/card098_caution.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "failures": failures}, "\t"))
	print("[SCOUT-CAUTION] %d paired trials, %d failures" % [rows.size(), failures])
	quit(1 if failures else 0)


func _trial(seed_value: int, policy: String, saved: Dictionary) -> void:
	var game := Controller.new()
	if not game.restore_snapshot(saved): failures += 1; return
	if policy == "previous_card": game.scouting = baseline.new(game.run)
	var start_losses: int = game.run.scout_losses.get("home", 0)
	var start: float = game.run.simulation_time
	game.set_exploration(5)
	var copy := Controller.new()
	for tick: int in 6000:
		game.advance(0.25)
		if tick == 2999:
			if not copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))): failures += 1
			if policy == "previous_card": copy.scouting = baseline.new(copy.run)
		elif tick > 2999:
			copy.advance(0.25)
		if not game.run.colony.piles.home.workers.invariant_holds(): failures += 1
	var exact: bool = game.run.to_dict() == copy.run.to_dict()
	if not exact: failures += 1
	var types: Array[String] = []
	for known: KnownNode in game.run.knowledge.nodes.values():
		if known.definition_id not in types: types.append(known.definition_id)
	types.sort()
	var row: Dictionary = {"seed": seed_value, "policy": policy, "start_at": start,
		"scout_losses": game.run.scout_losses.get("home", 0) - start_losses,
		"known_sources": game.run.knowledge.nodes.size(), "resource_types": types, "exact_saved_continuation": exact}
	rows.append(row)
	print(row)
