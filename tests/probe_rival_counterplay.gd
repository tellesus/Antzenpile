extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_rival_counterplay.gd")
const Contact = preload("res://tests/test_rival_contact.gd")
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var game: SimulationController = Fixture.new().ready_game()
	for tick: int in 1600:
		game.advance(0.25)
		if game.run.trails.routes.route_1.conflict_report == "reinforced": break
	if game.run.trails.routes.route_1.conflict_report != "reinforced": failures += 1
	var saved: Dictionary = Contact.new().snapshot(game)
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		root.simulation.restore_snapshot(saved); root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("outward")
		var view: OutwardView = root._outward_view
		view.selected_id = "signal:known:carb_exposed"; view._process(0); view._run_command("journey_open")
		if not view._rival_attention(): failures += 1
		for state: String in ["pressure", "survey", "withdrawal"]:
			if state == "survey": view._run_command("journey_topic")
			if state == "withdrawal":
				view._run_command("journey_topic")
				var event: InputEvent = InputEventScreenTouch.new() if size.x == 900 else InputEventMouseButton.new()
				event.position = view._journey_rect("journey_defend").get_center(); event.pressed = true
				if size.x != 900: event.button_index = MOUSE_BUTTON_LEFT
				view._unhandled_input(event)
				if root.simulation.run.trails.routes.route_1.desired_workers != 0: failures += 1
			for frame: int in 8: await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("res://.godot/card122_%s_%d.png" % [state,size.x])
	print("[RIVAL-COUNTERPLAY] six captures; navigation/withdrawal failures=",failures)
	root.free(); await create_timer(0.3).timeout
	quit(1 if failures else 0)
