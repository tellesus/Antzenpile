extends "res://tests/probe_sensory_art.gd"
const Fixture = preload("res://tests/test_colony_activity.gd")

func _run() -> void:
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	game_root.set_mode("inward")
	var view: InwardView = game_root._inward_view
	var status: Dictionary = game_root.inward_status("home")
	status.merge(Fixture.new().stress(), true)
	status.humidity.water_used = 3.0
	status.brood[0].progress_seconds = 60.0
	status.brood[1].progress_seconds = 30.0
	status.midden.merge(game_root.inward_status("home").midden)
	status.guest.merge({"reported_losses": 4, "observation": "foreign", "purge_progress": 0.2})
	status.nursery_occupied_space = 16
	status.nursery_brood_capacity = 16
	status.nursery_max_care_capacity = 16
	view.status_provider = func() -> Dictionary: return status.duplicate(true)
	view._animation_time = 7.0
	var snapshot: Dictionary = game_root.simulation.run.to_dict()
	for stage: String in ["pressure", "steady"]:
		if stage == "steady":
			status.humidity.moisture = 65.0
			status.humidity.larval_rate = 1.0
			status.midden.larval_rate = 1.0
			for cohort: Dictionary in status.brood:
				cohort.nutrition = 1.0
				cohort.care = 1.0
		for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
			DisplayServer.window_set_size(size)
			view.selected_id = ""
			await _capture("%s_%d" % [stage, size.x])
			view.activate_at(InwardView.positions(view.get_viewport_rect().size).nursery)
			await _capture("%s_selected_%d" % [stage, size.x])
	view.selected_id = ""
	status.paused = false # Decorative fixture only; actual run remains paused.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[ACTIVITY-PROBE] engine=%s gpu=%s renderer=%s bloom=false" % [Engine.get_version_info().string, RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method")])
	await create_timer(1.2).timeout # Refresh Godot's slower performance monitor after disabling vsync.
	await _measure("internal_jobs_900_unpaced")
	DisplayServer.window_set_size(Vector2i(1280,720))
	await create_timer(1.2).timeout
	await _measure("internal_jobs_1280_unpaced")
	if snapshot != game_root.simulation.run.to_dict(): failed = true
	print("[ACTIVITY-PROBE] snapshots_equal=%s max_ants=12 max_brood=6" % (snapshot == game_root.simulation.run.to_dict()))
	game_root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)

func _capture(label: String) -> void:
	for frame: int in 10: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card067_%s.png" % label) != OK: failed = true
