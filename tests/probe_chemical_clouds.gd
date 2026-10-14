extends "res://tests/probe_neon_trails.gd"
## Native renderer evidence, including real paid and returned survey boundaries.

const Survey = preload("res://tests/test_journey_investigation.gd")
const Roaming = preload("res://tests/test_roaming_predator.gd")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Chemical cloud capture requires a rendering display.")
		quit(1)
		return
	output_dir = "res://.godot/card179"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	var view: OutwardView = game_root._outward_view
	print("[CHEMISTRY] engine=%s renderer=%s adapter=%s" % [Engine.get_version_info().string,
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), RenderingServer.get_video_adapter_name()])
	_resize(Vector2i(1920, 1080))
	await _capture("empty_1920")
	if not view.chemical_field.clouds.is_empty(): failed = true
	_fixture()
	var signals: Array[Dictionary] = view.signal_provider.call()
	var status: Dictionary = view.status_provider.call()
	status.paused = true
	view.status_provider = func() -> Dictionary: return status
	view._animation_time = 11.0
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(900, 600)]:
		_resize(size)
		await _capture("clouds_%d" % size.x)
		var target: Dictionary = view._placed[1]
		for kind: String in ["mouse", "touch"]:
			view.selected_id = ""
			view._pointer_press(target.center, kind)
			view._pointer_release(target.center, kind)
			if view.selected_id != target.id: failed = true
		await _capture("selected_%d" % size.x)
		view.selected_id = ""
	_resize(Vector2i(1920, 1080))
	view._animation_time = 23.0
	await _capture("motion_1920")
	var paused: Image = get_root().get_texture().get_image()
	for frame: int in 12: await process_frame
	await RenderingServer.frame_post_draw
	if paused.get_data() != get_root().get_texture().get_image().get_data(): failed = true
	view.facing = PI - 0.03
	await _capture("rear_1920")
	if not view.chemical_field.clouds.is_empty(): failed = true
	view.facing = 0.0
	if frozen != game_root.simulation.run.to_dict(): failed = true
	print("[CHEMISTRY] detached_mouse_touch_pause_empty_snapshot=%s" % not failed)
	await _returned_predator()
	await _returned_beetle()
	view.signal_provider = Callable()
	view.status_provider = Callable()
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)


func _returned_predator() -> void:
	var game: SimulationController = Survey.new().investigated_game()
	var view: OutwardView = game_root._outward_view
	game_root.simulation = game
	view.signal_provider = game_root.focused_outward_signals
	view.status_provider = game_root.focused_outward_status
	view.selected_id = ""
	if not game.journey_response.investigate("route_1"): failed = true
	for step: int in 2000:
		if not game.run.journey_response.predator_profile.is_empty(): break
		game.advance(0.25)
	if game.run.journey_response.predator_profile != "wolf_spider": failed = true
	game.toggle_pause()
	await _capture("private_survey_1920")
	if str(view._signals).contains("wolf_spider"): failed = true
	game.toggle_pause()
	while game.run.journey_response.active(): game.advance(0.25)
	game.toggle_pause()
	var before: Dictionary = game.run.to_dict()
	await _capture("returned_spider_1920")
	var threat: Dictionary = {}
	for entry: Dictionary in view._placed:
		if entry.signal.category == "threat": threat = entry
	if threat.is_empty() or threat.signal.get("predator_profile", "") != "wolf_spider": failed = true
	else:
		var region := Rect2i(Vector2i(threat.center) - Vector2i(120, 120), Vector2i(240, 240))
		get_root().get_texture().get_image().get_region(region).save_png(output_dir.path_join("spider_detail.png"))
		# These age/identity variants are detached art fixtures, not extra discoveries.
		var signals: Array[Dictionary] = view._signals.duplicate(true)
		view.signal_provider = func() -> Array[Dictionary]: return signals
		for signal_data: Dictionary in signals:
			if signal_data.category == "threat": signal_data.predator_profile = "beetle_hunter"
		await _capture("fixture_beetle_1920")
		for signal_data: Dictionary in signals:
			if signal_data.category == "threat": signal_data.age = 1800.0
		await _capture("stale_memory_1920")
	if game.run.to_dict() != before: failed = true
	print("[CHEMISTRY] real_private_returned_and_detached_aging=%s" % not failed)


func _returned_beetle() -> void:
	var game: SimulationController = Roaming.new().ready_game()
	game.toggle_pause()
	game_root.simulation = game
	var view: OutwardView = game_root._outward_view
	view.signal_provider = game_root.focused_outward_signals
	view.status_provider = game_root.focused_outward_status
	var frozen: Dictionary = game.run.to_dict()
	await _capture("returned_beetle_1920")
	if game.run.to_dict() != frozen: failed = true
	print("[CHEMISTRY] actual_garden_returned_beetle=%s" % not failed)
