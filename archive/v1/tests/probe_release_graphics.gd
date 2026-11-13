extends "res://tests/probe_sensory_art.gd"
## Comparable baseline/proof workload. Decorative fixtures never touch gameplay.

const InternalFixture = preload("res://tests/test_colony_activity.gd")
var measurements: Array[Dictionary] = []
var tag: String = "baseline"

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): tag = args[0]
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var before: Dictionary = game_root.simulation.run.to_dict()
	var paced: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[GRAPHICS] engine=%s cpu=%s gpu=%s renderer=%s max_fps=%d refresh=%.1f" % [Engine.get_version_info().string, OS.get_processor_name(), RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method"), Engine.max_fps, DisplayServer.screen_get_refresh_rate()])
	DisplayServer.window_set_size(Vector2i(1280,720))
	await _sample("quiet_outward")
	_fixture()
	var view: OutwardView = game_root._outward_view
	var stress_provider: Callable = view.status_provider
	var signal_provider: Callable = view.signal_provider
	var stress: Dictionary = stress_provider.call()
	var normal: Dictionary = stress.duplicate(true)
	normal.trails = normal.trails.slice(0,3)
	view.status_provider = func() -> Dictionary: return normal
	view.signal_provider = func() -> Array[Dictionary]: return signal_provider.call().slice(0,3)
	await _sample("normal_outward")
	view.status_provider = stress_provider
	view.signal_provider = signal_provider
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600), Vector2i(1920,1080)]:
		DisplayServer.window_set_size(size)
		await _sample("stress_outward_%d" % size.x)
		await _capture("%s_outward_%d" % [tag,size.x])
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(paced)
	await _sample("stress_outward_paced")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for state: String in ["uncertain","clear","stale","empty"]:
		var variants: Array[Dictionary] = signal_provider.call().duplicate(true)
		variants[1].confidence = 0.1 if state in ["uncertain","stale"] else 0.8
		variants[1].confidence_label = "uncertain" if state in ["uncertain","stale"] else "clear"
		variants[1].age = 400.0 if state == "stale" else 15.0
		view.signal_provider = func() -> Array[Dictionary]: return variants
		var state_status: Dictionary = stress.duplicate(true)
		state_status.temporal_hints[variants[1].source_knowledge_id].last_return_empty = state == "empty"
		view.status_provider = func() -> Dictionary: return state_status
		await _capture("%s_water_%s" % [tag,state])
	game_root.set_mode("inward")
	var inward: InwardView = game_root._inward_view
	var status: Dictionary = game_root.inward_status("home")
	status.merge(InternalFixture.new().stress(),true)
	status.humidity.water_used = 3.0
	status.brood[0].progress_seconds = 60.0
	status.brood[1].progress_seconds = 30.0
	status.nursery_brood_capacity = 16
	status.nursery_max_care_capacity = 16
	status.midden.merge(game_root.inward_status("home").midden)
	status.guest.merge({"reported_losses":4,"observation":"foreign","purge_progress":0.2})
	status.paused = false
	inward.status_provider = func() -> Dictionary: return status
	inward.selected_id = "nursery"
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600),Vector2i(1920,1080)]:
		DisplayServer.window_set_size(size)
		await _sample("stress_inward_%d" % size.x)
		await _capture("%s_inward_%d" % [tag,size.x])
	if before != game_root.simulation.run.to_dict():
		failed = true
		printerr("Decorative workload mutated simulation/RNG")
	game_root.free()
	# Natural quiet runtime at supported speeds, separately from detached rendering stress.
	game_root = Root.new()
	get_root().add_child(game_root)
	DisplayServer.window_set_size(Vector2i(1280,720))
	for speed: int in [1,16,64]:
		game_root.simulation.set_time_scale(speed)
		await _sample("live_%dx" % speed)
	game_root.free()
	var report: Dictionary = {"tag":tag,"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"samples":measurements,"decorative_snapshot_equal":not failed}
	var file := FileAccess.open("res://.godot/card088_%s.json" % tag,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	DisplayServer.window_set_vsync_mode(paced)
	quit(1 if failed else 0)

func _sample(label: String) -> void:
	await create_timer(0.8).timeout
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var start: int = last
	var draws: int = 0
	var texture_bytes: int = 0
	while Time.get_ticks_usec() - start < 2000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now-last)/1000.0)
		last = now
		draws = maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		texture_bytes = maxi(texture_bytes,int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	times.sort()
	var record: Dictionary = {"label":label,"logical_viewport":str(get_root().get_visible_rect().size),"window":str(DisplayServer.window_get_size()),"render_texture":str(get_root().get_texture().get_size()),"frames":times.size(),"duration_ms":float(last-start)/1000.0,"vsync":DisplayServer.window_get_vsync_mode(),"p50_ms":times[int(times.size()*0.5)],"p95_ms":times[mini(times.size()-1,int(times.size()*0.95))],"p99_ms":times[mini(times.size()-1,int(times.size()*0.99))],"worst_ms":times.back(),"draw_calls":draws,"texture_bytes":texture_bytes}
	measurements.append(record)
	print("[GRAPHICS] %s" % JSON.stringify(record))
