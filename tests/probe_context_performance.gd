extends "res://tests/probe_sensorium_performance.gd"
const Context = preload("res://tests/test_context_impressions.gd")

func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output_dir="res://.godot/card188";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	_fixture()
	var view: OutwardView=game_root._outward_view
	var status: Dictionary=view.status_provider.call();status.temporal_hints={};status.paused=false
	var signals: Array[Dictionary]=[]
	var identities: Array[String]=["site_loam","site_root","site_stone","site_edge","large_animal","dog_like","foreign_ants"]
	for index: int in identities.size():
		var signal_data: Dictionary=Context.new().sample(identities[index])
		signal_data.merge({"id":"signal:known:art_%d"%index,"source_knowledge_id":"known:art_%d"%index,"confidence_label":"clear","bearing":-0.99+index*0.33,"estimated_distance":9.0,"uncertainty_radius":1.0,"traffic":null})
		signals.append(signal_data)
	view.signal_provider=func()->Array[Dictionary]:return signals
	view.status_provider=func()->Dictionary:return status
	_resize(Vector2i(1920,1080))
	var vsync: DisplayServer.VSyncMode=DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Dictionary={"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"adapter":RenderingServer.get_video_adapter_name(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"size":[1920,1080],"vsync":"disabled","audio":"Dummy","fixture":"seven detached returned-context clouds; six known courses/representative traffic; frozen authoritative run; live decorative clock; identities present versus absent","scope":"native editor frame-loop, not isolated GPU timing or release/full-game acceptance","samples":[]}
	for enabled: bool in [true,false]:
		if not enabled:
			for signal_data: Dictionary in signals:
				signal_data.erase("site_profile");signal_data.erase("passage_impression");signal_data.threat_kind=""
		view._animation_time=11.0
		var warm_until: int=Time.get_ticks_usec()+2000000
		while Time.get_ticks_usec()<warm_until:await process_frame
		await _capture("performance_%s_1920"%enabled)
		var row: Dictionary=await _sample(true)
		row.erase("soft_halos");row.identities=enabled;results.samples.append(row)
		print("[CONTEXT-PERF] "+JSON.stringify(row))
	DisplayServer.window_set_vsync_mode(vsync)
	results.snapshots_equal=frozen==game_root.simulation.run.to_dict()
	if not results.snapshots_equal:failed=true
	var file:=FileAccess.open(output_dir.path_join("windows_performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")+"\n");file.close()
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)
