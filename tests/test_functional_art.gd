extends RefCounted
const Activity = preload("res://src/presentation/inward/colony_activity.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Fixture = preload("res://tests/test_colony_activity.gd")

func run(test: Object) -> bool:
	var status: Dictionary = Fixture.new().stress()
	var before: Dictionary = status.duplicate(true)
	test.check(Activity.health(status, "nursery") == 0.5 and Activity.health(status, "midden") == 0.5, "Combined known strain uses the weakest reported function, without multiplying penalties")
	test.check(Activity.health({}, "nursery") == 1.0 and Activity.health(status, "queen") == 1.0, "Absent pressures and unrelated organs invent no illness")
	status.brood[0].nutrition = 0.0
	test.check(Activity.health(status, "nursery") == 0.0 and Activity.health(status, "midden") == 0.5, "Food starvation has an internal Nursery cue without inventing refuse")
	for health: float in [0.0, 0.5, 0.75, 1.0]:
		for time: float in [0.0, 0.1, 7.0, 3599.0]:
			test.check(absf(Activity.pulse(health, time)) <= 1.0, "Organic pulse remains finite and bounded")
	test.check(Activity.pulse(0.5, 7) != Activity.pulse(1.0, 7), "Strain changes pulse coherence")
	status = before.duplicate(true)
	Activity.health(status, "nursery")
	test.check(status == before, "Art projection never mutates known information")
	var game := Controller.new(74)
	var root := Root.new()
	root.simulation = game
	var view := View.new()
	test.get_root().add_child(view)
	game.toggle_pause()
	status.paused = true
	view.status_provider = func() -> Dictionary: return status.duplicate(true)
	var snapshot: Dictionary = game.run.to_dict()
	view.selected_id = "nursery"
	view._process(0.07)
	test.check(view._focus_gains.nursery > 0.0 and view._focus_gains.nursery < 1.0 and view._animation_time == 0.0, "Paused selection eases attention without animating biological work")
	var command_count: Array[int] = [0]
	view.humidity_command = func(count: int) -> Dictionary:
		command_count[0] += count
		return {"accepted": true}
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = view._humidity_rect(2).get_center()
	view._unhandled_input(touch)
	test.check(command_count[0] == 2, "Context staffing is immediately actionable during attention transition")
	view.activate_at(View.positions(view.get_viewport_rect().size).midden)
	view._process(0.07)
	test.check(view.selected_id == "midden" and view._focus_gains.nursery == 0.0 and view._focus_gains.midden > 0.0, "Rapid selection reverses attention without moving or blocking hit areas")
	view._process(1.0)
	test.check(view._focus_gains.midden == 1.0 and game.run.to_dict() == snapshot, "Attention settles with unchanged clock, ledger and RNG")
	status.paused = false
	status.time_scale = 1
	view._process(0.05)
	var first: float = view._animation_time
	status.time_scale = 64
	view._process(0.05)
	test.check(is_equal_approx(view._animation_time - first, first), "Decorative pulse has the same real-time pace at 1x and 64x")
	view.free()
	root.free()
	return true
