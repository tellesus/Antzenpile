extends "res://tests/probe_neon_trails.gd"
const Loss = preload("res://tests/test_journey_investigation.gd")

func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output_dir="res://.godot/card186";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation=Loss.new().investigated_game();game_root.simulation.toggle_pause();game_root.set_mode("outward")
	var game: SimulationController=game_root.simulation
	var view: OutwardView=game_root._outward_view
	view.selected_id="signal:known:aphid_01";view.journey_open=true;view._process(0);view.facing=view._selected_signal().get("bearing",0.0)
	var frozen: Dictionary=game.run.to_dict()
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size);await _capture("unidentified_%d" % size.x)
		for pointer: String in ["mouse","touch"]:
			_tap(view,"conflict_send",pointer)
			if not view.conflict.editing or not view.conflict.searching(view._conflict_route(),view._status):failed=true
			view.conflict.all_hands=false;_tap(view,"draft_goal",pointer)
			if view.conflict.goal!="clear":failed=true
			if pointer=="mouse":await _capture("draft_off_%d" % size.x)
			_tap(view,"draft_all",pointer)
			if not view.conflict.all_hands:failed=true
			if pointer=="mouse":await _capture("draft_on_%d" % size.x)
			_tap(view,"draft_back",pointer)
		if game.run.to_dict()!=frozen:failed=true
	_tap(view,"conflict_send","touch");view.conflict.all_hands=false
	_tap(view,"draft_commit","touch");await _capture("ordered_900")
	if not game.run.journey_response.active() or game.run.journey_response.defense.sent!=12 or not game.run.journey_response.reports.is_empty():failed=true
	frozen=game.run.to_dict()
	for frame: int in 12:await process_frame
	if game.run.to_dict()!=frozen:failed=true
	game.toggle_pause()
	for tick: int in 1800:
		game.advance(0.25)
		if game.run.journey_response.predator_profile!="":break
	game.toggle_pause();await _capture("private_encounter_900")
	if not game.run.journey_response.reports.is_empty() or view.conflict_impression.cloud.cloud_material.get_shader_parameter("recognition")!=0.0:failed=true
	game.toggle_pause()
	for tick: int in 1800:
		if not game.run.journey_response.active():break
		game.advance(0.25)
	game.toggle_pause()
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size);await _capture("returned_%d" % size.x)
	if game.run.journey_response.reports.route_1.get("predator_profile","")!="wolf_spider" or view.conflict_impression.cloud.cloud_material.get_shader_parameter("recognition")<=0.0:failed=true
	print("[ARMED-SEARCH] native_optional_survey_borrowing_return=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)

func _tap(view: OutwardView, command: String, pointer: String) -> void:
	var at: Vector2=view._conflict_rect(command).get_center()
	for pressed: bool in [true,false]:
		var event: InputEvent
		if pointer=="mouse":event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		else:event=InputEventScreenTouch.new()
		event.position=at;event.pressed=pressed;view._unhandled_input(event)
