extends "res://tests/probe_neon_trails.gd"
const Survey = preload("res://tests/test_journey_investigation.gd")
const Roaming = preload("res://tests/test_roaming_predator.gd")
const Fixture = preload("res://tests/test_colony_activity.gd")
## Native composition/menu verification. Fixture art is distinct from real reports.

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Sensorium captures require a native rendering display.")
		quit(1)
		return
	if "--movie" in OS.get_cmdline_user_args():
		await _movie()
		return
	output_dir = "res://.godot/card180"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	_fixture()
	var view: OutwardView = game_root._outward_view
	var status: Dictionary = view.status_provider.call()
	status.paused = true
	view.status_provider = func() -> Dictionary: return status
	view._animation_time = 11.0

	game_root._inward_view._animation_time = 11.0
	for size: Vector2i in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(900,600)]:
		_resize(size)
		game_root.set_mode("outward")
		await _capture("outward_%d" % size.x)
		view.selected_id = view._placed[1].id
		await _capture("context_%d" % size.x)
		view.selected_id = ""
		var menu: ColonyControls = game_root._colony_controls
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		menu._input(escape)
		if not menu.opened or not Rect2(Vector2.ZERO,Vector2(size)).encloses(menu.panel_rect()): failed = true
		await _capture("menu_%d" % size.x)
		menu._input(escape)
		game_root.set_mode("inward")
		game_root._inward_view.selected_id = ""
		await _capture("inward_%d" % size.x)
		game_root._inward_view.selected_id = "nursery"
		await _capture("nursery_%d" % size.x)
		game_root._inward_view.selected_id = ""
	if game_root.simulation.run.to_dict() != frozen: failed = true
	print("[SENSORIUM] resolution_menu_free_inspection_immutable=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	_resize(Vector2i(1920,1080))
	game_root.set_mode("inward")
	_mature(false)
	await _capture("developed_1920")
	_mature(true)
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(900,600)]:
		_resize(size)
		await _capture("strained_%d" % size.x)
	for frame: int in 30: await process_frame
	await RenderingServer.frame_post_draw
	var paused: PackedByteArray = get_root().get_texture().get_image().get_data()
	for frame: int in 12: await process_frame
	await RenderingServer.frame_post_draw
	if paused != get_root().get_texture().get_image().get_data(): failed = true
	if game_root.simulation.run.to_dict() != frozen: failed = true
	print("[SENSORIUM] developed_strained_pause_immutable=%s" % not failed)
	_resize(Vector2i(1920,1080))
	game_root.set_mode("outward")
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


func _mature(strained: bool) -> void:
	var view: InwardView = game_root._inward_view
	var status: Dictionary = game_root.inward_status("home")
	status.merge(Fixture.new().stress(), true)
	status.paused = true
	status.humidity.water_used = 3.0
	status.brood[0].progress_seconds = 60.0
	status.brood[1].progress_seconds = 30.0
	status.midden.merge(game_root.inward_status("home").midden)
	status.guest.merge({"reported_losses":4,"observation":"foreign","purge_progress":0.2})
	status.nursery_brood_capacity = 24
	status.nursery_max_care_capacity = 24
	status.nursery_expansion = {"state":"developed"}
	status.food_exchange_state = "developed"
	if not strained:
		status.humidity.moisture = 65.0
		status.humidity.larval_rate = 1.0
		status.midden.larval_rate = 1.0
		for cohort: Dictionary in status.brood:
			cohort.nutrition = 1.0
			cohort.care = 1.0
	view.status_provider = func() -> Dictionary: return status.duplicate(true)
	view.selected_id = ""
	view._animation_time = 11.0


func _movie() -> void:
	output_dir = "res://.godot/card180/frames"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	_resize(Vector2i(1280,720))
	_fixture()
	_mature(false)
	var outward: OutwardView = game_root._outward_view
	var status: Dictionary = outward.status_provider.call()
	status.paused = true
	outward.status_provider = func() -> Dictionary: return status
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	for mode: String in ["outward", "inward"]:
		game_root.set_mode(mode)
		for frame: int in 60:
			outward._animation_time = 11.0 + frame / 15.0
			game_root._inward_view._animation_time = outward._animation_time
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			if get_root().get_texture().get_image().save_png(output_dir.path_join("%s_%03d.png" % [mode,frame])) != OK: failed = true
	if game_root.simulation.run.to_dict() != frozen: failed = true
	print("[SENSORIUM-MOVIE] 120 native1280x720 frames; snapshot_immutable=%s" % not failed)
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
