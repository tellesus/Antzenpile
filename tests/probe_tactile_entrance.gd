extends "res://tests/probe_sensorium_revision.gd"
## Native entrance and current sound panel checks; mixer has its own200 probe.
func _run() -> void:
	output_dir = "res://.godot/card200/entrance"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new(); get_root().add_child(game_root); game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	_fixture(); _mature(true)
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size); game_root.set_mode("outward")
		await _capture("outward_%d" % size.x)
		var settings: AudioSettings = game_root._audio_settings
		settings.opened = true
		settings.changed = Callable()
		settings.activate_at(settings.level_rect("music", 3).get_center())
		if game_root.audio_preferences.music != 0.75 or not Rect2(Vector2.ZERO,Vector2(size)).encloses(settings.panel_rect()): failed = true
		await _capture("sound_%d" % size.x)
		settings.opened = false
	if frozen != game_root.simulation.run.to_dict(): failed = true
	print("[ENTRANCE200] passed=%s" % (not failed))
	game_root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
