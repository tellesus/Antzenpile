extends SceneTree
const Root=preload("res://src/core/game_root.gd")
var failed: bool=false
func _initialize() -> void: call_deferred("run_probe")
func capture(name: String) -> void:
	for frame: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/card104_"+name+".png")
func run_probe() -> void:
	var colony:=Root.new(); get_root().add_child(colony)
	var view: OutwardView=colony._outward_view
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		var prepared: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card104_backyard_slice_482817_prepared.json"))
		if not colony.simulation.restore_snapshot(prepared): quit(1); return
		colony.simulation.toggle_pause(); colony.set_mode("outward"); view.sources_open=false
		var signals: Array[Dictionary]=colony.sensory_snapshot("home")
		for signal_data: Dictionary in signals:
			if signal_data.category=="nest_site": view.selected_id=signal_data.id; view.facing=signal_data.bearing
		await capture("prepared_%d" % size.x)
		var event: InputEvent=InputEventScreenTouch.new() if size.x==900 else InputEventMouseButton.new()
		event.position=view._founding_rect().get_center(); event.pressed=true
		if event is InputEventMouseButton: event.button_index=MOUSE_BUTTON_LEFT
		view._unhandled_input(event)
		await capture("dispatched_%d" % size.x)
		failed=failed or colony.simulation.run.founding.phase!="outbound" or colony.simulation.run.colony.piles.home.workers.count("trail:"+colony.simulation.run.founding.route_id)!=12
		for phase: String in ["settling","ready"]:
			var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card104_backyard_slice_482817_%s.json" % phase))
			if not colony.simulation.restore_snapshot(saved): quit(1); return
			colony.simulation.toggle_pause(); var frozen: Dictionary=colony.simulation.run.to_dict()
			await capture("%s_%d" % [phase,size.x])
			failed=failed or colony.simulation.run.to_dict()!=frozen or view._button_at(view._founding_rect().get_center())=="founding"
	print("[FOUNDING-UI] standard/compact actual mouse/touch funding, private arrival, delivered camp and pause; passed=",not failed)
	colony.queue_free(); await process_frame; await process_frame; quit(1 if failed else 0)
