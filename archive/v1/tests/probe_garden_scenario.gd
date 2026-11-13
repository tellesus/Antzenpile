extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	root.simulation.toggle_pause()
	var snapshot: Dictionary = root.simulation.run.to_dict()
	var controls: ColonyControls = root._colony_controls
	for mode: String in ["outward","inward"]:
		root.set_mode(mode)
		for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
			DisplayServer.window_set_size(size)
			for frame: int in 3: await process_frame
			var touch := InputEventScreenTouch.new()
			touch.pressed = true
			touch.position = controls.button_rect().get_center()
			controls._input(touch)
			var mouse := InputEventMouseButton.new()
			mouse.pressed = true
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.position = controls.scenario_rect().get_center()
			controls._input(mouse)
			if controls.selected_scenario != "garden_edge": failed = true
			for frame: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			if get_root().get_texture().get_image().save_png("res://.godot/card071_%s_%d.png" % [mode,size.x]) != OK: failed = true
			controls.activate_at(controls.choice_rect("cancel").get_center())
	if root.simulation.run.to_dict() != snapshot: failed = true
	controls.selected_scenario = "garden_edge"
	controls.opened = true
	controls.activate_at(controls.choice_rect("repeat").get_center())
	if root.simulation.run.to_dict() != Controller.new(482817,"garden_edge").run.to_dict() or root.mode != "outward": failed = true
	if not root._outward_view._placed.is_empty(): failed = true
	root._outward_view.dispatch_command.call(0.0)
	if root.simulation.run.scouts.size() != 1: failed = true
	print("[GARDEN-PROBE] both layouts/modes, touch opening/mouse setting, no preview/selection mutation, exact selected restart and working commands; failed=%s" % failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
