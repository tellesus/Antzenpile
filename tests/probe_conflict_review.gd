extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failures: int = 0
var captures: int = 0

func _initialize() -> void: _run.call_deferred()

func press(view: Node, point: Vector2, touch: bool) -> void:
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position = point
	event.pressed = true
	if not touch: event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)

func _run() -> void:
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 4: await process_frame
		for state: String in ["ambush_losses","ambush_survey","ambush_away","ambush_pending","ambush_secured","rival_warning","rival_after_response","rival_heavy_response","guest_warning","guest_foreign","guest_purged","guest_outward","guest_nursery","rival_journey"]:
			var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card118_" + ("guest_foreign" if state in ["guest_outward","guest_nursery"] else "rival_after_response" if state == "rival_journey" else state) + ".json"))
			if not root.simulation.restore_snapshot(saved): failures += 1; continue
			root.simulation.toggle_pause(); root._refresh_loaded_views()
			var inward: bool = state.begins_with("guest") and state != "guest_outward"
			root.set_mode("inward" if inward else "outward")
			if inward:
				var view: InwardView = root._inward_view
				view.selected_id = ""
				view._process(0)
				press(view,view.positions(view.get_viewport_rect().size).nursery if state == "guest_nursery" else view.positions(view.get_viewport_rect().size).guest,size.x==900)
				if view.selected_id != ("nursery" if state == "guest_nursery" else "guest"): failures += 1
			else:
				var view: OutwardView = root._outward_view
				view.selected_id = "signal:known:aphid_01" if state.begins_with("ambush") else "signal:known:carb_exposed"
				# Select the actual returned source ID rather than assuming its hidden object name.
				if state.begins_with("ambush"): view.selected_id = "signal:" + root.trail_summaries("home")[0].destination_knowledge_id
				if state == "guest_outward": view.selected_id = ""
				view.journey_open = false; view._process(0)
				if state.begins_with("ambush") or state == "rival_journey":
					press(view,view._journey_rect("journey_open").get_center(),size.x==900)
					if not view.journey_open: failures += 1
			for frame: int in 8: await process_frame
			await RenderingServer.frame_post_draw
			if get_root().get_texture().get_image().save_png("res://.godot/card118_%s_%d.png" % [state,size.x]) != OK: failures += 1
			captures += 1
	print("[CONFLICT-PROBE] captures=",captures," mouse/touch navigation failures=",failures)
	root.free(); await create_timer(0.3).timeout
	quit(1 if failures > 0 else 0)
