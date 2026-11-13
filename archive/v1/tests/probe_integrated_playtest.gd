extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Driver = preload("res://tests/scenario_run_driver.gd")
var failed: bool = false
var game_root: Node
var folder: String = "res://.godot/card191"
var captures: int = 0

func _initialize() -> void: _run.call_deferred()

func picture(name: String) -> void:
	for frame: int in 5: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png(folder.path_join(name + ".png")) != OK: failed = true
	captures += 1

func resize(size: Vector2i) -> void:
	get_root().content_scale_size = size
	get_root().size = size
	DisplayServer.window_set_size(size)

func sample(label: String, speed: int) -> Dictionary:
	game_root.simulation.set_time_scale(speed)
	game_root.set_process(true)
	game_root.simulation.run.clock.paused = false
	var start_time: float = game_root.simulation.run.simulation_time
	var until: int = Time.get_ticks_usec() + 2000000
	while Time.get_ticks_usec() < until: await process_frame
	var times: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var last: int = start
	until = start + 30000000
	while Time.get_ticks_usec() < until:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000)
		last = now
	game_root.set_process(false)
	game_root.simulation.run.clock.paused = true
	for pile: PileState in game_root.simulation.run.colony.piles.values():
		if not pile.workers.invariant_holds(): failed = true
	times.sort()
	var slow_count: int = maxi(1, ceili(times.size() * 0.01))
	var slow_sum: float = 0
	for index: int in range(times.size() - slow_count, times.size()): slow_sum += times[index]
	var row: Dictionary = {"label":label,"speed":speed,"seconds":float(last-start)/1000000,"frames":times.size(),"median_ms":times[times.size()/2],"p99_ms":times[mini(times.size()-1,ceili(times.size()*0.99)-1)],"one_percent_low_fps":1000/(slow_sum/slow_count),"worst_ms":times.back(),"simulated_seconds_advanced":game_root.simulation.run.simulation_time-start_time}
	row.median_fps = 1000 / row.median_ms
	print("[INTEGRATED-PERF] " + JSON.stringify(row))
	return row

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	game_root = Root.new(); get_root().add_child(game_root); game_root.set_process(false)
	game_root.audio_preferences.music = 1; game_root.audio_preferences.cues = 1
	var report: Dictionary = {"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"audio":"Dummy","size":[1920,1080],"scope":"native editor real Root and active current-build simulated colony;30-second frame-loop samples; debug overlay closed; not isolated GPU, exported-release or human acceptance","runs":[],"samples":[]}
	var vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for scenario: String in ["backyard_slice","garden_edge","roadside"]:
		var arc: Dictionary = Driver.new().play(scenario,"network" if scenario == "garden_edge" else "adaptive",6000 if scenario == "garden_edge" else 3600)
		if not arc.save_ok or not arc.events.has("continuity"): failed = true; print("[INTEGRATED-FAIL] strategy ",scenario)
		if not game_root.simulation.restore_snapshot(JSON.parse_string(JSON.stringify(arc.game.run.to_dict(),"",true,true))): failed = true; print("[INTEGRATED-FAIL] restore ",scenario)
		game_root.simulation.run.clock.paused = true
		game_root._refresh_loaded_views()
		var frozen: Dictionary = game_root.simulation.run.to_dict()
		report.runs.append({"scenario":scenario,"events":arc.events,"piles":game_root.simulation.run.colony.piles.size(),"same_build_midrun_continuation":arc.save_ok})
		for size: Vector2i in [Vector2i(1920,1080),Vector2i(900,600)]:
			resize(size)
			game_root.inspect_outward_pile("home"); await picture(scenario+"_outward_"+str(size.x))
			game_root.inspect_pile("home"); await picture(scenario+"_inward_"+str(size.x))
			for organ: String in ["queen","nursery","entrance"]:
				game_root._inward_view.selected_id = organ
				await picture(scenario+"_"+organ+"_"+str(size.x))
			game_root.inspect_pile("satellite_1"); await picture(scenario+"_daughter_"+str(size.x))
		if frozen != game_root.simulation.run.to_dict():
			failed = true; print("[INTEGRATED-FAIL] inspection changed run ",scenario)
			var diagnostic := FileAccess.open(folder.path_join(scenario+"_diagnostic.json"),FileAccess.WRITE)
			diagnostic.store_string(JSON.stringify({"before":frozen,"after":game_root.simulation.run.to_dict()}));diagnostic.close()
		resize(Vector2i(1920,1080)); game_root.inspect_outward_pile("home")
		if not OS.get_cmdline_user_args().has("captures"): report.samples.append(await sample(scenario+"_outward",1))
		game_root.inspect_pile("home")
		if not OS.get_cmdline_user_args().has("captures"): report.samples.append(await sample(scenario+"_inward64",64))
		game_root._colony_controls.opened = true
		await picture(scenario+"_menu_1920")
		game_root._colony_controls.opened = false
		if game_root._audio_controller.get_child_count() != 6: failed = true; print("[INTEGRATED-FAIL] audio children ",game_root._audio_controller.get_child_count())
	DisplayServer.window_set_vsync_mode(vsync)
	report.captures = captures; report.passed = not failed
	var file := FileAccess.open(folder.path_join("integrated.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	print("[INTEGRATED] fresh_complete_runs_inspection_active_ledgers_audio=%s captures=%d" % [not failed,captures])
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
