extends SceneTree

const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_guest.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var game_root := Root.new()
	get_root().add_child(game_root)
	var restored: bool = game_root.simulation.restore_snapshot(Fixture.new().loss_fixture().run.to_dict())
	if not restored:
		quit(1)
		return
	game_root.simulation.advance(60.0)
	game_root.set_mode("inward")
	game_root.simulation.toggle_pause()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for selection: String in ["guest", "nursery"]:
			game_root._inward_view.selected_id = selection
			for frame: int in 20:
				await process_frame
			get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card050_%s_%d.png" % [selection, size.x])
	print("[GUEST-PROBE] captured suspected guest and Nursery at standard/compact sizes")
	get_root().remove_child(game_root)
	game_root.free()
	await create_timer(0.5).timeout
	quit(0)
