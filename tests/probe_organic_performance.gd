extends "res://tests/probe_sensorium_performance.gd"
## Six source routes plus eight scout scent directions; separate from live simulation timing.
func _run() -> void:
	output_dir="res://.godot/card192"
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	_fixture();_mature(true)
	var outward: OutwardView=game_root._outward_view
	var status: Dictionary=outward.status_provider.call()
	status.scout_missions=[]
	for i: int in 8:
		status.scout_missions.append({"id":"perf_%d" % i,"bearing":-1.1+i*0.31,"scent":0.85,"returned_at":-1.0,"course":[]})
	outward.status_provider=func() -> Dictionary:return status
	var inward: InwardView=game_root._inward_view
	var inside: Dictionary=inward.status_provider.call();inside.paused=false
	inward.status_provider=func() -> Dictionary:return inside
	_resize(Vector2i(1920,1080))
	var vsync: DisplayServer.VSyncMode=DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Dictionary={"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"adapter":RenderingServer.get_video_adapter_name(),"renderer":"Compatibility","size":[1920,1080],"vsync":"off","audio":"Dummy","scope":"native editor frame loop; paused simulation, live decorative clock; six route and eight scout traces, developed INWARD; not release or active simulation performance","samples":[]}
	for mode: String in ["outward","inward"]:
		game_root.set_mode(mode)
		await create_timer(2.0).timeout
		await _capture("performance_%s_1920" % mode)
		var row: Dictionary=await _sample(true);row.erase("soft_halos");row.mode=mode
		results.samples.append(row)
		print("[ORGANIC PERF] ",JSON.stringify(row))
	DisplayServer.window_set_vsync_mode(vsync)
	results.snapshots_equal=frozen==game_root.simulation.run.to_dict()
	var file:=FileAccess.open(output_dir.path_join("performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout
	quit(0 if results.snapshots_equal else 1)
