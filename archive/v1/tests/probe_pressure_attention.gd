extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for kind: String in ["climate", "refuse"]:
			for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
				var path: String = "res://.godot/card075_%s_482817_%s.json" % [scenario, kind]
				if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path))): failed = true; continue
				root.simulation.toggle_pause()
				root._refresh_loaded_views()
				root.set_mode("outward")
				DisplayServer.window_set_size(size)
				await _capture("%s_%s_%d_badge" % [scenario,kind,size.x])
				var snapshot: Dictionary = root.simulation.run.to_dict()
				var view: OutwardView = root._outward_view
				if view._status.internal_attention.is_empty(): failed = true
				view._pointer_press(view._button_rect("internal_pressure").get_center(), "touch" if size.x == 900 else "mouse")
				if root.mode != "inward" or root._inward_view.selected_id != ("midden" if kind == "refuse" else "nursery"): failed = true
				await _capture("%s_%s_%d_context" % [scenario,kind,size.x])
				if snapshot != root.simulation.run.to_dict(): failed = true
				if kind == "refuse": root.set_sanitation_workers(2)
				else: root.set_humidity_workers(1)
				root.simulation.toggle_pause()
				root.simulation.advance(200.0)
				root.simulation.toggle_pause()
				root.set_mode("outward")
				await _capture("%s_%s_%d_recovered" % [scenario,kind,size.x])
				if not root._outward_view._status.internal_attention.is_empty(): failed = true
	print("[PRESSURE-PROBE] actual ordinary dry/refuse, both settings/sizes, touch/mouse context, unchanged click state, paid remedies clear badge; failed=",failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card076_%s.png" % label) != OK: failed = true
