extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_ambusher_defense.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	var game: SimulationController = Fixture.new().ready_game()
	root.simulation = game; root._refresh_loaded_views()
	var initial: Dictionary = Fixture.new().snapshot(game)
	var view: OutwardView = root._outward_view
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		if not game.restore_snapshot(initial): failed = true
		view.selected_id = "threat:route_1"; view.facing = PI / 4; view._process(0)
		await _capture("%d_mobilize" % size.x)
		view._pointer_press(view._journey_rect("journey_defend").get_center(),"mouse")
		if game.run.journey_response.defense.mode != "defend": failed = true
		while game.run.journey_response.phase == "outbound": game.advance(0.25)
		view._process(0)
		view._pointer_press(view._journey_rect("journey_defend").get_center(),"touch")
		if game.run.journey_response.defense.extra_workers != 4: failed = true
		view._process(0); await _capture("%d_away" % size.x)
		while game.run.journey_response.phase != "inbound": game.advance(0.25)
		view._process(0); await _capture("%d_private_victory" % size.x)
		if not view._status.journey_response.outcomes.is_empty(): failed = true
		while game.run.journey_response.active(): game.advance(0.25)
		view._process(0); await _capture("%d_returned" % size.x)
		if view._status.journey_response.outcomes.route_1.outcome != "secured": failed = true
		view._pointer_press(view._journey_rect("journey_close").get_center(),"touch")
		view._process(0); await _capture("%d_source" % size.x)
	print("[DEFENSE-PROBE] paid mouse mobilization/touch reinforcement, private victory, delivered outcome, source at 1280/900; failed=",failed)
	root.free(); await create_timer(0.3).timeout; quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 12: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card084_%s.png" % label) != OK: failed = true
