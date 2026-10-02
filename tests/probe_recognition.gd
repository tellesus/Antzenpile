extends SceneTree

const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_recognition.gd")
var game_root: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	game_root = Root.new()
	get_root().add_child(game_root)
	if not game_root.simulation.restore_snapshot(Fixture.new().candidate_game().run.to_dict()):
		quit(1)
		return
	game_root.set_mode("inward")
	game_root._inward_view.selected_id = "adaptation"
	game_root.simulation.toggle_pause()
	game_root._inward_view._process(0)
	if not game_root._inward_view.activate_at(game_root._inward_view._web_family_rect().get_center()):
		quit(1)
		return
	for id: String in ["security", "tolerance"]:
		game_root._inward_view.web_selection = id
		await _capture(id + "_candidate")
	var view: InwardView = game_root._inward_view
	if not view.activate_at(view._adaptation_rect("tolerance").get_center()) or game_root.simulation.run.colony.piles.home.trial_cohort().adaptation_id != "tolerance":
		quit(1)
		return
	await _capture("tolerance_trial")
	game_root.simulation.toggle_pause()
	Fixture.new().advance_cared(game_root.simulation, 360)
	game_root.simulation.toggle_pause()
	await _capture("tolerance_inherited")
	view.web_selection = "security"
	await _capture("alternative")
	print("[RECOGNITION-PROBE] ten standard/compact contexts; selected pointer purchase; paused drawing unchanged")
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
		get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card058_%s_%d.png" % [label, size.x])
	if before != game_root.simulation.run.to_dict():
		printerr("FAIL: drawing changed paused simulation")
		quit(1)
