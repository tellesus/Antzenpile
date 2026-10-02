extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Snapshot = preload("res://tests/test_guest.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	var initial: Dictionary = Snapshot.new().snapshot(root.simulation)
	for mode: String in ["outward","inward"]:
		for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
			root.simulation.restore_snapshot(initial)
			root._refresh_loaded_views()
			root.set_mode(mode)
			DisplayServer.window_set_size(size)
			root.simulation.dispatch_scout("home",0.0)
			while root.simulation.run.simulation_time < 400 and root.simulation.run.knowledge.nodes.is_empty(): root.simulation.advance(0.25)
			var before: Dictionary = root.simulation.run.to_dict()
			var facing: float = root._outward_view.facing
			var message: String = root.poll_discovery_notice()
			if message.is_empty(): failed = true
			for frame: int in 3: await process_frame
			if not root._audio_controller.discovery_player.playing: failed = true
			await RenderingServer.frame_post_draw
			if get_root().get_texture().get_image().save_png("res://.godot/card072_%s_%d.png" % [mode,size.x]) != OK: failed = true
			if before != root.simulation.run.to_dict() or root._outward_view.facing != facing or not root._outward_view.selected_id.is_empty(): failed = true
	print("[DISCOVERY-PROBE] actual returned trace, cue playback and both-mode/size text, state/facing/selection unchanged; failed=%s" % failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
