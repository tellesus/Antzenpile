extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_brood_care_safeguard.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		var game: SimulationController = Fixture.new().legacy_stalled()
		if not root.simulation.restore_snapshot(Fixture.new().snapshot(game)): failed = true
		root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("inward")
		var view: InwardView = root._inward_view; view.selected_id = "nursery"; view._process(0)
		await _capture("stalled_%d" % size.x)
		var input: InputEvent = InputEventScreenTouch.new() if size.x == 900 else InputEventMouseButton.new()
		input.pressed = true; input.position = view._brood_care_rect().get_center()
		if input is InputEventMouseButton: input.button_index = MOUSE_BUTTON_LEFT
		view._unhandled_input(input); view._process(0)
		failed = failed or root.simulation.run.trails.routes.route_1.desired_workers != 38 or root.simulation.run.colony.piles.home.workers_available != 0
		await _capture("recalling_%d" % size.x)
		root.simulation.toggle_pause(); root.simulation.advance(100); root.simulation.toggle_pause(); view._process(0)
		failed = failed or root.inward_status("home").brood_care.missing > 0
		await _capture("restored_%d" % size.x)
		view.selected_id = "queen"; view._process(0)
		await _capture("held_%d" % size.x)
	print("[BROOD CARE UI] eight actual-input stalled/recalling/restored/held captures; failed=", failed)
	root.free(); await create_timer(0.5).timeout; quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 12: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card128_%s.png" % label) != OK: failed = true
