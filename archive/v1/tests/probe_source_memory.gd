extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_persistent_chemistry.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var game := Root.new()
	get_root().add_child(game)
	game.set_process(false)
	game.simulation = Fixture.new().experienced_game()
	game.simulation.toggle_pause()
	var view: OutwardView = game._outward_view
	view._process(0)
	view._pointer_press(view._button_rect("sources").get_center(), "touch")
	assert(view.sources_open)
	await _capture(game, "browse")
	view._pointer_press(view._source_row_rect(1).get_center(), "mouse")
	assert(not view.sources_open and not view.selected_id.is_empty())
	await _capture(game, "selected")
	print("[SOURCE-MEMORY-PROBE] source browser and remembered-bearing focus via touch/mouse at standard/compact sizes")
	game.queue_free()
	await process_frame
	quit()
func _capture(game: Node, stage: String):
	var before: Dictionary = game.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(get_root().get_texture().get_image().save_png("res://.godot/card065_%s_%d.png" % [stage, size.x]) == OK)
	assert(before == game.simulation.run.to_dict())
