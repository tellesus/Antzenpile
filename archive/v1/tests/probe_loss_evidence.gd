extends SceneTree

const Root = preload("res://src/core/game_root.gd")
const PredatorFixture = preload("res://tests/test_predator.gd")
const SwarmFixture = preload("res://tests/test_swarm.gd")
var game_root: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	game_root = Root.new()
	get_root().add_child(game_root)
	var fixture := PredatorFixture.new()
	var game: SimulationController = fixture._fixture()
	for tick: int in 1200:
		if game.run.trails.routes.route_1.attack_reports > 0:
			break
		game.advance(0.25)
	await _capture(game, "attack", "known:aphid_01")
	for tick: int in 1200:
		if game.run.trails.routes.route_1.attack_reports > 1:
			break
		game.advance(0.25)
	await _capture(game, "repeated", "known:aphid_01")
	game = fixture._fixture()
	game.set_trail_workers("route_1", 1)
	for tick: int in 1200:
		if game.run.trails.routes.route_1.missing_workers > 0:
			break
		game.advance(0.25)
	await _capture(game, "missing", "known:aphid_01")
	game = SwarmFixture.new().forming_fixture()
	game.set_trail_workers("route_1", 9)
	for tick: int in 1600:
		if game.run.swarm.phase == "finished":
			break
		game.advance(0.25)
	game.set_trail_workers("route_1", 0)
	game.advance(100.0)
	await _capture(game, "fighting", "known:carb_exposed")
	print("[LOSS-EVIDENCE] eight standard/compact witness, repeated attack, missing and fighting contexts; paused state preserved")
	game_root.free()
	quit(0)


func _capture(game: SimulationController, label: String, source_id: String) -> void:
	if not game_root.simulation.restore_snapshot(PredatorFixture.new()._snapshot(game)):
		printerr("FAIL: loss probe fixture restore")
		quit(1)
		return
	game_root.simulation.toggle_pause()
	game_root._outward_view.reset_mission_visuals()
	game_root._outward_view.selected_id = "signal:" + source_id
	var before: Dictionary = game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 10:
			await process_frame
		get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card055_%s_%d.png" % [label, size.x])
	if before != game_root.simulation.run.to_dict():
		printerr("FAIL: drawing changed paused loss evidence")
		quit(1)
