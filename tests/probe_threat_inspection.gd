extends "res://tests/probe_neon_trails.gd"
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Beetle = preload("res://tests/test_roaming_predator.gd")
const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")


func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output_dir="res://.godot/card185";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	var view: OutwardView=game_root._outward_view
	for species: String in ["spider","beetle"]:
		game_root.simulation=Defense.new().ready_game() if species=="spider" else Beetle.new().ready_game()
		game_root.simulation.toggle_pause();game_root.set_mode("outward")
		view.signal_provider=game_root.focused_outward_signals;view.status_provider=game_root.focused_outward_status
		view.selected_id="threat:route_1";view.journey_open=true;view.conflict.reset();view._animation_time=11.0;view._process(0)
		view.facing=view._selected_signal().get("bearing",0.0)
		var frozen: Dictionary=game_root.simulation.run.to_dict()
		for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
			_resize(size);await _capture(species+"_%d" % size.x)
			for pointer: String in ["mouse","touch"]:
				_tap(view,"conflict_send",pointer)
				if not view.conflict.editing:failed=true
				var facing_before: float=view.facing
				var at: Vector2=view.conflict_impression.get_global_rect().get_center()
				view._pointer_press(at,pointer);view._pointer_drag(at+Vector2(35,0));view._pointer_release(at+Vector2(35,0),pointer)
				if view.facing!=facing_before:failed=true
				if pointer=="mouse":await _capture(species+"_draft_%d" % size.x)
				_tap(view,"draft_back",pointer)
			_tap(view,"conflict_reports","touch");await _capture(species+"_history_%d" % size.x)
			_tap(view,"draft_back","touch")
		if game_root.simulation.run.to_dict()!=frozen:failed=true
		if species=="spider":
			_resize(Vector2i(900,600))
			for index: int in 24:
				view._animation_time=11.0+index*0.1;await _capture("motion_%03d" % index)
			await RenderingServer.frame_post_draw
			var pixels: PackedByteArray=get_root().get_texture().get_image().get_data()
			for frame: int in 12:await process_frame
			await RenderingServer.frame_post_draw
			if pixels!=get_root().get_texture().get_image().get_data():failed=true
			var signals: Array[Dictionary]=view._signals.duplicate(true)
			view.signal_provider=func()->Array[Dictionary]:return signals
			for variant: String in ["weak","stale","generic","ground"]:
				for signal_data: Dictionary in signals:
					if signal_data.category!="threat":continue
					signal_data.confidence=0.2 if variant=="weak" else 0.75
					signal_data.age=1800.0 if variant=="stale" else 5.0
					if variant=="generic":signal_data.erase("predator_profile")
					if variant=="ground":signal_data.threat_kind="surface"
				await _capture(variant)
				if view.conflict_impression.cloud.cloud_material.get_shader_parameter("recognition")!=0.0:failed=true
			view.selected_id="";view.journey_open=false;await _capture("closed")
			if view.conflict_impression.visible:failed=true
	print("[INSPECTION] native_returned_layout_input_pause=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)


func _tap(view: OutwardView, command: String, pointer: String) -> void:
	var at: Vector2=view._conflict_rect(command).get_center()
	for pressed: bool in [true,false]:
		var event: InputEvent
		if pointer=="mouse":
			event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		else:event=InputEventScreenTouch.new()
		event.position=at;event.pressed=pressed;view._unhandled_input(event)
