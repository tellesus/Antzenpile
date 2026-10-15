extends "chemical_smoke.gd"
## External authoring probe; release PCK remains unchanged.

func _run() -> void:
	game_root=Root.new()
	game_root.simulation=Controller.new(482817)
	var game: SimulationController=game_root.simulation
	game.dispatch_scout("home",PI)
	for tick: int in 600:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:carb_sheltered"):break
	if not game.run.knowledge.nodes.has("known:carb_sheltered"):quit(1);return
	game.toggle_pause()
	get_root().content_scale_size=Vector2i(900,600)
	get_root().size=Vector2i(900,600)
	var view:=Outward.new()
	view.signal_provider=game_root.sensory_snapshot.bind("home")
	view.status_provider=game_root.outward_status.bind("home")
	view.gather_order_command=game_root.order_gathering
	get_root().add_child(view)
	view.selected_id="signal:known:carb_sheltered"
	view._process(0)
	view.facing=view._selected_signal().bearing
	var frozen: Dictionary=game.run.to_dict()
	view._run_command("trail_create")
	var touch:=InputEventScreenTouch.new()
	touch.pressed=true
	touch.position=view.gathering_draft.rect(Vector2(900,600),"gather_more").get_center()
	view._unhandled_input(touch)
	var failed: bool=view.gathering_draft.amount!=6 or game.run.to_dict()!=frozen
	for frame: int in 15:await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image=get_root().get_texture().get_image()
	failed=failed or picture.get_size()!=Vector2i(900,600) or picture.save_png(OS.get_cmdline_user_args()[0])!=OK
	var mouse:=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	mouse.position=view.gathering_draft.rect(Vector2(900,600),"gather_commit").get_center()
	view._unhandled_input(mouse)
	var route: TrailRouteState=game.run.trails.find_route("home","known:carb_sheltered")
	failed=failed or route==null or route.allocated_workers!=6 or view.gathering_draft.opened
	failed=failed or not view._feedback.contains("6 assigned · 0 queued")
	print("[PACKED-DISPATCH] native_free_edit_commit_receipt=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	view.free()
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
