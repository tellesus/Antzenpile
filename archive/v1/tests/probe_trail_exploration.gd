extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_trail_exploration.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var game := Root.new()
	get_root().add_child(game)
	game.set_process(false)
	game.simulation = Fixture.new().fixture()
	game.simulation.set_exploration(1)
	game.simulation.advance(0.75)
	var scout: ScoutAgent = game.simulation.run.scouts.values()[0]
	var id: String = scout.id
	assert(scout.phase == "following_trail")
	for summary: Dictionary in game.scout_mission_summaries("home"):
		if summary.id == id:
			assert(summary.course.is_empty())
	for tick: int in 300:
		game.simulation.advance(0.25)
		if scout.phase == "exploring":
			break
	assert(scout.phase == "exploring")
	game.simulation.advance(3)
	game.simulation.set_exploration(0)
	game.simulation.advance(60)
	assert(not game.simulation.run.scouts.has(id) and not game.simulation.run.scout_missions[id].course.is_empty())
	game.simulation.toggle_pause()
	var view: OutwardView = game._outward_view
	view._process(0)
	for signal_data: Dictionary in view._signals:
		if signal_data.source_knowledge_id == "known:carb_exposed":
			view.selected_id = signal_data.id
			view.facing = signal_data.bearing
	view.exploration_open = true
	var before: Dictionary = game.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(get_root().get_texture().get_image().save_png("res://.godot/card062_returned_trunk_%d.png" % size.x) == OK)
	assert(game.simulation.run.to_dict() == before)
	print("[TRUNK-PROBE] private outbound trunk, physical branch/recall, delivered course, compact/standard UI")
	game.queue_free()
	await process_frame
	quit()
