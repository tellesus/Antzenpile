extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var game_root: Node
func _initialize():
	_run.call_deferred()
func _run():
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	var view: OutwardView = game_root._outward_view
	view._process(0)
	view._pointer_press(view._button_rect("scout").get_center(), "touch")
	view._pointer_press(view._exploration_rect("explore_5").get_center(), "mouse")
	view.facing = PI / 4
	view._pointer_press(view._exploration_rect("exploration_bias").get_center(), "touch")
	game_root.simulation.advance(7)
	assert(game_root.simulation.scouting.standing_count() == 4)
	game_root.simulation.toggle_pause()
	var before: Dictionary = game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(get_root().get_texture().get_image().save_png("res://.godot/card060_exploration_%d.png" % size.x) == OK)
	assert(game_root.simulation.run.to_dict() == before)
	print("[EXPLORATION-PROBE] standard/compact standing controls, actual mouse/touch input and paused drawing")
	game_root.queue_free()
	await process_frame
	quit()
