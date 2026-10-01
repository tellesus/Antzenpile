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
	game._inward_view.selected_id = "adaptation"
	for frame: int in 40:
		await process_frame
	var result: Error = get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card039_adaptation_900.png")
	print("[ADAPTATION-PROBE] image=", result, " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit(0 if result == OK else 1)
