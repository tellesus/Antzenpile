extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_sanitation.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var game := Root.new()
	get_root().add_child(game)
	game.set_process(false)
	# Funded pressure fixture tests presentation/input, not economic feasibility.
	game.simulation = Fixture.new().fixture()
	game.set_mode("inward")
	var view: InwardView = game._inward_view
	view._process(0)
	_touch(view, InwardView.positions(view.get_viewport_rect().size).midden)
	assert(view.selected_id == "midden")
	_touch(view, view._cleaner_rect(2).get_center())
	assert(game.simulation.run.colony.piles.home.midden.cleaners == 2)
	game.simulation.toggle_pause()
	await _capture(game, "basic")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = view._midden_develop_rect().get_center()
	view._unhandled_input(mouse)
	assert(game.simulation.run.colony.piles.home.midden.state == "developing")
	game.simulation.toggle_pause()
	game.simulation.advance(90)
	view._process(0)
	_touch(view, view._cleaner_rect(1).get_center())
	game.simulation.toggle_pause()
	await _capture(game, "developed")
	_touch(view, view._cleaner_rect(0).get_center())
	var state: SanitationState = game.simulation.run.colony.piles.home.midden
	state.generated_units = state.isolated_units + state.CONFIG.heavy_units
	view.selected_id = "nursery"
	await _capture(game, "nursery")
	print("[SANITATION-PROBE] touch cleanup, mouse development, reduced developed staffing, and Nursery pressure at standard/compact sizes")
	game.queue_free()
	await process_frame
	quit()
func _touch(view: InwardView, at: Vector2):
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = at
	view._unhandled_input(touch)
func _capture(game: Node, stage: String):
	var before: Dictionary = game.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(get_root().get_texture().get_image().save_png("res://.godot/card064_%s_%d.png" % [stage, size.x]) == OK)
	assert(before == game.simulation.run.to_dict())
