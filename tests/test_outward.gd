extends RefCounted

const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const SensoryFixture = preload("res://tests/test_observations.gd")


func signal_at(id: String, bearing: Variant) -> Dictionary:
	return {"id": id, "source_knowledge_id": "known:" + id, "category": "carbohydrate",
		"bearing": bearing, "estimated_distance": 10.0, "uncertainty_radius": 1.0,
		"strength": 0.45, "confidence": 0.8, "confidence_label": "clear", "age": 0.0,
		"risk": null, "traffic": null}


func run(test: Object) -> bool:
	var size := Vector2(1280, 720)
	var seam: Array[Dictionary] = [signal_at("left", deg_to_rad(359)), signal_at("right", deg_to_rad(1))]
	var placed: Array[Dictionary] = Panorama.project(seam, 0.0, size)
	test.check(placed.size() == 2 and placed[0].center.x < size.x * 0.5 and placed[1].center.x > size.x * 0.5, "Bearings on both sides of the east seam remain adjacent")
	test.check(absf(placed[0].center.x - placed[1].center.x) < 20.0 and placed[0].center.y == placed[1].center.y, "Seam projection has no screen discontinuity")
	var edges: Array[Dictionary] = Panorama.project([signal_at("north", 3 * PI / 2), signal_at("south", PI / 2), signal_at("behind", PI)], 0.0, size)
	test.check(edges.size() == 2 and edges[0].center.x < size.x * 0.5 and edges[1].center.x > size.x * 0.5, "Exactly 90-degree signals appear at edges; rear signal is culled")
	test.check(Panorama.project([signal_at("center", null)], 0.0, size).is_empty(), "Coincident direction produces no invented cloud")
	var facing := deg_to_rad(359)
	var center: Array[Dictionary] = Panorama.project([signal_at("seen", deg_to_rad(1))], facing, size)
	test.check(center.size() == 1 and center[0].center.x > size.x * 0.5, "Rotated-facing seam stays wrapped")
	test.check(Panorama.pick(center, center[0].center) == "seen" and Panorama.pick(center, center[0].center + Vector2(39, 0)) == "seen" and Panorama.pick(center, Vector2(0, 0)).is_empty(), "Nearest visible signal has touch-sized target")
	test.check(Panorama.project(seam, NAN, size).is_empty() and Panorama.project(seam, 0.0, Vector2.ZERO).is_empty(), "Invalid projection geometry is empty")
	var narrow: Array[Dictionary] = Panorama.project(seam, 0.0, Vector2(900, 600))
	test.check(narrow.size() == 2 and narrow[0].center.x >= 72 and narrow[1].center.x <= 828, "Projection remains within smaller landscape viewport")
	var source: Dictionary = seam[0].duplicate(true)
	placed[0].signal.category = "changed"
	test.check(seam[0] == source, "Screen placement holds detached signal values")
	var mouse := View.new()
	var touch := View.new()
	test.get_root().add_child(mouse)
	test.get_root().add_child(touch)
	var drag_start := Vector2(280, 250)
	var drag_end := Vector2(360, 250)
	mouse._pointer_press(drag_start, "mouse")
	mouse._pointer_drag(drag_end)
	mouse._pointer_release(drag_end, "mouse")
	touch._pointer_press(drag_start, "touch")
	touch._pointer_drag(drag_end)
	touch._pointer_release(drag_end, "touch")
	test.check(mouse.facing == touch.facing and mouse.facing > PI, "Mouse and touch use the same drag-to-turn path")
	test.check(View.facing_text(0.0) == "FACING  000°" and View.facing_text(7 * PI / 4) == "FACING  315°" and View.facing_text(TAU) == "FACING  000°", "Bearing label formats wrapped degrees without runtime error")
	test.check(mouse.selected_id.is_empty() and touch.selected_id.is_empty(), "Drag never selects a signal")
	var touch_input := View.new()
	test.get_root().add_child(touch_input)
	var touch_down := InputEventScreenTouch.new()
	touch_down.pressed = true
	touch_down.position = drag_start
	touch_input._unhandled_input(touch_down)
	var touch_motion := InputEventScreenDrag.new()
	touch_motion.position = drag_end
	touch_input._unhandled_input(touch_motion)
	var touch_up := InputEventScreenTouch.new()
	touch_up.position = drag_end
	touch_input._unhandled_input(touch_up)
	test.check(touch_input.facing == mouse.facing and touch_input._pointer_kind.is_empty(), "Screen-touch events follow the same turn path and release capture")
	var old_facing: float = mouse.facing
	mouse._pointer_press(Vector2(100, 200), "mouse")
	mouse._pointer_drag(Vector2(104, 200))
	mouse._pointer_release(Vector2(104, 200), "mouse")
	test.check(mouse.facing == old_facing, "Small tap movement does not rotate")
	mouse._pointer_press(Vector2(40, 45), "mouse")
	mouse._pointer_drag(Vector2(160, 45))
	mouse._pointer_release(Vector2(160, 45), "mouse")
	test.check(mouse.facing == old_facing, "HUD region cannot rotate panorama")
	var target: Array[Dictionary] = Panorama.project([signal_at("tap", 0.0)], 0.0, mouse.get_viewport_rect().size)
	mouse._placed = target
	mouse._pointer_press(target[0].center, "mouse")
	mouse._pointer_release(target[0].center, "mouse")
	touch._placed = target
	touch._pointer_press(target[0].center, "touch")
	touch._pointer_release(target[0].center, "touch")
	test.check(mouse.selected_id == "tap" and touch.selected_id == "tap", "Mouse and touch tap select the same sensory trace")
	var game := Controller.new(53)
	mouse._status = {"available_workers": 40, "active_scouts": 0, "scout_cap": 4, "paused": false, "time_scale": 1, "time": 0.0}
	mouse.dispatch_command = func(angle: float) -> bool: return game.dispatch_scout("home", angle)
	mouse.pause_command = game.toggle_pause
	mouse.speed_command = game.set_time_scale
	mouse._run_command("scout")
	test.check(game.run.scouts.size() == 1 and game.run.colony.piles.home.workers_available == 39, "Scout button dispatches semantic command through worker ledger")
	mouse._run_command("pause")
	test.check(game.run.clock.paused and game.run.clock.tick_count == 0, "Pause control changes authoritative clock state")
	mouse._run_command("speed_16")
	test.check(game.run.clock.time_scale == 16 and game.run.clock.paused, "Time control changes scale without silently unpausing")
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_SPACE
	keyboard.pressed = true
	test.check(keyboard.is_action_pressed("pause"), "Named pause keyboard action is configured")
	keyboard = InputEventKey.new()
	keyboard.physical_keycode = KEY_3
	keyboard.pressed = true
	test.check(keyboard.is_action_pressed("time_16"), "Named 16x keyboard action is configured")
	mouse._run_command("pause")
	game.advance(0.25)
	test.check(not game.run.clock.paused and game.run.clock.tick_count == 16, "Resuming advances at selected scale")
	var before: Dictionary = game.run.to_dict()
	mouse.turn_pixels(150.0, 1280.0)
	test.check(game.run.to_dict() == before, "Facing changes never modify simulation or RNG")
	mouse._status.active_scouts = 4
	mouse._run_command("scout")
	test.check(game.run.scouts.size() == 1, "Disabled scout action cannot exceed active cap")
	mouse.input_blocked = func() -> bool: return true
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(200, 200)
	press.pressed = true
	old_facing = mouse.facing
	mouse._unhandled_input(press)
	test.check(mouse._pointer_kind.is_empty() and mouse.facing == old_facing, "Development overlay blocks player pointer input")
	var root := Root.new()
	root.simulation = SensoryFixture.new().fixture()
	test.check(root.sensory_snapshot("home").is_empty(), "Undiscovered world produces empty OUTWARD field")
	root.simulation.advance(60.0)
	var observed: Array[Dictionary] = root.sensory_snapshot("home")
	test.check(observed.size() == 1 and Panorama.project(observed, 0.0, size).size() == 1, "Returned evidence appears as a sensory trace")
	var prior: Dictionary = root.simulation.run.to_dict()
	root.simulation.run.world.nodes.carb_exposed.position = Vector2(2, 2)
	test.check(root.sensory_snapshot("home") == observed and root.simulation.run.rng.state == int(prior.rng_state), "Hidden truth mutation does not refresh the player view")
	root.free()
	mouse.free()
	touch.free()
	touch_input.free()
	return true
