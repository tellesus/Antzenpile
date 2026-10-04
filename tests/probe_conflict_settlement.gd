extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Swarm = preload("res://tests/test_swarm.gd")
const Counter = preload("res://tests/test_rival_counterplay.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func press(view: Node, point: Vector2, touch: bool) -> void:
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position = point; event.pressed = true
	if not touch: event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)
func _run() -> void:
	var game: SimulationController = Swarm.new().forming_fixture()
	while game.run.trails.routes.route_1.conflict_report not in ["withdrew","dispersed"]: game.advance(0.25)
	var snapshots: Dictionary = {"rival_retreat":Defense.new().snapshot(game)}
	game = Counter.new().ready_game()
	while game.run.trails.routes.route_1.conflict_report != "secured": game.advance(0.25)
	snapshots.rival_victory = Defense.new().snapshot(game)
	game = Defense.new().ready_game(); game.journey_response.defend("route_1"); game.journey_response.reinforce("route_1")
	while game.run.journey_response.active(): game.advance(0.25)
	snapshots.ambush_return = Defense.new().snapshot(game)
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for state: String in snapshots:
			if not root.simulation.restore_snapshot(snapshots[state]): failures += 1
			root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("outward")
			var view: OutwardView = root._outward_view
			view.selected_id = "signal:"+root.trail_summaries("home")[0].destination_knowledge_id
			view._process(0); view._run_command("journey_open")
			for frame: int in 8: await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("res://.godot/card123_%s_%d.png" % [state,size.x])
			if state == "rival_retreat":
				press(view,view._journey_rect("journey_investigate").get_center(),size.x == 900)
				if root.simulation.run.trails.routes.route_1.desired_workers != 4: failures += 1
			if state == "ambush_return":
				press(view,view._journey_rect("journey_investigate").get_center(),size.x == 900)
				if root.simulation.run.trails.routes.route_1.desired_workers != 5: failures += 1
	print("[SETTLEMENT] six captures; restore/retry/reopen input failures=",failures)
	root.free(); await create_timer(0.3).timeout
	quit(1 if failures else 0)
