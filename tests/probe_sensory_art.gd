extends SceneTree
## Real returned alarm plus detached six-link graphical stress/layout fixture.

const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
var game_root: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game_root = Root.new()
	get_root().add_child(game_root)
	var game: SimulationController = game_root.simulation
	game.restore_snapshot(Controller.new(3043).run.to_dict())
	game.toggle_pause()
	await _capture("empty")
	game.toggle_pause()
	game.dispatch_scout("home", PI / 4.0)
	for tick: int in 1000:
		if game.run.knowledge.nodes.has("known:aphid_01"):
			break
		game.advance(0.25)
	if not game.create_trail("home", "known:aphid_01"):
		quit(1)
		return
	for tick: int in 1800:
		if game.run.trails.routes.route_1.reported_losses > 0:
			break
		game.advance(0.25)
	if game.run.trails.routes.route_1.reported_losses == 0:
		quit(1)
		return
	game.toggle_pause()
	game_root._outward_view.selected_id = "signal:known:aphid_01"
	game_root._outward_view._animation_time = 11.0
	await _capture("returned_alarm")
	DisplayServer.window_set_size(Vector2i(900, 600))
	await _capture("returned_alarm_compact")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var snapshot: Dictionary = game.run.to_dict()
	_fixture()
	print("[ART-PROBE] engine=%s cpu=%s gpu=%s renderer=%s glow=false" % [Engine.get_version_info().string, OS.get_processor_name(), RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method")])
	await _measure("six_links_1280")
	var vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _measure("six_links_1280_unpaced")
	DisplayServer.window_set_vsync_mode(vsync)
	await _capture("families_active_ghost_empty")
	DisplayServer.window_set_size(Vector2i(900, 600))
	await _measure("six_links_900")
	await _capture("families_compact")
	game_root.set_mode("inward")
	game_root._inward_view.selected_id = "adaptation"
	await _capture("inward_adaptation_compact")
	game_root._inward_view.selected_id = "nursery"
	await _capture("inward_nursery_compact")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _capture("inward_nursery")
	if snapshot != game.run.to_dict():
		printerr("Art probe mutated simulation or RNG")
		failed = true
	print("[ART-PROBE] snapshots_equal=%s capped_links=6 capped_outward_ants=21 capped_inward_ants=4" % (snapshot == game.run.to_dict()))
	get_root().remove_child(game_root)
	game_root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)


func _fixture() -> void:
	var signals: Array[Dictionary] = []
	var routes: Array[Dictionary] = []
	var hints: Dictionary = {}
	for index: int in 6:
		var category: String = ["carbohydrate", "water", "protein"][index % 3]
		var id: String = "known:art_%d" % index
		signals.append({"id": "signal:" + id, "source_knowledge_id": id, "category": category,
			"bearing": -1.1 + index * 0.42, "estimated_distance": 5.0 + index * 2.0,
			"strength": 0.72, "confidence": 0.8, "confidence_label": "clear", "uncertainty_radius": 1.0,
			"age": 15.0, "risk": "reported_loss" if index == 3 else null, "traffic": null})
		routes.append({"id": "route_%d" % index, "destination_knowledge_id": id,
			"pheromone_strength": 0.0 if index == 5 else 0.22 if index == 4 else 0.85,
			"route_familiarity": 0.75, "active_workers": 20, "allocated_workers": 20,
			"desired_workers": 20, "checking_workers": 0, "delivered_total": 15.0, "status": "active",
			"reported_losses": 1 if index == 3 else 0})
		hints[id] = {"has_report": true, "last_return_empty": index == 2, "label": "Last return found nothing" if index == 2 else "Risk unknown"}
	var status: Dictionary = game_root.outward_status("home")
	status.trails = routes
	status.temporal_hints = hints
	status.paused = false # Only decorative time runs; the actual run remains paused.
	game_root._outward_view.signal_provider = func() -> Array[Dictionary]: return signals
	game_root._outward_view.status_provider = func() -> Dictionary: return status
	game_root._outward_view.selected_id = ""


func _capture(label: String) -> void:
	for frame: int in 15:
		await process_frame
	var result: Error = get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card047_%s.png" % label)
	if result != OK:
		failed = true
	print("[ART-PROBE] capture=%s result=%d" % [label, result])


func _measure(label: String) -> void:
	for frame: int in 30:
		await process_frame
	var times: Array[float] = []
	var process_times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var nodes: int = 0
	var draws: int = 0
	for frame: int in 120:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		nodes = maxi(nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	times.sort()
	process_times.sort()
	print("[ART-PROBE] workload=%s p50=%.2fms p95=%.2fms worst=%.2fms process_p95=%.2fms vsync=%d nodes<=%d draws<=%d" % [label, times[60], times[114], times.back(), process_times[114], DisplayServer.window_get_vsync_mode(), nodes, draws])
