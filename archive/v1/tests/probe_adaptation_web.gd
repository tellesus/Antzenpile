extends SceneTree

const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Fixture = preload("res://tests/test_adaptation_web.gd")
var game_root: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_mode("inward")
	game_root._inward_view.selected_id = "adaptation"
	game_root.simulation.toggle_pause()
	await _capture("fork")
	game_root._inward_view.web_selection = "lean"
	await _capture("lean")
	var loaded: bool = game_root.simulation.restore_snapshot(Fixture.new().known_fixture().run.to_dict())
	if not loaded:
		quit(1)
		return
	game_root.simulation.toggle_pause()
	game_root._inward_view.web_selection = "honeydew"
	await _capture("observed")
	game_root.simulation.toggle_pause()
	game_root.simulation.create_trail("home", "known:aphid_01")
	for tick: int in 800:
		if game_root.simulation.run.honeydew.relationship == "exploited":
			break
		game_root.simulation.advance(0.25)
	var protected: bool = game_root.simulation.start_honeydew_tending("home")
	if not protected:
		quit(1)
		return
	game_root.simulation.toggle_pause()
	await _capture("protected")
	game_root.simulation.toggle_pause()
	for resource: String in PileState.RESOURCE_IDS:
		game_root.simulation.run.colony.piles.home.deposit_resource(resource, 150.0)
	game_root.simulation.advance(360.0)
	var started: bool = game_root.simulation.start_adaptation("home", "lean")
	if not started:
		quit(1)
		return
	game_root.simulation.advance(360.0)
	game_root.simulation.toggle_pause()
	game_root._inward_view.web_selection = "lean"
	await _capture("inherited")
	print("[WEB-PROBE] ten standard/compact contexts; paused authoritative snapshots unchanged by drawing")
	get_root().remove_child(game_root)
	game_root.free()
	await create_timer(0.5).timeout
	quit(0)

func _capture(label: String) -> void:
	var before: Dictionary = game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 20:
			await process_frame
		get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card052_%s_%d.png" % [label, size.x])
	if before != game_root.simulation.run.to_dict():
		printerr("FAIL: drawing changed paused simulation")
		quit(1)
