extends "chemical_smoke.gd"
var failed: bool=false

func press(at: Vector2) -> void:
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.position=at;event.pressed=down
		get_root().push_input(event,true);await process_frame

func picture(path: String) -> void:
	for frame: int in 4:await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png(path)!=OK:failed=true

func _run() -> void:
	game_root=Root.new();game_root.simulation=Controller.new(3043)
	game_root.simulation.advance(380);game_root.simulation.toggle_pause()
	get_root().content_scale_size=Vector2i(900,600);DisplayServer.window_set_size(Vector2i(900,600))
	var menu=load("res://src/presentation/colony_controls.gd").new()
	menu.seed_provider=game_root.current_seed;menu.scenario_provider=game_root.current_scenario
	menu.start_command=game_root.start_new_colony;menu.utility_command=game_root.menu_utility
	get_root().add_child(menu);game_root._colony_controls=menu
	var output: String=OS.get_cmdline_user_args()[0]
	var identity: String=SaveBuild.current()
	failed=not menu.build_caption().contains(identity.trim_prefix("windows-").trim_prefix("editor-").left(8))
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	await press(menu.button_rect().get_center());await picture(output)
	await press(menu.help_button_rect().get_center())
	for page: int in menu.GUIDE.size():
		if page==2:await picture(output.get_basename()+"_help.png")
		await press(menu.guide_rect("next").get_center())
	await press(menu.guide_rect("back").get_center())
	failed=failed or menu.opened or game_root.simulation.run.to_dict()!=frozen
	var review=load("res://src/presentation/run_review.gd").new()
	get_root().add_child(review);game_root._review=review
	if not game_root.end_run_review():failed=true
	frozen=game_root.simulation.run.to_dict()
	await picture(output.get_basename()+"_review.png")
	for point: Vector2 in [review.map_rect().position,review.map_rect().end]:
		if not review.map_rect().encloses(review.map_caption(point,20,"Spider-like ambusher").rect):failed=true
	await press(review.button_rect("first").get_center());await press(review.button_rect("last").get_center())
	if game_root.simulation.run.to_dict()!=frozen:failed=true
	print("[PACKED-INTERFACE] native_help_build_context_review=%s adapter=%s build_id=%s"%[not failed,RenderingServer.get_video_adapter_name(),identity])
	menu.free();review.free();game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)
