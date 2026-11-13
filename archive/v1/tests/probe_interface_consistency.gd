extends "res://tests/probe_neon_trails.gd"
const Search = preload("res://tests/test_journey_investigation.gd")
const Rival = preload("res://tests/test_rival_counterplay.gd")

func press(at: Vector2, touch: bool) -> void:
	for down: bool in [true,false]:
		var event: InputEvent=InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
		if event is InputEventMouseButton:event.button_index=MOUSE_BUTTON_LEFT
		event.position=at;event.pressed=down;get_root().push_input(event,true)
		await process_frame

func _run() -> void:
	output_dir="res://.godot/card189";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var controls: ColonyControls=game_root._colony_controls
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size);var touch: bool=size.x==900
		await press(controls.button_rect().get_center(),touch);await _capture("menu_%d"%size.x)
		await press(controls.help_button_rect().get_center(),touch)
		for page: int in ColonyControls.GUIDE.size():
			if page in [2,3,7,8]:await _capture("help_%d_%d"%[page,size.x])
			await press(controls.guide_rect("next").get_center(),touch)
		await press(controls.guide_rect("back").get_center(),touch)
	if game_root.simulation.run.to_dict()!=frozen or controls.opened:failed=true
	var view: OutwardView=game_root._outward_view
	for kind: String in ["search","rival"]:
		game_root.simulation=Search.new().investigated_game() if kind=="search" else Rival.new().ready_game()
		game_root.simulation.toggle_pause();game_root.set_mode("outward")
		view.selected_id="signal:known:aphid_01" if kind=="search" else "signal:known:carb_exposed"
		view.journey_open=true;view.conflict.reset();view._process(0);view.facing=view._selected_signal().get("bearing",0.0)
		frozen=game_root.simulation.run.to_dict()
		await press(view._conflict_rect("conflict_send").get_center(),true)
		await _capture(kind+"_draft_900")
		await press(view._conflict_rect("draft_goal").get_center(),true)
		if view.conflict.goal!="clear":failed=true
		await press(view._conflict_rect("draft_all").get_center(),true);await _capture(kind+"_borrow_on_900")
		if game_root.simulation.run.to_dict()!=frozen:failed=true
	game_root.simulation=Search.new().investigated_game();game_root._refresh_loaded_views()
	game_root.save_service.path="res://.godot/card189-slot.json"
	if not game_root.quick_save().accepted or not game_root.end_run_review():failed=true
	frozen=game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size);await _capture("review_%d"%size.x)
		await press(game_root._review.button_rect("first").get_center(),size.x==900)
		await press(game_root._review.button_rect("last").get_center(),size.x==900)
	if game_root.simulation.run.to_dict()!=frozen or game_root.quick_save().accepted:failed=true
	await press(game_root._review.button_rect("load").get_center(),true)
	if game_root.mode!="outward" or game_root._review.visible:failed=true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game_root.save_service.path))
	print("[INTERFACE] native_help_context_map_bounds_build_tag=%s adapter=%s"%[not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)
