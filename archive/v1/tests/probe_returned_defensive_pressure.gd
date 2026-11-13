extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_ambusher_defense.gd")
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	var game: SimulationController = Fixture.new().ready_game()
	game.journey_response.defend("route_1")
	while game.run.journey_response.pressure.reports.is_empty(): game.advance(0.25)
	var saved: Dictionary = Fixture.new().snapshot(game)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		root.simulation.restore_snapshot(saved); root.simulation.toggle_pause(); root._refresh_loaded_views()
		root.set_mode("outward")
		var view: OutwardView = root._outward_view
		view.selected_id = "signal:"+root.trail_summaries("home")[0].destination_knowledge_id
		view.journey_open = true
		for state: String in ["returned", "pending", "settled"]:
			for frame: int in 8: await process_frame
			if state == "pending":
				var event: InputEvent = InputEventScreenTouch.new() if size.x == 900 else InputEventMouseButton.new()
				event.position = view._journey_rect("journey_defend").get_center(); event.pressed = true
				if size.x != 900: event.button_index = MOUSE_BUTTON_LEFT
				view._unhandled_input(event)
				if not root.simulation.run.journey_response.defense.sent == 16: failures += 1
			if state == "settled":
				root.simulation.toggle_pause()
				while root.simulation.run.journey_response.active(): root.simulation.advance(0.25)
				root.simulation.toggle_pause()
			for frame: int in 8: await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("res://.godot/card121_%s_%d.png" % [state,size.x])
	print("[RETURNED-PRESSURE] six captures; mouse/touch reinforcement failures=",failures)
	root.free(); await create_timer(0.3).timeout
	quit(1 if failures else 0)
