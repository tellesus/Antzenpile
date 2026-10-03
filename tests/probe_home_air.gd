extends SceneTree
const Root = preload("res://src/core/game_root.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var colony := Root.new()
	get_root().add_child(colony)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card100_backyard_slice_4_warm.json"))
	if not colony.simulation.restore_snapshot(data): quit(1); return
	colony.simulation.toggle_pause()
	colony.set_mode("outward")
	var frozen: Dictionary = colony.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 8: await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://.godot/card101_home_air_%d.png" % size.x)
	var passed: bool = colony.outward_status("home").home_air == "Hot, dry air at Home" and colony.simulation.run.to_dict() == frozen
	print("[HOME-AIR-UI] standard/compact current Home cue, paused truth preserved; passed=",passed)
	colony.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)
