extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	root.simulation.toggle_pause()
	var controls: ColonyControls = root._colony_controls
	var snapshot: Dictionary = root.simulation.run.to_dict()
	for mode: String in ["outward","inward"]:
		root.set_mode(mode)
		for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
			DisplayServer.window_set_size(size)
			controls.opened = false
			for frame: int in 3: await process_frame
			controls.activate_at(controls.button_rect().get_center())
			controls.activate_at(controls.choice_rect("guide").get_center())
			for page: int in ColonyControls.GUIDE.size():
				for frame: int in 3: await process_frame
				await RenderingServer.frame_post_draw
				if get_root().get_texture().get_image().save_png("res://.godot/card073_%s_%d_%d.png" % [mode,size.x,page]) != OK: failed = true
				controls.activate_at(controls.guide_rect("next").get_center())
			controls.activate_at(controls.guide_rect("back").get_center())
			controls.activate_at(controls.choice_rect("cancel").get_center())
	if snapshot != root.simulation.run.to_dict() or root.interaction_blocked(): failed = true
	print("[GUIDE-PROBE] four optional pages, both modes/sizes, navigation/cancel, unchanged simulation; failed=%s" % failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
