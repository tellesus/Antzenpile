extends "res://tests/probe_colony_activity.gd"

func _capture(label: String) -> void:
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card074_%s.png" % label) != OK: failed = true
	if "selected" in label:
		var view: InwardView = game_root._inward_view
		view.activate_at(InwardView.positions(view.get_viewport_rect().size).midden)
		await process_frame
		await RenderingServer.frame_post_draw
		if get_root().get_texture().get_image().save_png("res://.godot/card074_%s_transition.png" % label) != OK: failed = true
		for frame: int in 24: await process_frame
		await RenderingServer.frame_post_draw
		if get_root().get_texture().get_image().save_png("res://.godot/card074_%s_midden.png" % label) != OK: failed = true
