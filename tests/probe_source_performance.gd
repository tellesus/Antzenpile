extends "res://tests/probe_sensorium_performance.gd"
## Same six-trail fixture, with and without approved source identity.

func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output_dir="res://.godot/card184";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	_fixture()
	var view: OutwardView=game_root._outward_view
	var signals: Array[Dictionary]=view.signal_provider.call()
	var types: Array[String]=["flower_nectar","dew_drops","insect_remains","aphid_honeydew","rain_puddle","cracked_seeds"]
	_resize(Vector2i(1920,1080))
	var vsync: DisplayServer.VSyncMode=DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Dictionary={"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"adapter":RenderingServer.get_video_adapter_name(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"size":[1920,1080],"vsync":"disabled","audio":"Dummy","fixture":"same detached six-trail OUTWARD fixture; live decorative clock; frozen authoritative run","scope":"native editor frame-loop, not release/full-game performance or isolated GPU timer","samples":[]}
	for identified: bool in [true,false]:
		for i: int in signals.size():
			signals[i].source_type=types[i] if identified else ""
		view._animation_time=11.0
		var warm_until: int=Time.get_ticks_usec()+2000000
		while Time.get_ticks_usec()<warm_until:await process_frame
		var row: Dictionary=await _sample(true)
		row.erase("soft_halos");row.identified=identified;results.samples.append(row)
		print("[SOURCE-PERF] "+JSON.stringify(row))
	DisplayServer.window_set_vsync_mode(vsync)
	results.snapshots_equal=frozen==game_root.simulation.run.to_dict()
	if not results.snapshots_equal:failed=true
	var file:=FileAccess.open(output_dir.path_join("windows_performance.json"),FileAccess.WRITE)
	if file==null:failed=true
	else:file.store_string(JSON.stringify(results,"\t")+"\n");file.close()
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)
