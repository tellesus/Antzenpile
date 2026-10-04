extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		var game: SimulationController = Defense.new().ready_game()
		if not root.simulation.restore_snapshot(Defense.new().snapshot(game)): failures += 1
		root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("outward")
		var view: OutwardView = root._outward_view
		view.selected_id = "threat:route_1"; view._process(0)
		for frame: int in 8: await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://.godot/card124_ready_%d.png" % size.x)
		var event: InputEvent = InputEventScreenTouch.new() if size.x == 900 else InputEventMouseButton.new()
		event.position = view._force_rect(16).get_center(); event.pressed = true
		if event is InputEventMouseButton: event.button_index = MOUSE_BUTTON_LEFT
		view._unhandled_input(event)
		if root.simulation.run.journey_response.defense.sent != 16: failures += 1
		view._process(0)
		for frame: int in 8: await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://.godot/card124_committed_%d.png" % size.x)
	print("[MANAGEMENT] four captures; actual force controls failures=", failures)
	root.free(); await create_timer(0.3).timeout; quit(1 if failures else 0)
