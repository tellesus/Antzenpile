extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
			for phase: String in ["available", "building", "four_cohorts"]:
				var path: String = "res://.godot/card077_%s_482817_%s.json" % [scenario,phase]
				if not FileAccess.file_exists(path) or not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path))): failed = true; continue
				root.simulation.toggle_pause()
				root._refresh_loaded_views()
				root.set_mode("inward")
				DisplayServer.window_set_size(size)
				root._inward_view.selected_id = "nursery"
				var snapshot: Dictionary = root.simulation.run.to_dict()
				await _capture("%s_%s_%d" % [scenario,phase,size.x])
				if snapshot != root.simulation.run.to_dict(): failed = true
				var view: InwardView = root._inward_view
				if view._nursery_expand_rect().end.y >= view._button_rect("pause").position.y: failed = true
				if phase == "available":
					var input: InputEvent = InputEventScreenTouch.new() if size.x == 900 else InputEventMouseButton.new()
					input.pressed = true
					input.position = view._nursery_expand_rect().get_center()
					if input is InputEventMouseButton: input.button_index = MOUSE_BUTTON_LEFT
					view._unhandled_input(input)
					if root.simulation.run.colony.piles.home.nursery_expansion_state != "developing" or root.simulation.run.colony.piles.home.workers.count("nursery_expansion:home") != 8: failed = true
					await _capture("%s_paid_%d" % [scenario,size.x])
				if phase == "four_cohorts":
					if root.inward_status("home").brood.size() != 4 or root.inward_status("home").nursery_brood_capacity != 32: failed = true
	print("[NURSERY-PROBE] ordinary paid project and four cohorts, both settings/sizes, separate targets, touch/mouse payment, unchanged display snapshots; failed=",failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card077_%s.png" % label) != OK: failed = true
