extends RefCounted
const Pressure = preload("res://src/presentation/colony_pressure.gd")
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Inward = preload("res://src/presentation/inward/inward_view.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
const Fixture = preload("res://tests/test_colony_activity.gd")

func run(test: Object) -> bool:
	test.check(Pressure.attention({}).is_empty(), "Healthy/absent internal pressure adds no attention control")
	var mixed: Dictionary = Fixture.new().stress()
	var before: Dictionary = mixed.duplicate(true)
	var attention: Dictionary = Pressure.attention(mixed)
	test.check(attention.organ == "nursery" and attention.causes == ["DRY", "REFUSE", "FOOD", "CARE"] and mixed == before, "Mixed known causes open Nursery without changing summaries or inventing a diagnosis")
	mixed.humidity.moisture = 90.0
	test.check(Pressure.nursery_causes(mixed)[0] == "DAMP", "Known dampness stays distinct from dryness")
	test.check(Pressure.attention({"midden": {"revealed": true, "larval_rate": 0.75}}).organ == "midden", "Refuse-only pressure opens its cleanup remedy")
	var root := Root.new()
	test.get_root().add_child(root)
	root.set_process(false)
	root.simulation = Controller.new(76)
	var view := Outward.new()
	root.add_child(view)
	root._outward_view = view
	view.signal_provider = root.sensory_snapshot.bind("home")
	view.status_provider = root.outward_status.bind("home")
	view.pressure_command = root.inspect_internal_pressure
	var inward := Inward.new()
	root.add_child(inward)
	root._inward_view = inward
	inward.status_provider = root.inward_status.bind("home")
	root.simulation.toggle_pause()
	var pile: PileState = root.simulation.run.colony.piles.home
	pile.nursery_state = "developed" # Fixture isolates known dry pressure; ordinary probe pays development.
	pile.humidity.moisture = 350000
	view._process(0)
	var snapshot: Dictionary = root.simulation.run.to_dict()
	var at: Vector2 = view._button_rect("internal_pressure").get_center()
	view.facing = 1.2
	view.selected_id = "remembered-selection"
	view.sources_open = true
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = at
	view._unhandled_input(touch)
	test.check(root.mode == "inward" and inward.selected_id == "nursery" and not view.sources_open, "Touch opens the currently strained function and closes outgoing browsing")
	test.check(root.simulation.run.to_dict() == snapshot and view.facing == 1.2 and view.selected_id == "remembered-selection", "Attention preserves paused simulation, RNG, ledger and outward attention")
	root.set_mode("outward")
	view.input_blocked = func() -> bool: return true
	view._unhandled_input(touch)
	test.check(root.mode == "outward", "Global modal shielding blocks pressure navigation")
	view.input_blocked = Callable()
	pile.humidity.moisture = 650000
	snapshot = root.simulation.run.to_dict()
	view._pointer_press(at, "mouse") # Cached badge, but navigation must revalidate current conditions.
	test.check(root.mode == "outward" and root.simulation.run.to_dict() == snapshot, "Stale pressure click cannot move attention or mutate the colony")
	view._process(0)
	test.check(view._button_at(at).is_empty(), "Recovered condition removes the attention target")
	pile.midden.revealed = true
	pile.midden.generated_units = 2000000
	view._process(0)
	view._pointer_press(at, "mouse")
	test.check(root.mode == "inward" and inward.selected_id == "midden", "Mouse opens refuse-only cleanup through the same command")
	var known: Dictionary = root.outward_status("home").internal_attention
	root.simulation.run.world.nodes.water_01.quantity = 0
	test.check(root.outward_status("home").internal_attention == known, "Private exterior depletion cannot change internal attention")
	root.start_new_colony(76)
	test.check(root.mode == "outward" and view._status.internal_attention.is_empty() and inward.selected_id.is_empty(), "New colony clears old pressure/context attention")
	root.free()
	return true
