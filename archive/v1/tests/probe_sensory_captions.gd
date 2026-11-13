extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card080_482817_recovered.json"))): quit(1); return
	root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("outward")
	var before: Dictionary = root.simulation.run.to_dict()
	var view: OutwardView = root._outward_view
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for bearing: int in [0,41,90,180,270,359]:
			view.facing = deg_to_rad(bearing); view.selected_id = ""; view.sources_open = false; view.exploration_open = false
			view._process(0)
			await _capture("%d_%03d" % [size.x,bearing])
			var rects: Array[Rect2] = []
			for entry: Dictionary in view._placed:
				if not view._signal_labels.has(entry.id): continue
				var text_size: Vector2 = view._font.get_string_size(view._signal_caption(entry.signal),HORIZONTAL_ALIGNMENT_LEFT,-1,13)
				var baseline: Vector2 = view._signal_labels[entry.id]
				var box := Rect2(baseline - Vector2(text_size.x * 0.5,text_size.y),text_size + Vector2(0,4))
				if rects.any(func(other: Rect2): return other.grow(3).intersects(box)): failed = true
				rects.append(box)
		view.facing = deg_to_rad(41); view._process(0)
		if not view._placed.is_empty():
			var center: Vector2 = view._placed[0].center
			var expected: String = Panorama.pick(view._placed,center)
			view._pointer_press(center,"touch" if size.x == 900 else "mouse")
			view._pointer_release(center,"touch" if size.x == 900 else "mouse")
			if view.selected_id != expected: failed = true
			await _capture("%d_selected" % size.x)
		view.sources_open = true; view.source_page = 1
		await _capture("%d_sources" % size.x)
		view.sources_open = false; view.exploration_open = true
		await _capture("%d_exploration" % size.x)
		if root.simulation.run.to_dict() != before: failed = true
	print("[CAPTION-PROBE] ordinary recovered Roadside, six bearings at 1280/900, selected/source/exploration reservations, separated captions and unchanged mouse/touch geometry/state; failed=",failed)
	root.free(); await create_timer(0.5).timeout; quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card082_%s.png" % label) != OK: failed = true
