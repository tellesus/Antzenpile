extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_guest.gd")
var failures: int = 0

func _initialize() -> void: _run.call_deferred()

func press(view: Node, point: Vector2, touch: bool) -> void:
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position = point; event.pressed = true
	if not touch: event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)

func _run() -> void:
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		if not root.simulation.restore_snapshot(Fixture.new().loss_fixture().run.to_dict()): failures += 1
		root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("outward")
		for frame: int in 8: await process_frame
		press(root._outward_view, root._outward_view._button_rect("internal_pressure").get_center(), size.x == 900)
		if root.mode != "inward" or root._inward_view.selected_id != "guest": failures += 1
		for state: String in ["uncertain", "nursery", "clearing", "settled"]:
			var view: InwardView = root._inward_view
			if state == "nursery": view.selected_id = "nursery"
			if state == "clearing":
				press(view, view._guest_link_rect().get_center(), size.x == 900)
				if view.selected_id != "guest": failures += 1
				press(view, view._guest_rect().get_center(), size.x == 900)
				if not root.simulation.run.guest.phase == "rejecting": failures += 1
			if state == "settled":
				root.simulation.toggle_pause(); root.simulation.advance(60.0); root.simulation.toggle_pause()
			for frame: int in 8: await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("res://.godot/card120_%s_%d.png" % [state,size.x])
	print("[NURSERY-HARM] eight captures; navigation/order failures=",failures)
	root.free(); await create_timer(0.3).timeout
	quit(1 if failures else 0)
