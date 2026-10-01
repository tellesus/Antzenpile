extends SceneTree
## Graphical layout probe for the returned honeydew source and protection action.

const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var root := Root.new()
	get_root().add_child(root)
	var game: SimulationController = root.simulation
	game.restore_snapshot(Controller.new(3043).run.to_dict())
	if not game.dispatch_scout("home", PI / 4.0):
		printerr("Honeydew probe scout could not launch")
		quit(1)
		return
	for tick: int in 1000:
		if game.run.knowledge.nodes.has("known:aphid_01"):
			break
		game.advance(0.25)
	if not game.run.knowledge.nodes.has("known:aphid_01") or not game.create_trail("home", "known:aphid_01"):
		printerr("Honeydew probe could not create its trail")
		quit(1)
		return
	var route: TrailRouteState = game.run.trails.routes.route_1
	for tick: int in 800:
		if route.delivered_total > 0.0:
			break
		game.advance(0.25)
	if route.delivered_total <= 0.0 or not game.start_honeydew_tending("home"):
		printerr("Honeydew probe could not start tending")
		quit(1)
		return
	game.toggle_pause()
	root._outward_view.selected_id = "signal:known:aphid_01"
	for frame: int in 30:
		await process_frame
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card044_honeydew_1280.png")
	DisplayServer.window_set_size(Vector2i(900, 600))
	for frame: int in 30:
		await process_frame
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card044_honeydew_900.png")
	print("[HONEYDEW-PROBE] captured 1280x720 and 900x600 selected tended context")
	get_root().remove_child(root)
	root.free()
	await create_timer(0.5).timeout
	quit(0)
