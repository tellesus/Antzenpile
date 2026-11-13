extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		for phase: String in ["intake","loss","recovered"]:
			var path: String = "res://.godot/card080_482817_%s.json" % phase
			if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path))): failed = true; continue
			root.simulation.toggle_pause(); root._refresh_loaded_views(); DisplayServer.window_set_size(size)
			var before: Dictionary = root.simulation.run.to_dict()
			root.set_mode("outward")
			await _capture("%s_%d_outward" % [phase,size.x])
			if phase == "loss":
				root._outward_view._pointer_press(root._outward_view._button_rect("internal_pressure").get_center(),"touch" if size.x == 900 else "mouse")
				if root.mode != "inward" or root._inward_view.selected_id != "food_exchange": failed = true
			else: root.set_mode("inward"); root._inward_view.selected_id = "food_exchange"
			await _capture("%s_%d_food" % [phase,size.x])
			if before != root.simulation.run.to_dict(): failed = true
			if phase == "loss":
				var view: InwardView = root._inward_view
				var input: InputEvent = InputEventScreenTouch.new() if size.x == 900 else InputEventMouseButton.new()
				input.pressed = true; input.position = view._food_source_rect("carbohydrate").get_center()
				if input is InputEventMouseButton: input.button_index = MOUSE_BUTTON_LEFT
				view._unhandled_input(input)
				if root.mode != "outward" or not root._outward_view.sources_open or root._outward_view.source_category != "carbohydrate": failed = true
				await _capture("%d_review_sources" % size.x)
				if before != root.simulation.run.to_dict() or view._food_source_rect("carbohydrate").end.y >= view._button_rect("pause").position.y: failed = true
				# Actual selected returned food gives its existing Stop Traffic command.
				root._outward_view.sources_open = false; root._outward_view.selected_id = "signal:known:carb_spill"
				root._outward_view._process(0)
				for signal_data: Dictionary in root.sensory_snapshot("home"):
					if signal_data.source_knowledge_id == "known:carb_spill": root._outward_view.selected_id = signal_data.id
				await _capture("%d_supply_context" % size.x)
	# Detached primitive/history layout, preserving actual known symptom records.
	root.set_mode("inward"); root._inward_view.selected_id = "food_exchange"
	var status: Dictionary = root.inward_status("home"); status.food_exchange_state = "primitive"
	root._inward_view.status_provider = func() -> Dictionary: return status.duplicate(true)
	await _capture("900_primitive_history")
	root._colony_controls.opened = true; root._colony_controls.selected_scenario = "roadside"
	await _capture("900_roadside_selection")
	print("[CONTAMINATION-PROBE] actual intake/known failure/recovery, both sizes, header context and free sources via mouse/touch, existing suspect-supply controls, unchanged paused state, primitive history and Roadside selector; failed=",failed)
	root.free(); await create_timer(0.5).timeout; quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card080_%s.png" % label) != OK: failed = true
