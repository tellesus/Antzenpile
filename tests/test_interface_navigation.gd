extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
const Controls = preload("res://src/presentation/colony_controls.gd")
const Sound = preload("res://src/presentation/audio_settings.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	root.simulation = Defense.new().ready_game()
	var view := Outward.new()
	test.get_root().add_child(view)
	root._outward_view = view
	view.signal_provider = root.sensory_snapshot.bind("home")
	view.status_provider = root.outward_status.bind("home")
	view.journey_command = root.respond_to_journey
	view._process(0)
	view.selected_id = "signal:known:aphid_01"
	var controls := Controls.new()
	test.get_root().add_child(controls)
	controls.interaction_started = root.cancel_field_gesture
	var sound := Sound.new()
	test.get_root().add_child(sound)
	sound.interaction_started = root.cancel_field_gesture
	var before: Dictionary = root.simulation.run.to_dict()
	for kind: String in ["mouse", "touch"]:
		view._pointer_press(Vector2(400, 210), kind)
		var event: InputEvent = InputEventScreenTouch.new() if kind == "touch" else InputEventMouseButton.new()
		event.pressed = true
		if event is InputEventMouseButton: event.button_index = MOUSE_BUTTON_LEFT
		event.position = controls.help_button_rect().get_center()
		controls._input(event)
		test.check(controls.opened and controls.guide_open and view._pointer_kind.is_empty(), "%s opens Help directly and cancels an old field gesture" % kind)
		event.position = controls.guide_rect("back").get_center()
		controls._input(event)
		test.check(not controls.opened and not controls.guide_open, "%s Close Help returns directly to play" % kind)
		view._pointer_press(Vector2(400, 210), kind)
		event.position = sound.button_rect().get_center()
		sound._input(event)
		test.check(sound.opened and view._pointer_kind.is_empty(), "%s Sound modal also cancels old field gestures" % kind)
		sound.opened = false
	test.check(root.simulation.run.to_dict() == before, "Modal navigation preserves simulation")
	view._pointer_press(Vector2(400, 210), "mouse")
	root.set_mode("inward")
	test.check(view._pointer_kind.is_empty(), "Mode switching cannot leave an old rotation gesture")
	var pile: PileState = root.simulation.run.colony.piles.home
	pile.workers.create_commitment("test:busy", "other", "test")
	pile.workers.allocate("test:busy", pile.workers_available)
	view._process(0)
	before = root.simulation.run.to_dict()
	view._run_command("journey_defend")
	test.check(view._request_rejected and view._request_selection == view.selected_id and root.simulation.run.to_dict() == before, "Rejected defender request remains explainable without partial payment or dispatch")
	view._run_command("sources")
	test.check(not view._request_rejected, "New attention command clears the previous rejection notice")
	for page: Dictionary in Controls.GUIDE:
		for line: String in page.lines:
			test.check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= 360, "Guide line fits: " + line)
	controls.free(); sound.free(); view.free(); root.free()
	return true
