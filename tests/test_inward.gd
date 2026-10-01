extends RefCounted

const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")


func run(test: Object) -> bool:
	var root := Root.new()
	test.get_root().add_child(root)
	var pile: PileState = root.simulation.run.colony.piles.home
	var summary: Dictionary = root.inward_status("home")
	test.check(summary.queens == 1 and summary.workers_total == 40 and summary.workers_available == 40 and summary.brood[0].count == 8 and summary.food_exchange_state == "primitive", "INWARD receives approved colony state")
	test.check(not summary.has("world") and not summary.has("position") and not summary.has("cohorts") and not summary.has("scouts"), "INWARD summary omits hidden world and individual agent objects")
	var unchanged: Dictionary = root.inward_status("home")
	summary.resources.carbohydrate = 999.0
	summary.brood[0].count = 999
	test.check(root.inward_status("home") == unchanged and pile.resources.carbohydrate == 10.0 and pile.brood_cohorts[0].count == 8, "INWARD summary is detached from authoritative state")
	root.simulation.run.world.nodes.carb_exposed.position = Vector2(35, 35)
	test.check(root.inward_status("home") == unchanged, "Changing hidden world truth never alters INWARD summary")
	for size: Vector2 in [Vector2(1280, 720), Vector2(900, 600)]:
		var centers: Dictionary = View.positions(size)
		test.check(centers.size() == 5 and centers.food_exchange.x < size.x - 316.0 and centers.adaptation.x < size.x - 316.0 and centers.queen.y > 98.0 and centers.entrance.y < size.y - 110.0, "Five authored nodes fit beside context and above controls")
		for id: String in View.NODES:
			test.check(View.node_at(centers[id], size) == id, "Node hit target selects " + id)
	var inward: InwardView = View.new()
	var outward: OutwardView = Outward.new()
	root.add_child(inward)
	root.add_child(outward)
	root._inward_view = inward
	root._outward_view = outward
	inward.status_provider = root.inward_status.bind("home")
	inward.mode_command = root.set_mode.bind("outward")
	outward.mode_command = root.set_mode.bind("inward")
	outward.facing = 1.2
	outward.selected_id = "signal:known:carb_exposed"
	test.check(root.set_mode("inward") and inward.visible and not outward.visible and root.mode == "inward", "Mode command shows INWARD only")
	var center: Vector2 = View.positions(inward.get_viewport_rect().size).nursery
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = center
	inward._unhandled_input(touch)
	test.check(inward.selected_id == "nursery", "Touch selects an abstract node")
	inward.selected_id = ""
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = center
	inward._unhandled_input(mouse)
	test.check(inward.selected_id == "nursery", "Mouse follows the same selection path")
	var before: Dictionary = root.simulation.run.to_dict()
	test.check(inward.activate_at(inward._button_rect("outward").get_center()) and root.mode == "outward" and outward.visible and not inward.visible, "Touch-sized OUTWARD button switches presentation")
	test.check(root.simulation.run.to_dict() == before and outward.facing == 1.2 and inward.selected_id == "nursery" and outward.selected_id == "signal:known:carb_exposed", "Switching preserves simulation, facing and per-view selections")
	outward._run_command("inward")
	test.check(root.mode == "inward" and inward.selected_id == "nursery", "OUTWARD mode button returns to the same INWARD selection")
	root.set_mode("outward")
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_TAB
	keyboard.pressed = true
	test.check(keyboard.is_action_pressed("toggle_inward"), "Named keyboard mode action exists")
	root._unhandled_input(keyboard)
	test.check(root.mode == "inward" and root.simulation.run.to_dict() == before, "Keyboard mode switch changes presentation only")
	root.simulation.advance(1.0)
	test.check(root.simulation.run.simulation_time == before.clock.time + 1.0, "Simulation continues across mode switches")
	var invalid: Dictionary = before.duplicate(true)
	invalid.colony.piles[0].food_exchange_state = "developed"
	test.check(not root.simulation.run.restore(invalid), "Task 017 snapshot rejects premature chamber development")
	root.queue_free()
	return true
