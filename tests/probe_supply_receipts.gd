extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		for phase: String in ["intake","loss","recovered"]:
			if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card080_482817_%s.json" % phase))): failed = true; continue
			root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("outward"); DisplayServer.window_set_size(size)
			var before: Dictionary = root.simulation.run.to_dict()
			var view: OutwardView = root._outward_view
			view._pointer_press(view._button_rect("sources").get_center(),"touch" if size.x == 900 else "mouse")
			view._process(0)
			await _capture("%s_%d_sources" % [phase,size.x])
			if not view.sources_open or view._source_entries().is_empty() or view._source_page_rect().end.y >= view._button_rect("pause").position.y: failed = true
			var selected: Dictionary = view._source_entries()[0]
			view._pointer_press(view._source_row_rect(0).get_center(),"mouse" if size.x == 900 else "touch")
			if view.selected_id != selected.id or view.facing != selected.bearing or view.sources_open or root.simulation.run.to_dict() != before: failed = true
			if phase == "recovered":
				view._run_command("sources"); view._run_command("source_page")
				await _capture("%d_second_page" % size.x)
	# Old dates remain visibly unknown until another actual intake.
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card080_482817_loss.json"))
	for route: Dictionary in legacy.trails.routes: route.erase("receipt")
	root.simulation.restore_snapshot(legacy); root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("outward")
	root._outward_view.sources_open = true
	await _capture("900_legacy_dates")
	print("[RECEIPT-PROBE] actual Roadside before/after failure/recovery, 1280/900, free mouse/touch selection, pagination, legacy dates; failed=",failed)
	root.free(); await create_timer(0.5).timeout; quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card081_%s.png" % label) != OK: failed = true
