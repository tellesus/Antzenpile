extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Memory = preload("res://src/presentation/outward/source_memory.gd")

func fixture() -> SimulationController:
	var game := Controller.new(6241)
	var site: WorldNodeState = game.run.world.nodes.nest_site_01
	site.position = Vector2(24.25, 22.25)
	game.run.world.nodes = {site.id:site}
	game.dispatch_scout("home", 0.0)
	var agent: ScoutAgent = game.run.scouts.scout_1
	agent.path.clear()
	for x: int in range(20,31): agent.path.append(Vector2(x,20))
	agent.mission_target = Vector2(30,20)
	return game

func run(test: Object) -> bool:
	var game := fixture()
	var colony := Root.new()
	colony.simulation = game
	var copy := Controller.new()
	var saw_private: bool = false
	var exact: bool = true
	for tick: int in 1200:
		game.advance(0.25)
		if not game.run.scouts.is_empty() and game.run.scouts.scout_1.observations.has("nest_site_01"):
			saw_private = true
			test.check(colony.sensory_snapshot("home").is_empty() and game.run.knowledge.nodes.is_empty(), "Private shelter sensing reveals nothing at Home")
			if not copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict()))): exact = false
			copy.advance(0.25)
			game.advance(0.25)
			exact = exact and copy.run.to_dict() == game.run.to_dict()
		if game.run.scouts.is_empty(): break
	test.check(saw_private and exact, "Nearby off-path shelter is sensed/localized with exact saved continuation")
	test.check(game.run.knowledge.nodes.has("known:nest_site_01") and game.run.colony.piles.home.workers_available == 40, "Scout returns a shelter report and releases its real worker")
	var signals: Array[Dictionary] = colony.sensory_snapshot("home")
	test.check(signals.size() == 1 and signals[0].category == "nest_site", "Returned shelter has a distinct approved sensory category")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.create_trail("home", "known:nest_site_01") and game.run.to_dict() == before, "Site cannot become a food route or spend gatherers")
	var forged := TrailRouteState.new()
	forged.id = "route_1"; forged.segment_id = "segment_1"
	forged.origin_pile = "home"; forged.destination_knowledge_id = "known:nest_site_01"
	forged.estimated_destination = game.run.knowledge.nodes[forged.destination_knowledge_id].estimated_position
	forged.desired_workers = 5; forged.allocated_workers = 5; forged.status = "active"
	var network := TrailNetwork.new()
	test.check(not network.restore({"next_route_id":2,"next_cohort_id":1,"routes":[forged.to_dict()],"segments":[],"cohorts":[]}, game.run.colony,game.run.knowledge,game.run.world,game.run.simulation_time), "Restore rejects a forged food route to a returned site")
	var view := View.new()
	test.get_root().add_child(view)
	view._signals = signals; view._status = colony.outward_status("home")
	view.sources_open = true
	view._pointer_press(view._source_filter_rect("nest_site").get_center(), "touch")
	test.check(view.source_category == "nest_site" and view._source_entries().size() == 1 and game.run.to_dict() == before, "Touch filters returned site memories without gameplay changes")
	view._pointer_press(view._source_row_rect(0).get_center(), "mouse")
	test.check(view.selected_id == signals[0].id and not view.sources_open and game.run.to_dict() == before, "Mouse selects a dated site report without claiming it")
	test.check(view._button_at(view._trail_button_rect("trail_create").get_center()) == "" and view._button_at(view._investigate_button_rect().get_center()) == "investigate", "Site context offers rechecking and no gathering action")
	test.check(Memory.receipt_label(view._source_entries()[0],game.run.simulation_time) == "Occupants and safety unknown", "Shelter memory invents no deliveries or guaranteed safety")
	game.run.world.nodes.nest_site_01.active = false
	test.check(colony.sensory_snapshot("home") == signals, "Hidden site change cannot refresh colony memory")
	view.investigate_command = colony.toggle_investigation_priority
	view._run_command("investigate")
	test.check(game.run.exploration.priorities == ["known:nest_site_01"] and view._feedback.contains("Site queued"), "Site recheck uses the existing editable exploration priority")
	test.check(game.investigate_known_source("home","known:nest_site_01"), "Known site estimate can be investigated by a real scout")
	for tick: int in 1200:
		game.advance(0.25)
		if game.run.scouts.is_empty(): break
	view._signals = colony.sensory_snapshot("home"); view._status = colony.outward_status("home")
	test.check(game.run.scouts.is_empty() and view._reported_empty(view._selected_signal()) and view._signal_caption(view._selected_signal()).contains("UNCONFIRMED"), "Only returned failed recheck changes the site cue")
	test.check(game.run.world.nodes.nest_site_01.quantity == 1 and game.run.colony.piles.home.resources == {"carbohydrate":10.0,"protein":5.0,"water":10.0}, "Investigating shelter creates no food cargo or extraction")
	var saved: Dictionary = game.run.to_dict()
	test.check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(saved))), "Returned site and priority restore")
	game.advance(10); copy.advance(10)
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.colony.piles.home.workers.invariant_holds(), "Site history continues exactly with conserved workers")
	var stable: Dictionary = game.run.to_dict()
	game.toggle_pause(); before = game.run.to_dict(); game.advance(30)
	test.check(game.run.to_dict() == before, "Pause leaves site evidence and rechecks unchanged")
	var scaled: Dictionary = {}
	for scale: int in [1,4,16,64]:
		var speed_game := Controller.new()
		test.check(speed_game.restore_snapshot(stable) and speed_game.set_time_scale(scale), "Saved site accepts supported speed")
		speed_game.advance(16.0 / scale)
		var result: Dictionary = speed_game.run.to_dict(); result.clock.scale = 1
		if scaled.is_empty(): scaled = result
		test.check(result == scaled, "Site history is speed-independent")
	var legacy := Controller.new().run.to_dict()
	for i: int in range(legacy.world.nodes.size()-1,-1,-1):
		if legacy.world.nodes[i].definition_id == "nest_site": legacy.world.nodes.remove_at(i)
	test.check(copy.restore_snapshot(legacy) and not copy.run.world.nodes.has("nest_site_01"), "Old worlds without sites remain valid and do not gain injected truth")
	var bad: Dictionary = saved.duplicate(true)
	bad.world.nodes[0].quantity = 2.0
	before = copy.run.to_dict()
	test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == before, "Malformed site availability rejects atomically")
	view.queue_free(); colony.free()
	return true
