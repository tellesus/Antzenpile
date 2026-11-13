extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_source_recovery.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var game := Root.new()
	get_root().add_child(game)
	game.set_process(false)
	game.simulation = Fixture.new().fixture()
	var view: OutwardView = game._outward_view
	view._process(0)
	for signal_data: Dictionary in view._signals:
		if signal_data.source_knowledge_id == "known:carb_exposed":
			view.selected_id = signal_data.id
			view.facing = signal_data.bearing
	view._pointer_press(view._investigate_button_rect().get_center(), "touch")
	assert(game.simulation.run.trails.routes.route_1.resume_on_report)
	game.simulation.toggle_pause()
	await _capture(game, "watch")
	view._pointer_press(view._investigate_button_rect().get_center(), "mouse")
	game.simulation.toggle_pause()
	game.simulation.run.world.nodes.carb_exposed.quantity = 100
	assert(game.simulation.investigate_known_source("home", "known:carb_exposed"))
	for tick: int in 400:
		game.simulation.advance(0.25)
		if game.simulation.run.scouts.is_empty():
			break
	assert(game.simulation.run.trails.routes.route_1.status == "depleted")
	game.simulation.toggle_pause()
	await _capture(game, "renewed")
	print("[RECOVERY-PROBE] watch/stop input, returned renewal marker and separate gathering action at standard/compact sizes")
	game.queue_free()
	await process_frame
	quit()
func _capture(game: Node, stage: String):
	var before: Dictionary = game.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(get_root().get_texture().get_image().save_png("res://.godot/card063_%s_%d.png" % [stage,size.x]) == OK)
	assert(before == game.simulation.run.to_dict())
