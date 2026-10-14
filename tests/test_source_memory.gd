extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Memory = preload("res://src/presentation/outward/source_memory.gd")
const Fixture = preload("res://tests/test_persistent_chemistry.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	root.simulation = Fixture.new().experienced_game()
	var view: OutwardView = View.new()
	view.signal_provider = root.sensory_snapshot.bind("home")
	view.status_provider = root.outward_status.bind("home")
	test.get_root().add_child(view)
	view._process(0)
	var entries: Array[Dictionary] = Memory.entries(view._signals, view._status, "carbohydrate")
	test.check(entries.size() == 2 and entries[0].knowledge_id != entries[1].knowledge_id, "Browser lists distinct returned food memories")
	var before: Dictionary = root.simulation.run.to_dict()
	var evidence: Observation = root.simulation.run.knowledge.observations.values()[0].detached_copy()
	evidence.collective_search = true
	evidence.closest_distance = 3.60555124
	evidence.uncertainty_radius = 2.05277562
	var restored := Observation.new()
	test.check(restored.restore(JSON.parse_string(JSON.stringify(evidence.to_dict(), "", true, true)), root.simulation.run.world, root.simulation.run.colony, root.simulation.run.simulation_time) and restored.uncertainty_radius == evidence.uncertainty_radius, "Rounded collective observation cannot regain a legacy floating-point tail on reload")
	var remembered: Array[Dictionary] = entries.duplicate(true)
	root.simulation.run.world.nodes.carb_exposed.quantity = 0
	root.simulation.run.world.nodes.carb_exposed.active = false
	root.simulation.run.world.nodes.carb_sheltered.position += Vector2(2, 2)
	view._process(0)
	test.check(Memory.entries(view._signals, view._status, "carbohydrate") == remembered, "Hidden depletion/movement cannot update remembered sources")
	before = root.simulation.run.to_dict()
	view._pointer_press(view._button_rect("sources").get_center(), "touch")
	test.check(view.sources_open and not view.exploration_open, "Touch opens source attention")
	view._pointer_press(view._source_row_rect(1).get_center(), "mouse")
	test.check(view.selected_id == entries[1].id and view.facing == entries[1].bearing and not view.sources_open and root.simulation.run.to_dict() == before, "Mouse selects another returned memory without issuing gameplay commands")
	view._run_command("sources")
	view._pointer_press(view._source_filter_rect("water").get_center(), "touch")
	test.check(view.source_category == "water" and view.source_page == 0 and root.simulation.run.to_dict() == before, "Resource filter is free sensory attention")
	view._pointer_press(Vector2(25, 150), "mouse")
	test.check(root.simulation.run.to_dict() == before, "Panel background cannot click through to trails")
	# Pure projection fixture checks pagination beyond the authored backyard size.
	var signals: Array[Dictionary] = []
	for index: int in 7:
		var item: Dictionary = view._signals[0].duplicate(true)
		item.id = "signal:known:memory_%d" % index
		item.source_knowledge_id = "known:memory_%d" % index
		item.category = "carbohydrate"
		item.age = 9000.0
		signals.append(item)
	view._signals = signals
	view.source_category = "carbohydrate"
	var rows: int=view._source_rows()
	view._run_command("source_page")
	test.check(view.source_page == 1 and view._button_at(view._source_row_rect(rows-1).get_center()) == "source_entry_"+str(rows-1), "Seven old memories paginate with responsive accessible rows")
	while view.source_page<ceili(7.0/rows)-1: view._run_command("source_page")
	test.check(view.source_page == ceili(7.0/rows)-1 and (rows==1 or view._button_at(view._source_row_rect(1).get_center()) == "source_panel"), "Last partial page has no nonexistent selectable row")
	view._run_command("source_entry_0")
	test.check(view.selected_id == "signal:known:memory_6", "Aged memory stays selectable without confidence floor")
	view.free()
	root.free()
	return true
