extends SceneTree
## Windows graphical slice probe. Run without --headless using the pinned Godot build.

const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const SAMPLE_FRAMES: int = 240
var game_root: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game_root = Root.new()
	get_root().add_child(game_root)
	var game: SimulationController = game_root.simulation
	game.restore_snapshot(Controller.new(3030).run.to_dict())
	if game_root._debug_view != null:
		game_root._debug_view.snapshot_provider = game.run.to_dict
	game.dispatch_scout("home", 0.0)
	game.dispatch_scout("home", PI)
	game.advance(100.0)
	if not game.create_trail("home", "known:carb_exposed") or not game.create_trail("home", "known:carb_sheltered"):
		printerr("Profile fixture could not invest both routes")
		quit(1)
		return
	game.dispatch_scout("home", 2.0)
	for tick: int in 360:
		if game.run.rain.phase == "raining":
			break
		game.advance(0.25)
	if game.run.rain.phase != "raining":
		printerr("Profile fixture did not reach rain")
		quit(1)
		return
	print("[PROFILE] cpu=%s gpu=%s renderer=%s viewport=1280x720" % [OS.get_processor_name(), RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method")])
	await _measure("rain_outward")
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card022_rain_outward.png")
	game_root.set_mode("inward")
	game_root._inward_view.selected_id = "food_exchange"
	await _measure("rain_inward")
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card024_rain_inward.png")
	for tick: int in 2000:
		if game.run.knowledge.nodes.has("known:protein_01"):
			break
		game.advance(0.25)
	if not game.create_trail("home", "known:protein_01") or not game.start_food_exchange("home"):
		printerr("Profile fixture could not invest protein/development")
		quit(1)
		return
	for tick: int in 2000:
		if game.run.colony.piles.home.brood_matured_total == 8:
			break
		game.advance(0.25)
	if game.run.colony.piles.home.brood_matured_total != 8:
		printerr("Profile fixture did not reach emergence")
		quit(1)
		return
	game_root.set_mode("outward")
	await _measure("mature_outward")
	game_root.set_mode("inward")
	game_root._inward_view.selected_id = "food_exchange"
	await _measure("mature_inward")
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card022_mature_inward.png")
	DisplayServer.window_set_size(Vector2i(900, 600))
	for frame: int in 30:
		await process_frame
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card022_compact_inward.png")
	print("[PROFILE] final_time=%.2fs routes=%d cohorts=%d scouts=%d signals=%d" % [game.run.simulation_time, game.run.trails.routes.size(), game.run.trails.cohorts.size(), game.run.scouts.size(), game.run.knowledge.nodes.size()])
	get_root().remove_child(game_root)
	game_root.free()
	await create_timer(0.5).timeout
	quit(0)


func _measure(label: String) -> void:
	for warmup: int in 30:
		await process_frame
	var milliseconds: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var peak_nodes: int = 0
	var peak_draws: int = 0
	for sample: int in SAMPLE_FRAMES:
		await process_frame
		var now: int = Time.get_ticks_usec()
		milliseconds.append(float(now - last) / 1000.0)
		last = now
		peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	milliseconds.sort()
	print("[PROFILE] %s p50=%.2fms p95=%.2fms worst=%.2fms fps=%.1f nodes<=%d draws<=%d" % [label, milliseconds[120], milliseconds[228], milliseconds.back(), Engine.get_frames_per_second(), peak_nodes, peak_draws])
