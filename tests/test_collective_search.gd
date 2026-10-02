extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const Reports = preload("res://tests/test_knowledge.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")


func run(test: Object) -> bool:
	var game := Controller.new(6161)
	game.set_exploration(1)
	game.advance(7)
	var agent: ScoutAgent = game.run.scouts.values()[0]
	test.check(agent.return_path.size() > 1 and game.run.exploration.coverage.is_empty(), "Away footprints remain private, even in collective search")
	var needs: Dictionary = agent.need_weights.duplicate()
	game.run.colony.piles.home.deposit_resource("water", 10)
	game.run.exploration.coverage["0:0"] = 1.0
	test.check(agent.need_weights == needs and agent.search_memory.is_empty(), "Home needs and new shared coverage cannot telepathically alter an away scout")
	game.run.exploration.coverage.clear()
	game.set_exploration(0)
	game.advance(40)
	test.check(not game.run.exploration.coverage.is_empty() and game.run.scouts.is_empty() and game.run.colony.piles.home.workers_available == 40, "Only a real return records coarse search memory and releases labor")
	var dry := ExplorationState.new()
	var wet := ExplorationState.new()
	dry.coverage["0:0"] = 1.0
	wet.coverage["0:0"] = 1.0
	dry.decay(120, false)
	wet.decay(120, true)
	test.check(is_equal_approx(wet.coverage["0:0"], 0.5) and dry.coverage["0:0"] > wet.coverage["0:0"], "Rain makes returned search memory stale faster than dry time")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Returned coarse coverage survives JSON restore")
	var before: Dictionary = copy.run.to_dict()
	for malformed: Dictionary in [{"coverage": {"-1:0": 1.0}}, {"coverage": {"999:0": 1.0}}, {"coverage": {"0:0": INF}}, {"priorities": ["known:missing"]}, {"priority_last_sent": {"known:missing": 0.0}}, {"priority_cursor": 9}]:
		var bad: Dictionary = Snapshot.new().snapshot(game)
		bad.exploration.merge(malformed, true)
		test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == before, "Malformed shared memory/priority rejects atomically")
	var legacy: Dictionary = Snapshot.new().snapshot(game)
	legacy.exploration = {"target": 0, "bias": null, "cooldown_ticks": 0}
	test.check(copy.restore_snapshot(legacy) and copy.run.exploration.coverage.is_empty(), "Card-060 policy restores with empty collective memory")
	var reports := Reports.new()
	var sensory := Controller.new(6160)
	var choosing := ScoutAgent.new()
	choosing.origin_pile = "home"
	choosing.standing = true
	var carb: Observation = reports.evidence("scout_1", 0, 2, false)
	carb.closest_distance = 2
	var water: Observation = reports.evidence("scout_1", 0, 2, false)
	water.source_node_id = "water_01"
	water.definition_id = "water"
	water.closest_distance = 3
	choosing.observations = {"carb_exposed": carb, "water_01": water}
	choosing.need_weights = {"water": 4.0, "carbohydrate": 1.0}
	test.check(sensory.scouting._new_source_cue(choosing) == "water_01", "Captured colony needs favor a physically sensed water cue over a slightly closer food cue")
	choosing.observations.erase("water_01")
	test.check(sensory.scouting._new_source_cue(choosing) == "carb_exposed", "Need cannot target a resource the scout has not physically sensed")
	choosing.position = sensory.run.colony.piles.home.position
	choosing.return_path = [choosing.position]
	var initial_path: Array[Vector2] = sensory.scouting._frontier_path(choosing, choosing.position, -1)
	choosing.search_memory[sensory.run.exploration.cell_key(initial_path.back(), sensory.run.world.bounds)] = 1.0
	var alternate_path: Array[Vector2] = sensory.scouting._frontier_path(choosing, choosing.position, -1)
	test.check(alternate_path.back() != initial_path.back(), "Captured recently covered ground changes frontier choice without reading source locations")
	var knowledge := KnowledgeBase.new()
	var first: Observation = reports.evidence("scout_1", 10, 1, true)
	first.collective_search = true
	reports.deliver(knowledge, first, 20)
	var known: KnownNode = knowledge.nodes["known:carb_exposed"]
	var confidence: float = known.confidence
	test.check(confidence >= 0.65, "One convincing close encounter is usable without mandatory revisits")
	var second: Observation = reports.evidence("scout_2", 11, 1, true)
	second.collective_search = true
	second.estimated_position += Vector2(0.25, 0)
	reports.deliver(knowledge, second, 20)
	known = knowledge.nodes["known:carb_exposed"]
	test.check(known.confidence > confidence and known.uncertainty_radius < 1 and known.confidence <= 0.95, "Independent compatible accounts improve bounded confidence and localization")
	before = knowledge.to_dict()
	reports.deliver(knowledge, second, 30)
	test.check(knowledge.to_dict() == before, "Repeated delivery of one account cannot corroborate itself")
	var contradictory: Observation = reports.evidence("scout_3", 12, 1, true)
	contradictory.collective_search = true
	contradictory.estimated_position = Vector2(5, 5)
	reports.deliver(knowledge, contradictory, 30)
	test.check(knowledge.nodes["known:carb_exposed"].confidence < confidence, "Recent contradictory accounts reduce certainty instead of averaging distant locations")
	var stale: Observation = reports.evidence("scout_4", 400, 1, true)
	stale.collective_search = true
	reports.deliver(knowledge, stale, 410)
	test.check(is_equal_approx(knowledge.nodes["known:carb_exposed"].confidence, confidence) and knowledge.nodes["known:carb_exposed"].uncertainty_radius == 1, "Old reports add history without corroborating a fresh encounter")
	game = Controller.new(6162)
	game.run.clock.advance(20)
	first = reports.evidence("scout_1", 10)
	game.run.next_scout_id = 3
	reports.deliver(game.run.knowledge, first, 20)
	var other: Observation = reports.evidence("scout_2", 10)
	other.source_node_id = "water_01"
	other.definition_id = "water"
	other.id = "scout_2:water_01"
	other.estimated_position = Vector2(25, 20)
	reports.deliver(game.run.knowledge, other, 20)
	test.check(game.set_investigation_priority("known:carb_exposed", true) and game.set_investigation_priority("known:water_01", true), "Known sources accept standing investigation priorities")
	game.advance(5)
	test.check(game.run.scouts.is_empty(), "Queued priorities do not create exploration labor while effort is off")
	game.set_exploration(5)
	var investigated: Dictionary = {}
	var general: bool = false
	for tick: int in 2000:
		game.advance(0.25)
		var count: int = 0
		for scout: ScoutAgent in game.run.scouts.values():
			if scout.investigation_source_id.is_empty():
				general = true
			else:
				count += 1
				investigated[scout.investigation_source_id] = true
		assert(count <= 2)
	test.check(general and investigated.size() == 2 and game.run.exploration.priority_last_sent.size() == 2, "Priorities rotate fairly while reserving effort for novelty")
	test.check(game.run.colony.piles.home.workers.invariant_holds(), "Recurring investigations conserve the authoritative worker ledger")
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Corroborated history and recurring priorities restore together")
	game.advance(64)
	copy.set_time_scale(64)
	copy.advance(1)
	copy.set_time_scale(1)
	test.check(copy.run.to_dict() == game.run.to_dict(), "Collective investigations continue exactly across saves and 64x time")
	var root := Root.new()
	root.simulation = game
	var view := View.new()
	test.get_root().add_child(view)
	view.investigate_command = root.toggle_investigation_priority
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	var selected: Dictionary = {}
	for signal_data: Dictionary in view._signals:
		if signal_data.source_knowledge_id == "known:carb_exposed":
			selected = signal_data
	view.selected_id = selected.id
	test.check(view._investigation_title(selected).begins_with("STOP PRIORITY"), "Selected prioritized trace names its persistent state")
	view._pointer_press(view._investigate_button_rect().get_center(), "touch")
	view._status = root.outward_status("home")
	test.check(view._investigation_title(selected).begins_with("PRIORITIZE"), "Touch removes priority rather than sending another one-shot scout")
	view._pointer_press(view._investigate_button_rect().get_center(), "mouse")
	test.check(selected.source_knowledge_id in game.run.exploration.priorities, "Mouse restores the same standing priority")
	view.free()
	root.free()
	return true
