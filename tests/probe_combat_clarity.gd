extends "res://tests/probe_neon_trails.gd"
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Rival = preload("res://tests/test_rival_counterplay.gd")

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	output_dir="res://.godot/card182"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new(); get_root().add_child(game_root); game_root.set_process(false)
	var view: OutwardView=game_root._outward_view
	for scene: String in ["initial","queued","other_jobs","reinforce","junction"]:
		game_root.simulation=Rival.new().ready_game() if scene=="junction" else Defense.new().ready_game()
		var pile: PileState=game_root.simulation.run.colony.piles.home
		if scene in ["queued","other_jobs"]:
			pile.workers.create_commitment("probe:busy","internal","home")
			pile.allocate_workers("probe:busy",pile.workers_assignable-2)
			game_root.respond_to_journey("commit_clear_12","route_1")
		elif scene=="reinforce":game_root.respond_to_journey("commit_clear_12","route_1")
		game_root.simulation.toggle_pause()
		game_root.set_mode("outward")
		view.selected_id="signal:"+game_root.simulation.run.trails.routes.route_1.destination_knowledge_id
		view.journey_open=true;view.conflict.reset();view._process(0)
		view.facing=view._selected_signal().get("bearing",0.0)
		view._run_conflict_command("conflict_send")
		view.conflict.all_hands=scene=="other_jobs"
		var frozen: Dictionary=game_root.simulation.run.to_dict()
		for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
			_resize(size)
			await _capture("%s_%d" % [scene,size.x])
			if not view.conflict.editing:failed=true
		if game_root.simulation.run.to_dict()!=frozen:failed=true
	print("[COMBAT] native_layout_immutable=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
