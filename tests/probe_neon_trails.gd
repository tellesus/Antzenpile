extends "res://tests/probe_sensory_art.gd"
## Detached visual stress fixture plus an untouched real empty colony.
## Run graphically, not --headless; writes captures under .godot/card176/.

var output_dir: String = "res://.godot/card176"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Neon trail capture requires a rendering display.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var before: Dictionary = game_root.simulation.run.to_dict()
	var view: OutwardView = game_root._outward_view
	print("[NEON] engine=%s renderer=%s adapter=%s" % [Engine.get_version_info().string,
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), RenderingServer.get_video_adapter_name()])
	_resize(Vector2i(1920, 1080))
	await _capture("empty_1920")
	if not view._placed.is_empty(): failed = true
	_fixture()
	var status: Dictionary = view.status_provider.call()
	status.paused = true
	view.status_provider = func() -> Dictionary: return status
	view._animation_time = 11.0
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(900, 600)]:
		_resize(size)
		await _capture("mixed_%d" % size.x)
		var target: Dictionary = view._placed[1]
		for kind: String in ["mouse", "touch"]:
			view.selected_id = ""
			for pressed: bool in [true, false]:
				var event: InputEvent
				if kind == "mouse":
					event = InputEventMouseButton.new()
					event.button_index = MOUSE_BUTTON_LEFT
				else:
					event = InputEventScreenTouch.new()
				event.pressed = pressed
				event.position = target.center
				view._unhandled_input(event)
			if view.selected_id != target.id: failed = true
		await _capture("selected_%d" % size.x)
		view.selected_id = ""
	_resize(Vector2i(1920, 1080))
	status.rain_phase = "raining"
	await _capture("rain_1920")
	status.rain_phase = ""
	view.facing = PI - 0.03
	await _capture("rear_1920")
	if not view._placed.is_empty(): failed = true
	view.facing = 0.0
	view._animation_time = 12.0
	await _capture("motion_1920")
	var paused_time: float = view._animation_time
	for frame: int in 10: await process_frame
	if view._animation_time != paused_time: failed = true
	game_root.set_mode("inward")
	await _capture("inward_1920")
	if before != game_root.simulation.run.to_dict(): failed = true
	print("[NEON] mouse_touch_pause_empty_snapshot=%s" % not failed)
	await _returned_alarm()
	view.signal_provider = Callable()
	view.status_provider = Callable()
	game_root.free()
	# Drain pending draws and let the audio mixing thread release stopped streams.
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)


func _returned_alarm() -> void:
	# This second scene uses ordinary paid commands and actual returned knowledge.
	var game: SimulationController = game_root.simulation
	game.restore_snapshot(Controller.new(3043).run.to_dict())
	var view: OutwardView = game_root._outward_view
	view.signal_provider = game_root.focused_outward_signals
	view.status_provider = game_root.focused_outward_status
	game_root.set_mode("outward")
	if not game.dispatch_scout("home", PI / 4.0): failed = true
	for tick: int in 1000:
		if game.run.knowledge.nodes.has("known:aphid_01"): break
		game.advance(0.25)
	if not game.create_trail("home", "known:aphid_01"):
		failed = true
		return
	for tick: int in 1800:
		if game.run.trails.routes.route_1.reported_losses > 0: break
		game.advance(0.25)
	if game.run.trails.routes.route_1.reported_losses == 0: failed = true
	game.toggle_pause()
	var frozen: Dictionary = game.run.to_dict()
	view.selected_id = "signal:known:aphid_01"
	view.journey_open = true
	await _capture("returned_alarm_1920")
	if game.run.to_dict() != frozen: failed = true
	print("[NEON] real_returned_alarm=%s" % not failed)


func _resize(size: Vector2i) -> void:
	# Exercise each logical layout at its actual pixel size, without letterboxing.
	get_root().content_scale_size = size
	get_root().size = size


func _capture(label: String) -> void:
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_root().get_texture().get_image()
	if picture.get_size() != get_root().size:
		printerr("Capture resolution does not match requested window")
		failed = true
	if picture.save_png(output_dir.path_join(label + ".png")) != OK: failed = true
	print("[NEON] capture=%s size=%s" % [label, picture.get_size()])
