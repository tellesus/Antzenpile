extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new(); get_root().add_child(root); root.set_process(false)
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
			for phase: String in ["space", "carbohydrate", "final"]:
				var path: String = "res://.godot/card079_%s_%s.json" % [scenario,phase]
				if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path))): failed = true; continue
				root.simulation.toggle_pause(); root._refresh_loaded_views(); root.set_mode("inward")
				DisplayServer.window_set_size(size)
				var view: InwardView = root._inward_view; view.selected_id = "queen"
				var before: Dictionary = root.simulation.run.to_dict()
				await _capture("%s_%s_%d_grow" % [scenario,phase,size.x])
				if before != root.simulation.run.to_dict() or root.inward_status("home").brood_production.intent != "grow": failed = true
				var input: InputEvent = InputEventScreenTouch.new() if size.x == 900 else InputEventMouseButton.new()
				input.pressed = true; input.position = view._brood_intent_rect("manual").get_center()
				if input is InputEventMouseButton: input.button_index = MOUSE_BUTTON_LEFT
				view._unhandled_input(input)
				before.colony.piles[0].brood_intent = "manual"
				if before != root.simulation.run.to_dict(): failed = true
				await _capture("%s_%s_%d_manual" % [scenario,phase,size.x])
				if view._brood_intent_rect("grow").intersects(view._brood_rect()) or view._brood_rect().end.y >= view._button_rect("pause").position.y: failed = true
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		var before: Dictionary = root.simulation.run.to_dict()
		root._colony_controls.opened = true
		root._colony_controls.guide_open = true
		root._colony_controls.guide_page = 2
		await _capture("guide_%d" % size.x)
		if before != root.simulation.run.to_dict(): failed = true
	print("[STANDING-BROOD-PROBE] ordinary primitive/expanded/reserve waiting Queen contexts and updated guide; both settings/sizes; pause/manual mouse/touch changes only intent; targets separate; failed=",failed)
	root.free(); await create_timer(0.5).timeout; quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card079_%s.png" % label) != OK: failed = true
