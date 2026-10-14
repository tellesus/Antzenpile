extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
func _initialize() -> void: go.call_deferred()
func capture(tag: String, width: int) -> void:
	for frame: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/card127_%s_%d.png" % [tag,width])
func go() -> void:
	var game := Controller.new(71,"garden_edge")
	game.scouting.set_bias(2.15); game.scouting.set_effort(2)
	while not game.run.knowledge.nodes.has("known:aphid_01"): game.advance(0.25)
	game.scouting.set_effort(0); game.create_trail("home","known:aphid_01")
	while game.run.trails.routes.route_1.delivered_total == 0: game.advance(0.25)
	game.start_honeydew_tending("home")
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	root.simulation.restore_snapshot(Defense.new().snapshot(game)); root.simulation.toggle_pause()
	root._refresh_loaded_views(); root.set_mode("outward")
	var view: OutwardView = root._outward_view; view.selected_id = "signal:known:aphid_01"
	view.facing = (root.simulation.run.knowledge.nodes["known:aphid_01"].estimated_position-Vector2(20,20)).angle()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size); view._process(0); await capture("aphids",size.x)
		var controls: ColonyControls = root._colony_controls
		controls.activate_at(controls.help_button_rect().get_center())
		for index: int in ColonyControls.GUIDE.size():
			if ColonyControls.GUIDE[index].title in ["Manage returned threats","Choose another approach"]:
				controls.guide_page = index; await capture("help_%d" % index,size.x)
		controls.activate_at(controls.guide_rect("back").get_center())
	print("[VARIETY UI] six aphid/new-help captures at standard and compact sizes")
	root.free(); await create_timer(0.3).timeout; quit(0)
