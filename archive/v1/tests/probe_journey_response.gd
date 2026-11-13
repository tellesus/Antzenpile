extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_journey_investigation.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	var game: SimulationController = Fixture.new().investigated_game()
	root.simulation = game; root._refresh_loaded_views()
	var initial: Dictionary = game.run.to_dict()
	var view: OutwardView = root._outward_view
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		if not game.restore_snapshot(initial): failed = true
		view.selected_id = "signal:known:aphid_01"; view.facing = PI / 4; view.journey_open = false; view._process(0)
		await _capture("%d_loss" % size.x)
		view._pointer_press(view._journey_rect("journey_open").get_center(),"mouse")
		view._pointer_press(view._journey_rect("journey_investigate").get_center(),"touch")
		if not game.run.journey_response.active(): failed = true
		game.advance(10); view._process(0)
		await _capture("%d_away" % size.x)
		while game.run.journey_response.active(): game.advance(0.25)
		view._process(0)
		await _capture("%d_returned" % size.x)
		view.selected_id = "threat:route_1"; view.journey_open = false; view._process(0)
		if not view._journey_attention(): failed = true
		await _capture("%d_threat" % size.x)
		view._pointer_press(view._journey_rect("journey_close").get_center(),"touch")
		if view._journey_attention(): failed = true
	print("[JOURNEY-PROBE] ordinary loss, paid mouse/touch survey, away/returned/threat contexts at 1280/900; failed=",failed)
	root.free(); await create_timer(0.3).timeout; quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 12: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card083_%s.png" % label) != OK: failed = true
