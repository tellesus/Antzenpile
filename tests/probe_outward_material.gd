extends "res://tests/probe_sensory_art.gd"
## Actual gestures/known-only smoke/local Home/rain; no gameplay fixture mutation.

func _run() -> void:
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var before: Dictionary = game_root.simulation.run.to_dict()
	var view: OutwardView = game_root._outward_view
	DisplayServer.window_set_size(Vector2i(1280,720))
	await _capture("card096_quiet")
	if not view._placed.is_empty(): failed = true
	_fixture()
	var local: Dictionary = view.status_provider.call()
	local.paused = true
	view.status_provider = func() -> Dictionary: return local
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 30: await process_frame
		var target: Dictionary = view._placed[1]
		view.selected_id = ""
		for pressed: bool in [true,false]:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = pressed
			mouse.position = target.center
			view._unhandled_input(mouse)
		if view.selected_id != target.id: failed = true
		view.selected_id = ""
		for pressed: bool in [true,false]:
			var touch := InputEventScreenTouch.new()
			touch.pressed = pressed
			touch.position = target.center
			view._unhandled_input(touch)
		if view.selected_id != target.id: failed = true
		await _capture("card096_selected_%d" % size.x)
		view.selected_id = ""
	DisplayServer.window_set_size(Vector2i(1280,720))
	local.rain_phase = "raining"
	await _capture("card096_rain")
	var animation_time: float = view._animation_time
	await create_timer(0.6).timeout
	if view._animation_time != animation_time: failed = true
	if before != game_root.simulation.run.to_dict(): failed = true
	print("[OUTWARD-MATERIAL] input_pause_unknown_snapshot=%s" % not failed)
	game_root.free()
	quit(1 if failed else 0)
