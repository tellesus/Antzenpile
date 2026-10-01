extends SceneTree
## Reproducible compact-window visual check of the first Adaptation Web card.

const Root = preload("res://src/core/game_root.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(900, 600))
	var game := Root.new()
	get_root().add_child(game)
	game.set_mode("inward")
	var result: Error = await _capture(game, "", "card040_inward_stores_900.png")
	if result == OK:
		result = await _capture(game, "adaptation", "card040_adaptation_choices_900.png")
	if result == OK:
		result = await _capture(game, "food_exchange", "card040_food_exchange_900.png")
	var pile: PileState = game.simulation.run.colony.piles.home
	for resource_id: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource_id, 100.0)
	game.simulation.advance(360.0)
	if result == OK and game.simulation.start_adaptation("home", "lean"):
		result = await _capture(game, "adaptation", "card040_adaptation_trial_900.png")
	print("[INWARD-PROBE] images=", result, " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit(0 if result == OK else 1)


func _capture(game: Node, selection: String, filename: String) -> Error:
	game._inward_view.selected_id = selection
	for frame: int in 30:
		await process_frame
	return get_root().get_viewport().get_texture().get_image().save_png("res://.godot/" + filename)
