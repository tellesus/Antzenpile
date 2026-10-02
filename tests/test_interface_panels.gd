extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Fixture = preload("res://tests/test_persistent_chemistry.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	root.simulation = Fixture.new().experienced_game()
	var view := View.new()
	view.signal_provider = root.sensory_snapshot.bind("home")
	view.status_provider = root.outward_status.bind("home")
	test.get_root().add_child(view)
	view._process(0)
	var before: Dictionary = root.simulation.run.to_dict()
	for kind: String in ["mouse", "touch"]:
		for panel: String in ["sources", "exploration", "source", "journey", "mission"]:
			view.sources_open = panel == "sources"
			view.exploration_open = panel == "exploration"
			view.journey_open = panel == "journey"
			view.selected_id = view._signals[0].id if panel in ["source", "journey"] else "mission:scout_a" if panel == "mission" else ""
			view._status.scout_missions = [{"id": "scout_a"}]
			var at: Vector2 = Vector2(120, 180) if panel in ["sources", "exploration"] else Vector2(view.get_viewport_rect().size.x - 180, 210)
			var facing: float = view.facing
			var selected: String = view.selected_id
			view._pointer_press(at, kind)
			view._pointer_drag(at + Vector2(60, 0))
			view._pointer_release(at + Vector2(60, 0), kind)
			test.check(view.facing == facing and view.selected_id == selected, "%s %s panel absorbs drags" % [kind, panel])
			view._pointer_press(at, kind)
			view._pointer_release(at, kind)
			test.check(view.selected_id == selected, "%s %s panel absorbs background taps" % [kind, panel])
		view.sources_open = false
		view.exploration_open = false
		view.journey_open = false
		view.selected_id = ""
		view._status.scout_missions = []
		var facing: float = view.facing
		view._pointer_press(Vector2(400, 210), kind)
		view._pointer_drag(Vector2(460, 210))
		view._pointer_release(Vector2(460, 210), kind)
		test.check(view.facing != facing, "%s exposed field still rotates" % kind)
		view._pointer_press(Vector2(400, 210), kind)
		view._pointer_press(view._button_rect("sources").get_center(), kind)
		test.check(view.sources_open and view._pointer_kind.is_empty(), "Opening a panel cancels stale %s field gesture" % kind)
	test.check(root.simulation.run.to_dict() == before, "Panel attention does not mutate simulation")
	view.free()
	root.free()
	return true
