extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize() -> void: call_deferred("run_probe")
func press(view: OutwardView, at: Vector2, touch: bool) -> void:
	if touch:
		var down := InputEventScreenTouch.new(); down.index=0; down.position=at; down.pressed=true
		view._unhandled_input(down)
		var up := InputEventScreenTouch.new(); up.index=0; up.position=at; up.pressed=false
		view._unhandled_input(up)
	else:
		var down := InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.position=at; down.pressed=true
		view._unhandled_input(down)
		var up := InputEventMouseButton.new(); up.button_index=MOUSE_BUTTON_LEFT; up.position=at; up.pressed=false
		view._unhandled_input(up)
func capture(name: String) -> void:
	for frame: int in 6: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/card102_"+name+".png")
func run_probe() -> void:
	var colony := Root.new(); get_root().add_child(colony)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card102_ordinary.json"))
	if not colony.simulation.restore_snapshot(data): quit(1); return
	colony.simulation.toggle_pause(); colony.set_mode("outward")
	var view: OutwardView = colony._outward_view
	var frozen: Dictionary = colony.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		view.sources_open=false; view.selected_id=""
		await capture("before_%d" % size.x)
		press(view,view._button_rect("sources").get_center(),size.x==900)
		press(view,view._source_filter_rect("nest_site").get_center(),size.x==1280)
		failed = failed or view.source_category != "nest_site" or view._source_entries().size()!=1
		await capture("memory_%d" % size.x)
		press(view,view._source_row_rect(0).get_center(),size.x==900)
		await capture("selected_%d" % size.x)
		failed = failed or view.selected_id != "signal:known:nest_site_01" or colony.simulation.run.to_dict()!=frozen
		press(view,view._investigate_button_rect().get_center(),size.x==1280)
		failed = failed or "known:nest_site_01" not in colony.simulation.run.exploration.priorities
		press(view,view._investigate_button_rect().get_center(),size.x==900)
		failed = failed or colony.simulation.run.to_dict()!=frozen
	print("[NEST-SITE-UI] standard/compact actual mouse/touch memory/filter/recheck priority; paused truth preserved; passed=",not failed)
	colony.queue_free(); await process_frame; await process_frame
	quit(1 if failed else 0)
