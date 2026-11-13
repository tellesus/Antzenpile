extends "res://tests/probe_sensory_art.gd"
## Paused composition/input proof; fixtures never pay for gameplay projects.

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var before: Dictionary = game_root.simulation.run.to_dict()
	game_root.set_mode("inward")
	var view: InwardView = game_root._inward_view
	var local: Dictionary = game_root.inward_status("home")
	view.status_provider = func() -> Dictionary: return local
	await _capture("card095_primitive")
	local.nursery_state = "developing"
	local.nursery_progress = local.nursery_build_duration*0.5
	await _capture("card095_developing")
	local.nursery_state = "developed"
	local.food_exchange_state = "developed"
	local.nursery_brood_capacity = 16
	await _capture("card095_developed")
	local.nursery_expansion.state = "developing"
	local.nursery_expansion.progress_seconds = local.nursery_expansion.duration*0.5
	await _capture("card095_expanding")
	local.nursery_expansion.state = "developed"
	local.nursery_brood_capacity = 32
	await _capture("card095_expanded")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600),Vector2i(1920,1080)]:
		DisplayServer.window_set_size(size)
		for frame: int in 40: await process_frame
		var centers: Dictionary = InwardView.positions(view.get_viewport_rect().size)
		for id: String in InwardView.NODES:
			view.selected_id = ""
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = true
			mouse.position = centers[id]
			view._unhandled_input(mouse)
			if view.selected_id != id: failed = true
			view.selected_id = ""
			var touch := InputEventScreenTouch.new()
			touch.pressed = true
			touch.position = centers[id]+Vector2(48,0)
			view._unhandled_input(touch)
			if view.selected_id != id: failed = true
		view.selected_id = "nursery"
		await _capture("card095_selected_%d" % size.x)
		view.selected_id = ""
		# Known-only functions have both a drawing gate and an input gate.
		if InwardView.node_at(centers.midden,view.get_viewport_rect().size) != "": failed = true
		if InwardView.node_at(centers.guest,view.get_viewport_rect().size) != "": failed = true
	DisplayServer.window_set_size(Vector2i(1280,720))
	local.merge(preload("res://tests/test_colony_activity.gd").new().stress(),true)
	local.paused = true
	await _capture("card095_known_activity")
	# Frozen biology, not merely a frozen simulation with still-moving decoration.
	var animation_time: float = view._animation_time
	await create_timer(0.6).timeout
	if view._animation_time != animation_time: failed = true
	if before != game_root.simulation.run.to_dict(): failed = true
	print("[MATERIAL] mouse_touch_all_organs=%s paused_snapshot_equal=%s" % [not failed,before==game_root.simulation.run.to_dict()])
	game_root.free()
	quit(1 if failed else 0)
