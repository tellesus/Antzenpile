extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
var failures: int = 0
func _initialize() -> void: go.call_deferred()
func press(view: OutwardView, point: Vector2, touch: bool) -> void:
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position = point; event.pressed = true
	if event is InputEventMouseButton: event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)
func capture(tag: String, width: int) -> void:
	for frame: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/card126_%s_%d.png" % [tag,width])
func go() -> void:
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		root.simulation.restore_snapshot(Defense.new().snapshot(Defense.new().ready_game()))
		root._refresh_loaded_views(); root.set_mode("outward")
		var view: OutwardView = root._outward_view
		view.selected_id = "threat:route_1"; view._process(0)
		press(view,view._approach_tab_rect().get_center(),size.x == 900)
		view._process(0); await capture("ready",size.x)
		press(view,view._journey_rect("journey_defend").get_center(),size.x == 900)
		if root.simulation.run.journey_response.approach.candidate == null: failures += 1
		view._process(0); await capture("away",size.x)
		while root.simulation.run.journey_response.active(): root.simulation.advance(0.25)
		view._process(0); await capture("returned",size.x)
		press(view,view._journey_rect("journey_investigate").get_center(),size.x == 900)
		if root.simulation.run.trails.routes.route_1.desired_workers != 5: failures += 1
		press(view,view._journey_topic_rect().get_center(),size.x == 900)
		if view.approach_focus: failures += 1
	print("[APPROACH UI] six captures; test/resume/navigation input failures=",failures)
	root.free(); await create_timer(0.3).timeout; quit(1 if failures else 0)
