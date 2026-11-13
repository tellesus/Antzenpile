extends SceneTree
## Follow up a rare live-64x interval outlier; measures scheduling, not GPU timers.
const Root = preload("res://src/core/game_root.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	var paced: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game := Root.new()
	get_root().add_child(game)
	game.simulation.set_time_scale(64)
	await create_timer(1.0).timeout
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var start: int = last
	var above_16: int = 0
	var above_33: int = 0
	while Time.get_ticks_usec()-start < 20000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var interval: float = float(now-last)/1000.0
		times.append(interval)
		if interval > 16.667: above_16 += 1
		if interval > 33.333: above_33 += 1
		last = now
	times.sort()
	var report: Dictionary = {"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"speed":64,"seconds":float(last-start)/1000000.0,"frames":times.size(),"p50_ms":times[int(times.size()*0.5)],"p95_ms":times[int(times.size()*0.95)],"p99_ms":times[int(times.size()*0.99)],"worst_ms":times.back(),"above_16_667_ms":above_16,"above_33_333_ms":above_33,"render_texture":str(get_root().get_texture().get_size())}
	FileAccess.open("res://.godot/card096_live_interval.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[LIVE-INTERVAL] ",JSON.stringify(report))
	game.free()
	DisplayServer.window_set_vsync_mode(paced)
	quit()
