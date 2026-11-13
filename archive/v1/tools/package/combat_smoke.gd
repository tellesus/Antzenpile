extends "chemical_smoke.gd"
## Native input and actual returned reports in an unchanged release PCK.
const WorkerArt = preload("res://src/presentation/sensory_art.gd")

func _run() -> void:
	game_root=Root.new();game_root.simulation=Controller.new(3043)
	var game: SimulationController=game_root.simulation
	game.dispatch_scout("home",PI/4.0)
	for tick: int in 1200:
		if game.run.knowledge.nodes.has("known:aphid_01"):break
		game.advance(0.25)
	if not game.create_trail("home","known:aphid_01"):quit(1);return
	for tick: int in 1800:
		if game.run.trails.routes.route_1.reported_losses>0:break
		game.advance(0.25)
	game.set_trail_workers("route_1",0)
	for tick: int in 1200:
		if game.run.trails.routes.route_1.allocated_workers==0:break
		game.advance(0.25)
	if not game.journey_response.investigate("route_1"):quit(1);return
	for tick: int in 1600:
		if not game.run.journey_response.active():break
		game.advance(0.25)
	game.toggle_pause()
	get_root().content_scale_size=Vector2i(900,600);get_root().size=Vector2i(900,600)
	var view:=Outward.new();get_root().add_child(view)
	view.signal_provider=game_root.sensory_snapshot.bind("home");view.status_provider=game_root.outward_status.bind("home")
	view.journey_command=game_root.respond_to_journey;view.selected_id="threat:route_1";view._process(0)
	view.facing=view._selected_signal().get("bearing",0.0)
	var frozen: Dictionary=game.run.to_dict()
	view._run_conflict_command("conflict_send")
	var touch:=InputEventScreenTouch.new();touch.pressed=true
	touch.position=view._conflict_rect("draft_more_many").get_center();view._unhandled_input(touch)
	var failed: bool=view.conflict.amount!=17 or game.run.to_dict()!=frozen or WorkerArt.WORKER.get_size()!=Vector2(1536,576)
	for frame: int in 15:await process_frame
	await RenderingServer.frame_post_draw
	failed=failed or get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])!=OK
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true
	mouse.position=view._conflict_rect("draft_commit").get_center();view._unhandled_input(mouse)
	failed=failed or view.conflict.editing or not view._feedback.contains("17 ants ordered") or not game.run.journey_response.active()
	print("[PACKED-COMBAT] native_edit_commit_receipt=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	view.free();game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
