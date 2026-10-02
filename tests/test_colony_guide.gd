extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Controls = preload("res://src/presentation/colony_controls.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	test.get_root().add_child(root)
	var controls := Controls.new()
	controls.seed_provider = root.current_seed
	controls.scenario_provider = root.current_scenario
	controls.start_command = root.start_new_colony
	test.get_root().add_child(controls)
	var snapshot: Dictionary = root.simulation.run.to_dict()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = controls.button_rect().get_center()
	controls._input(touch)
	touch.position = controls.choice_rect("guide").get_center()
	controls._input(touch)
	test.check(controls.opened and controls.guide_open and controls.guide_page == 0, "Requested guide opens through touch without automatic tutorial")
	for page: int in Controls.GUIDE.size():
		controls.activate_at(controls.guide_rect("next").get_center())
	test.check(controls.guide_page == 0 and root.simulation.run.to_dict() == snapshot, "Navigation cycles concise pages without any colony action")
	controls.activate_at(controls.choice_rect("fresh").get_center())
	test.check(root.simulation.run.to_dict() == snapshot, "Guide absorbs coordinates of an underlying restart action")
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = controls.guide_rect("back").get_center()
	controls._input(mouse)
	test.check(not controls.guide_open and controls.opened, "Back returns to colony choices without closing or restarting")
	controls.activate_at(controls.choice_rect("guide").get_center())
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	controls._input(escape)
	test.check(not controls.opened and root.simulation.run.to_dict() == snapshot, "Escape closes help without pausing or changing the colony")
	controls.free()
	root.free()
	return true
