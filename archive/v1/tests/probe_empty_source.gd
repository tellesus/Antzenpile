extends SceneTree
## Captures the colony's last-empty report without revealing physical renewal.

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
		printerr("Empty-source probe scout could not launch")
		quit(1)
		return
	for tick: int in 400:
		if game.run.knowledge.nodes.has("known:protein_picnic"):
			break
		game.advance(0.25)
	if not game.run.knowledge.nodes.has("known:protein_picnic"):
		printerr("Empty-source probe did not receive picnic evidence")
		quit(1)
		return
	# Keep this visual-only fixture supplied while the temporary source expires.
	game.run.colony.piles.home.deposit_resource("carbohydrate", 10.0)
	if not game.create_trail("home", "known:protein_picnic"):
		printerr("Empty-source probe could not invest route")
		quit(1)
		return
	for tick: int in 1600:
		if game.run.trails.routes.route_1.status == "depleted":
			break
		game.advance(0.25)
	if game.run.trails.routes.route_1.status != "depleted":
		printerr("Empty-source probe did not receive an empty return: time=%.2f status=%s quantity=%.2f" % [game.run.simulation_time, game.run.trails.routes.route_1.status, game.run.world.nodes.protein_picnic.quantity])
		quit(1)
		return
	root.set_mode("outward")
	for signal_data: Dictionary in root.sensory_snapshot("home"):
		if signal_data.source_knowledge_id == "known:protein_picnic":
			root._outward_view.selected_id = signal_data.id
			break
	for frame: int in 30:
		await process_frame
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card037_empty_1280.png")
	DisplayServer.window_set_size(Vector2i(900, 600))
	for frame: int in 30:
		await process_frame
	get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card037_empty_900.png")
	print("[EMPTY PROBE] time=%.2f reported_empty=%s" % [game.run.simulation_time, game.run.knowledge.temporal_hint("known:protein_picnic").last_return_empty])
	root.free()
	await create_timer(0.2).timeout
	quit(0)
