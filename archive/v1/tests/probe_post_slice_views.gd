extends SceneTree
## Graphical layout/workload probe for the selected trace and Nursery context.

const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var root := Root.new()
	get_root().add_child(root)
	var game: SimulationController = root.simulation
	game.restore_snapshot(Controller.new(3040).run.to_dict())
	game.advance(450.0)
	if not game.dispatch_scout("home", PI / 4.0):
		printerr("Post-slice probe scout could not launch")
		quit(1)
		return
	for tick: int in 400:
		if game.run.knowledge.nodes.has("known:protein_picnic"):
			break
		game.advance(0.25)
	if not game.run.knowledge.nodes.has("known:protein_picnic"):
		printerr("Post-slice probe did not receive picnic evidence")
		quit(1)
		return
	root.set_mode("outward")
	for signal_data: Dictionary in root.sensory_snapshot("home"):
		if signal_data.source_knowledge_id == "known:protein_picnic":
			root._outward_view.selected_id = signal_data.id
			break
	await _settle()
	var large: Dictionary = await _measure()
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card036_selected_outward_1280.png")
	DisplayServer.window_set_size(Vector2i(900, 600))
	await _settle()
	var compact: Dictionary = await _measure()
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card036_selected_outward_900.png")
	root.set_mode("inward")
	root._inward_view.selected_id = "nursery"
	await _settle()
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card036_selected_nursery_900.png")
	print("[POST-PROBE] cpu=%s gpu=%s renderer=%s large_p95=%.2fms compact_p95=%.2fms nodes<=%d draws<=%d" % [OS.get_processor_name(), RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method"), large.p95, compact.p95, maxi(large.nodes, compact.nodes), maxi(large.draws, compact.draws)])
	get_root().remove_child(root)
	root.free()
	await create_timer(0.5).timeout
	quit(0)


func _settle() -> void:
	for frame: int in 30:
		await process_frame


func _measure() -> Dictionary:
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var peak_nodes: int = 0
	var peak_draws: int = 0
	for frame: int in 120:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
		peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	times.sort()
	return {"p95": times[114], "nodes": peak_nodes, "draws": peak_draws}
