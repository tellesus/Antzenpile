extends SceneTree
const Root = preload("res://src/core/game_root.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var game := Root.new()
	get_root().add_child(game)
	game.set_process(false)
	game.simulation.set_exploration(5)
	game.simulation.advance(400)
	game.simulation.toggle_pause()
	var view: OutwardView = game._outward_view
	view._process(0)
	assert(not view._signals.is_empty())
	var signal_data: Dictionary = view._signals[0]
	view.selected_id = signal_data.id
	view.facing = signal_data.bearing
	view._pointer_press(view._investigate_button_rect().get_center(), "touch")
	view._pointer_press(view._button_rect("scout").get_center(), "mouse")
	assert(signal_data.source_knowledge_id in game.simulation.run.exploration.priorities)
	var before: Dictionary = game.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(get_root().get_texture().get_image().save_png("res://.godot/card061_priority_%d.png" % size.x) == OK)
	assert(before == game.simulation.run.to_dict())
	print("[COLLECTIVE-PROBE] recurring priority, exploration controls, standard/compact paused rendering")
	game.queue_free()
	await process_frame
	quit()
