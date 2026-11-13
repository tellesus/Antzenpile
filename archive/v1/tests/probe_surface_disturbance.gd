extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_surface_disturbance.gd")
var failures: int = 0
func _initialize(): go.call_deferred()
func press(view: OutwardView, point: Vector2, touch: bool):
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position = point; event.pressed = true
	if event is InputEventMouseButton: event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event); view._process(0)
func capture(tag: String, width: int):
	for frame: int in 10: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card129_%s_%d.png" % [tag,width]) != OK: failures += 1
func go():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		if not root.simulation.restore_snapshot(Fixture.new().snapshot(Fixture.new().returned())): failures += 1
		root._refresh_loaded_views(); root.set_mode("outward")
		var view: OutwardView = root._outward_view
		view.selected_id = "threat:route_1"; view._process(0)
		await capture("witness",size.x)
		if view._can_mobilize(root.trail_summaries("home")[0]): failures += 1
		press(view, view._journey_rect("journey_defend").get_center(), size.x == 900)
		if root.simulation.run.trails.routes.route_1.desired_workers != 0: failures += 1
		await capture("withdraw",size.x)
		root.simulation.advance(30); view._process(0)
		press(view,view._journey_rect("journey_investigate").get_center(),size.x == 900)
		if not root.simulation.run.journey_response.active(): failures += 1
		await capture("survey",size.x)
		root.simulation.advance(60); view._process(0)
		press(view,view._approach_tab_rect().get_center(),size.x == 900)
		press(view,view._journey_rect("journey_defend").get_center(),size.x == 900)
		if root.simulation.run.journey_response.approach.candidate == null: failures += 1
		root.simulation.advance(60); view._process(0)
		await capture("alternative",size.x)
	print("[SURFACE UI] eight actual-input witness/withdraw/survey/alternative captures; failures=", failures)
	root.free(); await create_timer(0.3).timeout; quit(1 if failures else 0)
