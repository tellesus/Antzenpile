extends SceneTree

const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_persistent_chemistry.gd")
var game_root: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	game_root = Root.new()
	get_root().add_child(game_root)
	if not game_root.simulation.restore_snapshot(Fixture.new().experienced_game().run.to_dict()):
		quit(1)
		return
	game_root.set_mode("inward")
	game_root._inward_view.selected_id = "adaptation"
	game_root.simulation.toggle_pause()
	await _capture("pressure")
	if not game_root.simulation.restore_snapshot(Fixture.new().candidate_game().run.to_dict()):
		quit(1)
		return
	game_root.simulation.toggle_pause()
	game_root._inward_view.web_selection = "persistent"
	await _capture("candidate")
	game_root._inward_view._process(0.0)
	var before: Dictionary = game_root.simulation.run.to_dict()
	var leaf: Vector2 = AdaptationWeb.positions(game_root._inward_view.get_viewport_rect().size).persistent
	if not game_root._inward_view.activate_at(leaf) or game_root.simulation.run.to_dict() != before:
		quit(1)
		return
	if not game_root._inward_view.activate_at(game_root._inward_view._adaptation_rect("persistent").get_center()):
		quit(1)
		return
	if game_root.simulation.run.colony.piles.home.trial_cohort().adaptation_id != "persistent":
		printerr("FAIL: contextual pointer started the wrong trait")
		quit(1)
		return
	await _capture("trial")
	game_root.simulation.toggle_pause()
	game_root.simulation.advance(360.0)
	game_root.simulation.toggle_pause()
	await _capture("inherited")
	print("[CHEMISTRY-PROBE] eight standard/compact contexts; graph inspection free; one contextual purchase; pause preserved")
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
		get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card057_%s_%d.png" % [label, size.x])
	if before != game_root.simulation.run.to_dict():
		printerr("FAIL: drawing changed paused simulation")
		quit(1)
