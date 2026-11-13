extends SceneTree

const Root = preload("res://src/core/game_root.gd")
var game_root: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.simulation.toggle_pause()
	for frame: int in 5:
		await process_frame
	var view: OutwardView = game_root._outward_view
	view._run_command("scout")
	view._process(0.0)
	view.selected_id = "mission:scout_1"
	await _capture("approach")
	view._advance_departures(2.3)
	await _capture("climb")
	view._advance_departures(1.0)
	await _capture("away")
	game_root.simulation.toggle_pause()
	game_root.simulation.run.rain.phase = "raining"
	game_root.simulation.advance(12.0)
	game_root.simulation.toggle_pause()
	await _capture("fading")
	game_root.simulation.toggle_pause()
	for tick: int in 2000:
		if game_root.simulation.run.scouts.is_empty():
			break
		game_root.simulation.advance(0.25)
	game_root.simulation.toggle_pause()
	if not game_root.simulation.run.scouts.is_empty():
		quit(1)
		return
	await _capture("returned")
	game_root.simulation.run.scout_missions.scout_1.scent = 0.0
	await _capture("stub")
	print("[SCOUT-MEMORY] twelve standard/compact departure, fading, return and stub contexts; paused state preserved")
	game_root.free()
	quit(0)


func _capture(label: String) -> void:
	var before: Dictionary = game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 8:
			await process_frame
		get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card054_%s_%d.png" % [label, size.x])
	if before != game_root.simulation.run.to_dict():
		printerr("FAIL: drawing changed paused scout mission")
		quit(1)
