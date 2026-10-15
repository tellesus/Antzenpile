extends "res://tests/probe_sensorium_performance.gd"
const Defense = preload("res://tests/test_ambusher_defense.gd")

func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output_dir="res://.godot/card185";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation=Defense.new().ready_game();game_root.simulation.toggle_pause()
	game_root.set_mode("outward")
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	var view: OutwardView=game_root._outward_view
	var status: Dictionary=game_root.outward_status("home");status.paused=false
	view.status_provider=func()->Dictionary:return status
	view.selected_id="threat:route_1";view._process(0);view.facing=view._selected_signal().get("bearing",0.0)
	_resize(Vector2i(1920,1080))
	var vsync: DisplayServer.VSyncMode=DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Dictionary={"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"adapter":RenderingServer.get_video_adapter_name(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"size":[1920,1080],"vsync":"disabled","audio":"Dummy","fixture":"actual returned spider, one remembered trail; frozen authoritative run; live decorative clock; inspection open versus closed","scope":"native editor frame-loop, not isolated GPU timing or release/full-game acceptance","samples":[]}
	for opened: bool in [true,false]:
		view.selected_id="threat:route_1" if opened else "";view.journey_open=opened;view._animation_time=11.0
		var warm_until: int=Time.get_ticks_usec()+2000000
		while Time.get_ticks_usec()<warm_until:await process_frame
		var row: Dictionary=await _sample(true)
		row.erase("soft_halos");row.inspection_open=opened;results.samples.append(row)
		print("[INSPECTION-PERF] "+JSON.stringify(row))
	DisplayServer.window_set_vsync_mode(vsync)
	results.snapshots_equal=frozen==game_root.simulation.run.to_dict()
	if not results.snapshots_equal:failed=true
	var file:=FileAccess.open(output_dir.path_join("windows_performance.json"),FileAccess.WRITE)
	if file==null:failed=true
	else:file.store_string(JSON.stringify(results,"\t")+"\n");file.close()
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)
