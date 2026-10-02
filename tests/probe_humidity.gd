extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_humidity.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var game := Root.new()
	get_root().add_child(game)
	game.set_process(false)
	game.simulation = Fixture.new().fixture()
	game.simulation.run.colony.piles.home.humidity.moisture = 400000
	game.set_mode("inward")
	var view: InwardView = game._inward_view
	view.selected_id = "nursery"
	view._process(0)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = view._humidity_rect(2).get_center()
	view._unhandled_input(touch)
	assert(game.simulation.run.colony.piles.home.humidity.carers == 2)
	game.simulation.toggle_pause()
	await _capture(game, "dry")
	game.simulation.toggle_pause()
	game.simulation.advance(70)
	view._process(0)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = view._humidity_rect(1).get_center()
	view._unhandled_input(mouse)
	assert(game.simulation.run.colony.piles.home.humidity.carers == 1)
	game.simulation.toggle_pause()
	await _capture(game, "recovered")
	print("[HUMIDITY-PROBE] separate climate staffing and laying, dry warning and recovered condition at standard/compact sizes")
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
		assert(get_root().get_texture().get_image().save_png("res://.godot/card066_%s_%d.png" % [stage, size.x]) == OK)
	assert(before == game.simulation.run.to_dict())
