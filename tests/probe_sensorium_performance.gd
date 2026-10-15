extends "res://tests/probe_sensorium_revision.gd"
## Native frame-loop timings for art/composition, not an isolated GPU timer.
var sample_seconds: float = 60.0

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	output_dir = "res://.godot/card180"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	_fixture()
	_mature(true)
	var inward: InwardView = game_root._inward_view
	var status: Dictionary = inward.status_provider.call()
	status.paused = false
	inward.status_provider = func() -> Dictionary: return status
	_resize(Vector2i(1920,1080))
	var vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Dictionary = {"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"size":[1920,1080],"vsync":"disabled","audio":"Dummy",
		"fixture":"paused authoritative simulation; live decorative time; detached six-trail OUTWARD and developed/strained INWARD summaries",
		"scope":"native editor frame-loop, not release/full-game acceptance or isolated GPU cost","samples":[]}
	for mode: String in ["outward","inward"]:
		game_root.set_mode(mode)
		var warm_until: int = Time.get_ticks_usec() + 2000000
		while Time.get_ticks_usec() < warm_until: await process_frame
		await _capture("performance_%s_1920" % mode)
		var row: Dictionary = await _sample(true)
		row.erase("soft_halos")
		row.mode = mode
		results.samples.append(row)
		print("[SENSORIUM-PERF] %s" % JSON.stringify(row))
	DisplayServer.window_set_vsync_mode(vsync)
	results.snapshots_equal = frozen == game_root.simulation.run.to_dict()
	if not results.snapshots_equal: failed = true
	var file := FileAccess.open(output_dir.path_join("windows_performance.json"),FileAccess.WRITE)
	if file == null: failed = true
	else: file.store_string(JSON.stringify(results,"\t")+"\n"); file.close()
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)


func _sample(enabled: bool) -> Dictionary:
	var times: Array[float] = []
	var started: int = Time.get_ticks_usec()
	var last: int = started
	var deadline: int = started + int(sample_seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	var elapsed: float = float(last - started) / 1000000.0
	times.sort()
	var slow_count: int = maxi(1, int(ceil(times.size() * 0.01)))
	var slow_total: float = 0.0
	for index: int in range(times.size() - slow_count, times.size()): slow_total += times[index]
	var median: float = times[int(times.size() / 2)]
	return {"soft_halos": enabled, "seconds": elapsed, "frames": times.size(),
		"median_ms": median, "median_fps": 1000.0 / median,
		"p99_ms": times[mini(times.size() - 1, int(ceil(times.size() * 0.99)) - 1)],
		"one_percent_low_fps": 1000.0 / (slow_total / slow_count),
		"worst_ms": times.back()}
