extends SceneTree
const RootScript = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_scout_survival.gd")
var game_root: Node
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game_root = RootScript.new()
	get_root().add_child(game_root)
	var game: SimulationController = Fixture.fixture()
	Fixture.until_loss(game)
	game_root.simulation = game
	var agent: ScoutAgent = game.run.scouts.scout_1
	game.toggle_pause()
	var view: OutwardView = game_root._outward_view
	view.facing = PI / 4.0
	view.selected_id = "mission:scout_1"
	await _capture("awaiting")
	for kind: String in ["mouse", "touch"]:
		view._process(0)
		view._pointer_press(view._scout_recall_rect().get_center(), kind)
		view._pointer_release(view._scout_recall_rect().get_center(), kind)
		if view._feedback != "Return requested · await arrival" or not agent.lost: failures += 1
	game.toggle_pause()
	game.advance(agent.expected_tick * 0.25 - game.run.simulation_time)
	game.toggle_pause()
	view._feedback_until = 0
	await _capture("missing")
	view.exploration_open = true
	await _capture("attention")
	print("[SCOUT-SURVIVAL-UI] standard/compact waiting, missing and attention; actual recall mouse/touch; %d failures" % failures)
	game_root.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)


func _capture(label: String) -> void:
	var before: Dictionary = game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(900, 600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 8: await process_frame
		get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card097_%s_%d.png" % [label, size.x])
	if game_root.simulation.run.to_dict() != before: failures += 1

