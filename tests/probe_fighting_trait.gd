extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Queue = preload("res://tests/test_adaptation_queue.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
var failures: int = 0
func _initialize(): go.call_deferred()
func press(view: InwardView, point: Vector2, touch: bool):
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position = point; event.pressed = true
	if event is InputEventMouseButton: event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event); view._process(0)
func capture(tag: String, width: int):
	for frame: int in 10: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card130_%s_%d.png" % [tag,width]) != OK: failures += 1
func go():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		if not root.simulation.restore_snapshot(Queue.new().snapshot(Queue.new().funded())): failures += 1
		root._refresh_loaded_views(); root.set_mode("inward")
		var view: InwardView = root._inward_view
		view.selected_id = "adaptation"; view._process(0)
		press(view,view._web_family_rect().get_center(),size.x == 900)
		if view.web_family != "combat": failures += 1
		press(view,Web.positions(view.get_viewport_rect().size).fighter,size.x == 900)
		if view.web_selection != "fighter": failures += 1
		await capture("inspect",size.x)
		press(view,view._adaptation_rect("fighter").get_center(),size.x == 900)
		if root.simulation.run.colony.piles.home.queued_adaptation != "fighter": failures += 1
		await capture("queued",size.x)
		root.simulation.advance(0.25); view._process(0)
		if root.simulation.run.colony.piles.home.trial_cohort().adaptation_id != "fighter": failures += 1
		await capture("locked",size.x)
		root.simulation.advance(361); view._process(0)
		if root.simulation.run.colony.piles.home.genetics.count_trait("fighter") != 8: failures += 1
		await capture("inherited",size.x)
	print("[FIGHTING UI] eight actual-input inspect/queue/locked/inherited captures; failures=",failures)
	root.free(); await create_timer(0.3).timeout; quit(1 if failures else 0)
