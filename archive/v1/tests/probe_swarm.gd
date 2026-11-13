extends SceneTree

const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_swarm.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var game_root := Root.new()
	get_root().add_child(game_root)
	var game: SimulationController = game_root.simulation
	var restored: bool = game.restore_snapshot(Fixture.new().forming_fixture().run.to_dict())
	if not restored:
		quit(1)
		return
	for tick: int in 200:
		if game.run.trails.routes.route_1.conflict_report == "contested":
			break
		game.advance(0.25)
	game.toggle_pause()
	game_root._outward_view.selected_id = "signal:known:carb_exposed"
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 20:
			await process_frame
		get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card049_contested_%d.png" % size.x)
	print("[SWARM-PROBE] captured delivered contested contact at standard and compact sizes")
	get_root().remove_child(game_root)
	game_root.free()
	await create_timer(0.5).timeout
	quit(0)
