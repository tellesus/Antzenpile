extends SceneTree
## External native probe of the unchanged release pack; caller supplies an isolated profile.
var failures: int = 0

func _initialize() -> void:
	create_timer(30).timeout.connect(func() -> void:printerr("FAIL: packed current-save watchdog");quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: "+label)

func press(at: Vector2) -> void:
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=at;event.pressed=down;get_root().push_input(event,true)
		await process_frame

func run() -> void:
	# The pinned editor is a debug build, while this PCK excludes debug resources.
	# Release Main startup is checked separately; attach only the packed review here.
	var game=load("res://src/core/game_root.gd").new()
	game.simulation=load("res://src/core/simulation_controller.gd").new()
	game._review=load("res://src/presentation/run_review.gd").new()
	game._review.load_command=game.quick_load
	game._review.new_command=game.review_new_colony
	get_root().add_child(game._review)
	get_root().content_scale_size=Vector2i(900,600);DisplayServer.window_set_size(Vector2i(900,600))
	var controller=game.simulation
	controller.dispatch_scout("home",0.0);controller.dispatch_scout("home",PI)
	controller.advance(100)
	assert(controller.create_trail("home","known:carb_exposed"))
	controller.advance(260)
	var expected: Dictionary=controller.run.to_dict().duplicate(true)
	check(game.quick_save().accepted,"Packed current-build active colony saves")
	var path: String=game.save_service.path
	var document: String=FileAccess.get_file_as_string(path)
	var route=controller.run.trails.routes.route_1
	var segment_id: String=route.segment_id
	route.segment_id="missing_segment"
	var rejected: Dictionary=game.quick_save()
	check(not rejected.accepted and rejected.reason.contains("slot left unchanged") and FileAccess.get_file_as_string(path)==document,"Packed invalid runtime cannot overwrite last good slot")
	route.segment_id=segment_id
	check(game.end_run_review(),"Packed current-build end/review")
	var ended: Dictionary=controller.run.to_dict().duplicate(true)
	for action: String in ["first","play","last","previous","next"]:
		await press(game._review.button_rect(action).get_center())
		game._review._process(0.75)
	check(controller.run.to_dict()==ended,"Packed native playback remains detached")
	check(not game.quick_save().accepted and FileAccess.get_file_as_string(path)==document,"Packed revealed review keeps unrevealed saved slot")
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():
		await process_frame;await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(args[0])
	await press(game._review.button_rect("load").get_center())
	check(game.mode=="outward" and not game._review.visible and controller.run.to_dict()==expected,"Packed native LOAD SAVED restores exact state")
	var twin=load("res://src/core/simulation_controller.gd").new()
	check(twin.restore_snapshot(expected),"Packed reference snapshot validates")
	controller.advance(40);twin.advance(40)
	check(controller.run.to_dict()==twin.run.to_dict(),"Packed restored continuation matches exactly")
	game._review.free();game.free()
	for frame: int in 4:await process_frame
	await create_timer(0.3).timeout
	print("[PACKED-CURRENT-SAVE] native_save_review_reload_retention=",failures==0)
	quit(1 if failures else 0)
