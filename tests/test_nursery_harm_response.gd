extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_guest.gd")
const Pressure = preload("res://src/presentation/colony_pressure.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	test.get_root().add_child(root)
	root.set_process(false)
	root.simulation.advance(Fixture.CONFIG.first_tick * 0.25)
	test.check(root.outward_status("home").internal_attention.get("organ", "") != "guest", "Tolerated entry cannot announce unobserved harm")
	root.simulation = Fixture.new().loss_fixture()
	var outward := OutwardView.new()
	root.add_child(outward); root._outward_view = outward
	outward.status_provider = root.outward_status.bind("home")
	outward.signal_provider = root.sensory_snapshot.bind("home")
	outward.pressure_command = root.inspect_internal_pressure
	var inward := InwardView.new()
	root.add_child(inward); root._inward_view = inward
	inward.status_provider = root.inward_status.bind("home")
	var known: Dictionary = root.inward_status("home")
	test.check(Pressure.attention(known).organ == "guest" and "CAUSE UNCERTAIN" in Pressure.attention(known).causes[0], "First real brood loss directs voluntary attention without diagnosis")
	known.guest.observation = "foreign"
	known.humidity = {"larval_rate": 0.5, "moisture": 30.0}
	test.check("DRY" in Pressure.nursery_causes(known) and Pressure.attention(known).organ == "guest", "Harm navigation preserves coexisting Nursery climate evidence")
	root._refresh_loaded_views()
	root.set_mode("outward")
	var before: Dictionary = root.simulation.run.to_dict()
	outward._process(0)
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = outward._button_rect("internal_pressure").get_center()
	outward._unhandled_input(event)
	test.check(root.mode == "inward" and root._inward_view.selected_id == "guest" and root.simulation.run.to_dict() == before, "Actual touch opens harm controls without issuing an order")
	var view: InwardView = root._inward_view
	view.selected_id = "nursery"
	view._process(0)
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true; mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = view._guest_link_rect().get_center()
	view._unhandled_input(mouse)
	test.check(view.selected_id == "guest" and root.simulation.run.to_dict() == before, "Nursery mouse link shares free attention with OUTWARD")
	test.check(root.set_guest_rejection(true).accepted, "Known loss funds existing local rejection labor")
	test.check(ColonyPressure.needs(root.inward_status("home")).any(func(need: Dictionary) -> bool: return need.organ=="guest" and need.causes==["CLEARING EFFORT"]), "Assigned clearing remains inspectable among concurrent needs without obscuring untreated strain")
	root.simulation.advance(60.0)
	test.check(root.guest_summary("home").observation == "purged" and root.guest_summary("home").workers_committed == 0 and root.outward_status("home").internal_attention.get("organ", "") != "guest", "Purge settles urgency and releases workers; historical losses remain")
	root.simulation.advance(601.0)
	test.check(root.guest_summary("home").observation == "tolerated" and root.guest_summary("home").reported_losses == 0 and root.outward_status("home").internal_attention.get("organ", "") != "guest", "New tolerated encounter cannot inherit old alarm")
	root.free()
	return true
