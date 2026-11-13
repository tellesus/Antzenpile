extends "chemical_smoke.gd"
## Real loss, no survey, native whole-force commitment, private encounter and return.
func _run() -> void:
	game_root=Root.new();game_root.simulation=Controller.new(3043)
	var game: SimulationController=game_root.simulation
	assert(game.dispatch_scout("home",PI/4.0))
	for tick: int in 1200:
		if game.run.knowledge.nodes.has("known:aphid_01"):break
		game.advance(0.25)
	assert(game.create_trail("home","known:aphid_01"))
	for tick: int in 1800:
		if game.run.trails.routes.route_1.reported_losses>0:break
		game.advance(0.25)
	game.toggle_pause()
	get_root().content_scale_size=Vector2i(900,600);get_root().size=Vector2i(900,600)
	var view:=Outward.new();get_root().add_child(view)
	view.signal_provider=game_root.sensory_snapshot.bind("home");view.status_provider=game_root.outward_status.bind("home");view.journey_command=game_root.respond_to_journey
	view.selected_id="signal:known:aphid_01";view.journey_open=true;view._process(0);view.facing=view._selected_signal().get("bearing",0.0)
	var frozen: Dictionary=game.run.to_dict()
	view._run_conflict_command("conflict_send");view._run_conflict_command("draft_more_many")
	var failed: bool=not view.conflict.editing or view.conflict.amount!=17 or game.run.to_dict()!=frozen
	for frame: int in 12:await process_frame
	await RenderingServer.frame_post_draw
	var output: String=OS.get_cmdline_user_args()[0]
	if get_root().get_texture().get_image().save_png(output)!=OK:failed=true
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view._conflict_rect("draft_commit").get_center();view._unhandled_input(touch)
	if not view._feedback.contains("17 ants ordered") or view.conflict.editing:failed=true
	game.toggle_pause()
	var saw_private: bool=false
	for tick: int in 2400:
		game.advance(0.25)
		if game.run.journey_response.predator_profile!="":
			saw_private=true
			if not game.run.journey_response.reports.is_empty() or str(game_root.sensory_snapshot("home")).contains("wolf_spider"):failed=true
		if game.run.journey_response.defense.outcomes.has("route_1"):break
	game.toggle_pause();view._process(0)
	if not saw_private or game.run.journey_response.reports.get("route_1",{}).get("predator_profile","")!="wolf_spider":failed=true
	for frame: int in 12:await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png(output.get_basename()+"_returned.png")!=OK:failed=true
	var twin:=Controller.new()
	if not twin.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))):failed=true
	print("[PACKED-SEARCH] native_unsurveyed_borrowing_commit_return=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	view.free();game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)
