extends SceneTree
## Selected-route visual probe while one cohort worker investigates nearby.

const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_trail_side_discovery.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := Fixture.new()
	var game: SimulationController
	for seed: int in 24:
		var candidate: SimulationController = fixture._fixture(seed + 1)
		candidate.advance(4.0)
		if candidate.run.trails.cohorts.cohort_1.detour != null:
			game = candidate
			break
	if game == null:
		printerr("Trail detour probe found no active detour")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(900, 600))
	var root := Root.new()
	get_root().add_child(root)
	root.simulation = game
	root._outward_view.speed_command = game.set_time_scale
	for signal_data: Dictionary in root.sensory_snapshot("home"):
		if signal_data.source_knowledge_id == "known:carb_exposed":
			root._outward_view.selected_id = signal_data.id
			break
	for frame: int in 30:
		await process_frame
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card038_trail_detour_900.png")
	print("[TRAIL DETOUR PROBE] checking=%d active_scouts=%d" % [root.trail_summaries("home")[0].checking_workers, game.run.active_scout_count()])
	root.free()
	await create_timer(0.2).timeout
	quit(0)
