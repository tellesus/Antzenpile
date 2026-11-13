extends "res://tests/probe_neon_performance.gd"
## Same six-trail fixture, with native cloud quads on/off. Not a GPU timer.

class MeasuredField extends ChemicalField:
	var enabled: bool = true

	func sync(entries: Array[Dictionary], empty_ids: Dictionary, visual_time: float, size: Vector2) -> void:
		super.sync(entries, empty_ids, visual_time, size)
		if not enabled:
			for cloud: ChemicalCloud in clouds.values(): cloud.visible = false


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="): sample_seconds = argument.get_slice("=", 1).to_float()
	if not is_finite(sample_seconds) or sample_seconds <= 0.0 or DisplayServer.get_name() == "headless":
		printerr("A native display and positive sample duration are required.")
		quit(1)
		return
	output_dir = "res://.godot/card179"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	_fixture()
	_resize(Vector2i(1920, 1080))
	var view: OutwardView = game_root._outward_view
	view.chemical_field.free()
	var field := MeasuredField.new()
	view.chemical_field = field
	view.add_child(field)
	var vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Dictionary = {"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"cpu": OS.get_processor_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"size": [1920, 1080], "vsync": "disabled", "audio": "Dummy",
		"fixture": "detached six trails, five nonempty clouds; actual simulation paused, decorative time live",
		"control": "cloud material quads hidden; identical configuration, trails, ants, labels and motes retained",
		"samples": []}
	for enabled: bool in [true, false]:
		field.enabled = enabled
		var warm_until: int = Time.get_ticks_usec() + 2000000
		while Time.get_ticks_usec() < warm_until: await process_frame
		await _capture("performance_clouds_%s_1920" % ("on" if enabled else "off"))
		var row: Dictionary = await _sample(enabled)
		row.erase("soft_halos")
		row.cloud_materials = enabled
		results.samples.append(row)
		print("[CHEMISTRY-PERF] %s" % JSON.stringify(row))
	DisplayServer.window_set_vsync_mode(vsync)
	results.snapshots_equal = frozen == game_root.simulation.run.to_dict()
	if not results.snapshots_equal: failed = true
	var file: FileAccess = FileAccess.open(output_dir.path_join("windows_performance.json"), FileAccess.WRITE)
	if file == null: failed = true
	else:
		file.store_string(JSON.stringify(results, "\t") + "\n")
		file.close()
	view.signal_provider = Callable()
	view.status_provider = Callable()
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
