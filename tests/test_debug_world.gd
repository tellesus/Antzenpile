extends RefCounted

const Run = preload("res://src/core/run_state.gd")
const Model = preload("res://src/debug/debug_world_model.gd")


func run(test: Object) -> bool:
	test.check(not Model.allowed(false, "Windows") and not Model.allowed(true, "headless") and Model.allowed(true, "Windows"), "Release and headless debug guards")
	var event := InputEventKey.new()
	event.keycode = KEY_F3
	event.pressed = true
	test.check(event.is_action_pressed("debug_world"), "F3 works on default input device")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	test.check(click.is_action_pressed("select"), "Selection works on default input device")
	var viewed := Run.new(7621)
	var control := Run.new(7621)
	var model := Model.new()
	test.check(not model.shown, "Debug initially hidden")
	model.toggle()
	for viewport: Vector2 in [Vector2(1280, 720), Vector2(900, 600), Vector2(1920, 1080)]:
		model.refresh(viewed.to_dict(), viewport)
		for entry: Dictionary in model.snapshot.colony.piles + model.snapshot.world.nodes:
			var position := Vector2(entry.position[0], entry.position[1])
			var screen: Vector2 = model.transform * position
			test.check((model.transform.affine_inverse() * screen).distance_to(position) < 0.0001, "World transform round trip")
			model.pick(screen)
			test.check(model.selected().id == entry.id, "Picking uses inverse transform after resize")
	for index: int in range(100):
		viewed.clock.advance(0.25)
		control.clock.advance(0.25)
		model.refresh(viewed.to_dict(), Vector2(1280, 720))
		model.toggle()
		model.pick(Vector2(300, 300))
		model.snapshot.world.nodes[0].quantity = 999
	test.check(viewed.to_dict() == control.to_dict() and viewed.rng.randi() == control.rng.randi(), "Debug refresh/toggle/selection and detached writes do not affect state or RNG")
	return true
