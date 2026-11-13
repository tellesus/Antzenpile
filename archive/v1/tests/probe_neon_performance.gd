extends "res://tests/probe_neon_trails.gd"
## Native 1080p frame-loop benchmark; run graphically with --audio-driver Dummy.
## Off uses a transparent halo mask, retaining draw submissions and bright cores.

const Glow = preload("res://src/presentation/outward/trail_glow.gd")
var sample_seconds: float = 60.0


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			sample_seconds = argument.get_slice("=", 1).to_float()
	if not is_finite(sample_seconds) or sample_seconds <= 0.0:
		printerr("Sample duration must be a positive number of seconds.")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("Native performance capture requires a rendering display.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var before: Dictionary = game_root.simulation.run.to_dict()
	_fixture()
	_resize(Vector2i(1920, 1080))
	var vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var original_mask: ImageTexture = Glow.texture()
	var transparent_mask: ImageTexture = ImageTexture.create_from_image(Image.create(128, 64, false, Image.FORMAT_RGBA8))
	var results: Dictionary = {
		"engine": Engine.get_version_info().string,
		"os": OS.get_name(), "cpu": OS.get_processor_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"size": [1920, 1080], "vsync": "disabled", "audio": "Dummy",
		"fixture": "detached six routes; paused simulation; live decorative animation",
		"control": "transparent soft trail halo mask; identical draw submissions; cores and ant halos retained",
		"samples": []
	}
	for enabled: bool in [true, false]:
		Glow._texture = original_mask if enabled else transparent_mask
		var warm_until: int = Time.get_ticks_usec() + 2000000
		while Time.get_ticks_usec() < warm_until: await process_frame
		await _capture("performance_halo_%s_1920" % ("on" if enabled else "off"))
		var row: Dictionary = await _sample(enabled)
		results.samples.append(row)
		print("[NEON-PERF] %s" % JSON.stringify(row))
	Glow._texture = original_mask
	DisplayServer.window_set_vsync_mode(vsync)
	results.snapshots_equal = before == game_root.simulation.run.to_dict()
	if not results.snapshots_equal: failed = true
	var file: FileAccess = FileAccess.open(output_dir.path_join("windows_performance.json"), FileAccess.WRITE)
	if file == null:
		failed = true
	else:
		file.store_string(JSON.stringify(results, "\t") + "\n")
		file.close()
	game_root._outward_view.signal_provider = Callable()
	game_root._outward_view.status_provider = Callable()
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
