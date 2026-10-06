extends SceneTree
const RootScript = preload("res://src/core/game_root.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var colony := RootScript.new()
	get_root().add_child(colony)
	var game: SimulationController = load("res://tests/test_ambusher_defense.gd").new().ready_game()
	game.toggle_pause()
	colony.simulation = game
	var view: OutwardView = colony._outward_view
	view.exploration_open = true
	var frozen: Dictionary = game.run.to_dict()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(900, 600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 8: await process_frame
		get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card098_caution_%d.png" % size.x)
	if game.run.to_dict() != frozen or view._status.exploration.cautious_routes != 1:
		quit(1)
		return
	print("[SCOUT-CAUTION-UI] known caution in standard/compact Exploration; paused state preserved")
	colony.queue_free()
	await process_frame
	await process_frame
	quit(0)
