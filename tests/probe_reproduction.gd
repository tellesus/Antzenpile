extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool=false
func _initialize() -> void: call_deferred("run_probe")
func press(view: InwardView, at: Vector2, touch: bool) -> void:
	if touch:
		var event:=InputEventScreenTouch.new(); event.position=at; event.pressed=true; view._unhandled_input(event)
	else:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=at; event.pressed=true; view._unhandled_input(event)
func capture(name: String) -> void:
	for frame: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/card103_"+name+".png")
func run_probe() -> void:
	var colony:=Root.new(); get_root().add_child(colony)
	var view: InwardView=colony._inward_view
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card103_backyard_slice_482817_prepared.json"))
		if not colony.simulation.restore_snapshot(prior): quit(1); return
		colony.simulation.toggle_pause(); colony.set_mode("inward"); view.selected_id="queen"; view.queen_tab="workers"
		await capture("workers_%d" % size.x)
		var frozen: Dictionary=colony.simulation.run.to_dict()
		press(view,view._queen_tab_rect("reproduction").get_center(),size.x==900)
		await capture("available_%d" % size.x)
		failed=failed or view.queen_tab!="reproduction" or colony.simulation.run.to_dict()!=frozen
		press(view,view._reproduction_rect().get_center(),size.x==1280)
		await capture("laid_%d" % size.x)
		failed=failed or colony.simulation.run.colony.piles.home.reproduction.phase!="egg" or colony.simulation.run.colony.piles.home.workers.count("reproduction:home")!=4
		for phase: String in ["larva","ready"]:
			var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card103_backyard_slice_482817_%s.json" % phase))
			if not colony.simulation.restore_snapshot(saved): quit(1); return
			colony.simulation.toggle_pause(); frozen=colony.simulation.run.to_dict()
			await capture("%s_%d" % [phase,size.x])
			failed=failed or colony.simulation.run.to_dict()!=frozen
	print("[REPRODUCTION-UI] standard/compact mouse/touch tabs and paid laying, laid/larval/ready art and frozen pause; passed=",not failed)
	colony.queue_free(); await process_frame; await process_frame; quit(1 if failed else 0)
