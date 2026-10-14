extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Finder = preload("res://src/sim/scouting/scout_pathfinder.gd")
const CONFIG = preload("res://data/ecology/backyard_predator.tres")


func run(test: Object) -> bool:
	_test_missing(test)
	_test_recall_and_lateness(test)
	_test_shared_pressure(test)
	_test_profiles(test)
	return true


static func fixture(seed_value: int = 971) -> SimulationController:
	var game := Controller.new(seed_value)
	game.advance(300.0)
	for node: WorldNodeState in game.run.world.nodes.values():
		if node.id != "aphid_01": node.active = false
	var route: Array[Vector2] = Finder.new(game.run.world).path(game.run.colony.piles.home.position, CONFIG.position)
	assert(game.scouting._dispatch_route(game.run.colony.piles.home, route, false, PI / 4.0))
	return game


static func until_loss(game: SimulationController) -> bool:
	var private_evidence: bool = false
	for tick: int in 1000:
		if game.run.scout_losses.get("home", 0) > 0:
			return private_evidence
		private_evidence = private_evidence or not game.run.scouts.scout_1.observations.is_empty()
		game.advance(0.25)
	assert(false, "Fixture must physically cross the ambusher")
	return false


static func disk(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func _test_missing(test: Object) -> void:
	var game := fixture()
	var root := Root.new()
	root.simulation = game
	var pile: PileState = game.run.colony.piles.home
	var population: int = pile.workers_total
	game.run.world.nodes.carb_exposed.position = Vector2(29, 26)
	game.run.world.nodes.carb_exposed.active = true
	var had_evidence: bool = until_loss(game)
	var agent: ScoutAgent = game.run.scouts.scout_1
	test.check(agent.lost and pile.workers_total == population - 1 and pile.workers.count(agent.id) == 0 and pile.workers.lost_total == 1, "Scout crossing causes one conserved physical casualty")
	test.check(had_evidence and agent.observations.is_empty() and agent.investigating.is_empty() and game.run.knowledge.nodes.is_empty() and game.run.delivered_observations.is_empty(), "Lost scout discards actual private source discoveries instead of delivering them")
	test.check(root.inward_status("home").workers_total == population and root.outward_status("home").active_scouts == 1 and game.run.missing_scouts("home") == 0, "Away loss leaves expected population, capacity and missing history unchanged")
	var memory: Dictionary = root.scout_mission_summaries("home")[0]
	test.check(memory.awaiting and not memory.overdue and memory.missing_at == -1 and memory.course.is_empty() and not memory.has("lost"), "Normal mission exposes neither physical casualty nor private course")
	test.check(root.recall_scout(agent.id).accepted and agent.lost and game.run.scout_missions.scout_1.missing_at == -1, "Recall of unresolved absence has ordinary accepted feedback without an immediate death report")
	var saved: Dictionary = disk(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Private scout casualty restores exactly")
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(1000.0)
	test.check(game.run.to_dict() == paused, "Pause cannot settle a missing scout")
	game.toggle_pause()
	var wait: float = agent.expected_tick * SimulationClock.TICK_INTERVAL - game.run.simulation_time
	game.advance(wait - 0.25)
	test.check(game.run.scouts.has(agent.id) and game.run.scout_missions.scout_1.missing_at == -1, "Pending commitment and slot survive until the captured expectation")
	game.advance(0.25)
	copy.set_time_scale(4)
	copy.advance(wait / 4.0)
	copy.set_time_scale(1)
	test.check(copy.run.to_dict() == game.run.to_dict(), "Missing settlement and RNG continuation match across speeds")
	test.check(game.run.scouts.is_empty() and pile.workers.count(agent.id) == -1 and game.run.missing_scouts("home") == 1 and root.inward_status("home").workers_total == population - 1, "Expected return settles absence without freeing a dead worker into available labor")
	memory = root.scout_mission_summaries("home")[0]
	test.check(not memory.awaiting and memory.missing_at == memory.expected_at and memory.returned_at == -1 and memory.course.is_empty() and root.sensory_snapshot("home").is_empty(), "Missing report has direction and elapsed time but no resource, cause or course")
	test.check(copy.restore_snapshot(disk(game)), "Settled missing memory restores")
	for field: String in ["total", "ledger", "profile", "evidence", "deadline", "memory", "encounter"]:
		var invalid: Dictionary = saved.duplicate(true)
		match field:
			"total": invalid.scout_losses.home = 0
			"ledger": invalid.colony.piles[0].workers.commitments.scout_1.count = 1
			"profile": invalid.scouts[0].survival.profile = "persistent"
			"evidence": invalid.scouts[0].observations = [{"private": true}]
			"deadline": invalid.scouts[0].survival.expected_tick = 1
			"memory": invalid.scout_missions[0].missing_at = invalid.scout_missions[0].expected_at
			"encounter": invalid.scouts[0].survival.encountered = false
		var before: Dictionary = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Malformed survival rejects atomically: " + field)
	root.free()


func _test_recall_and_lateness(test: Object) -> void:
	var game := Controller.new(972)
	game.dispatch_scout("home", PI)
	game.advance(3.25)
	var agent: ScoutAgent = game.run.scouts.scout_1
	var available: int = game.run.colony.piles.home.workers_available
	test.check(game.recall_scout(agent.id) and agent.phase == "returning" and game.run.colony.piles.home.workers_available == available, "Recall begins physical travel instead of instantly refunding labor")
	game.advance(30.0)
	test.check(game.run.scouts.is_empty() and game.run.colony.piles.home.workers_available == available + 1 and game.run.scout_missions.scout_1.returned_at > 0, "Recalled survivor really returns and releases its worker")
	test.check(not game.recall_scout("scout_1") and not game.recall_scout("scout_999"), "Completed and unknown missions reject recall")
	var late := Controller.new(973)
	for node: WorldNodeState in late.run.world.nodes.values(): node.active = false
	for terrain: Dictionary in late.run.world.terrain: terrain.movement_cost = 100.0
	late.dispatch_scout("home", PI)
	late.advance(600.25)
	var root := Root.new()
	root.simulation = late
	var record: Dictionary = root.scout_mission_summaries("home")[0]
	test.check(record.overdue and record.awaiting and record.missing_at == -1 and late.run.colony.piles.home.workers.lost_total == 0, "A surviving late manual mission is overdue, never automatically killed")
	test.check(late.recall_scout("scout_1"), "Player can recall an overdue surviving scout")
	late.advance(800.0)
	test.check(late.run.scout_missions.scout_1.returned_at > record.expected_at and late.run.scout_losses.is_empty(), "Late scout may still return safely after expectation")
	var legacy := Controller.new(974)
	legacy.dispatch_scout("home", PI)
	var saved: Dictionary = disk(legacy)
	saved.erase("scout_losses")
	saved.scouts[0].erase("survival")
	saved.scout_missions[0].erase("expected_at")
	saved.scout_missions[0].erase("missing_at")
	test.check(legacy.restore_snapshot(saved) and legacy.run.scouts.scout_1.expected_tick == 0 and legacy.run.scout_missions.scout_1.expected_at == -1, "Older saves keep unknown expectation and baseline survival")
	for kind: String in ["mouse", "touch"]:
		var ui_game := Controller.new(975)
		ui_game.dispatch_scout("home", PI)
		root.simulation = ui_game
		var view: OutwardView = View.new()
		test.get_root().add_child(view)
		view.status_provider = root.outward_status.bind("home")
		view.signal_provider = root.sensory_snapshot.bind("home")
		view.scout_recall_command = root.recall_scout
		view.selected_id = "mission:scout_1"
		view._process(0)
		view._pointer_press(view._scout_recall_rect().get_center(), kind)
		view._pointer_release(view._scout_recall_rect().get_center(), kind)
		test.check(ui_game.run.scouts.scout_1.phase == "returning" and view.selected_id == "mission:scout_1" and view._scout_recall_rect().size.y >= 44, "Recall shares mouse/touch action and stable selection: " + kind)
		view.free()
	root.free()


func _test_shared_pressure(test: Object) -> void:
	var safe := fixture(976)
	safe.run.predator.last_attack_tick = safe.run.clock.tick_count
	safe.run.predator.kills_total = 1 # Saturation fixture; not a save-validation fixture.
	safe.advance(25.0)
	test.check(safe.run.scouts.scout_1.predator_encountered and not safe.run.scouts.scout_1.lost, "Scout consumes its one encounter opportunity when existing predator is saturated")
	safe.advance(100.0)
	test.check(safe.run.scouts.is_empty() and safe.run.scout_losses.is_empty() and safe.run.knowledge.nodes.has("known:aphid_01"), "Saturated scout returns real evidence without a delayed second attack")
	var defeated := fixture(977)
	defeated.run.predator.resistance = 0
	defeated.run.predator.defeated_at = 300.0
	defeated.advance(150.0)
	test.check(defeated.run.scout_losses.is_empty() and defeated.run.scout_missions.scout_1.returned_at > 0, "Existing defeated ambusher no longer kills scouts")
	var late := fixture(9771)
	late.run.scouts.scout_1.expected_tick = late.run.clock.tick_count + 1
	late.run.scout_missions.scout_1.expected_at = late.run.scouts.scout_1.expected_tick * 0.25
	until_loss(late)
	test.check(late.run.scouts.has("scout_1") and late.run.missing_scouts("home") == 0 and late.run.pending_for_pile("home") == 1, "Already-overdue casualty still has a grace period instead of an instant population leak")
	test.check(Controller.new().restore_snapshot(disk(late)), "Private late-loss grace restores while original public expectation stays unchanged")
	var standing := fixture(978)
	standing.run.scouts.scout_1.standing = true
	standing.run.exploration.target = 1
	until_loss(standing)
	var id: int = standing.run.next_scout_id
	var expectation: int = standing.run.scouts.scout_1.expected_tick
	standing.advance(1.0)
	test.check(standing.run.next_scout_id == id, "Standing effort cannot instantly replace an unreported death")
	standing.advance(expectation * 0.25 - standing.run.simulation_time + 2.0)
	test.check(standing.run.next_scout_id > id and standing.run.missing_scouts("home") == 1, "Standing effort replaces a missing scout from real available workers after settlement")
	test.check(standing.set_exploration(0) and Controller.new().restore_snapshot(disk(standing)), "Lowering effort with survivors or private loss preserves a valid save")


func _test_profiles(test: Object) -> void:
	var game := fixture(979)
	var pile: PileState = game.run.colony.piles.home
	# A consistent emerged-cohort fixture supplies one overlapping phenotype bundle.
	var cohort := BroodCohort.new()
	cohort.count = 8
	cohort.inherited_traits.assign(["lean", "persistent"])
	cohort.adaptation_id = "lean"
	cohort.adaptation_trial = true
	pile.genetics.established.assign(["persistent"])
	pile.rain_trace_observed = true
	pile.chemistry_candidate = true
	game.run.rain.phase = "raining"
	assert(pile.workers.add_living_workers("available", 8, "Test emergence"))
	pile.register_emergence(cohort)
	pile.brood_matured_total += 8
	pile.brood_started_total += 1
	pile.brood_cohorts[0].id = "brood_2"
	while game.run.scouts.scout_1.position.distance_to(CONFIG.position) > 2.25:
		game.advance(0.25)
	var draw := RandomNumberGenerator.new()
	for seed_value: int in range(1, 100):
		draw.seed = seed_value
		var state: int = draw.state
		if draw.randf() < pile.adaptation_fraction():
			game.run.rng.state = state
			break
	until_loss(game)
	test.check(game.run.scouts.scout_1.lost_profile == "lean+persistent", "Seeded scout casualty can remove a real overlapping phenotype bundle")
	var expected: int = pile.workers_total + game.run.pending_for_pile("home")
	test.check(expected == 48 and pile.workers_total == 47 and game.run.pending_for_pile("home") == 1, "Scout loss preserves expected baseline plus emerged population")
	for trait_id: String in ["lean", "persistent"]:
		test.check(pile.genetics.count_trait(trait_id) + game.run.pending_trait("home", trait_id) == 8, "Unreturned scout loss preserves expected overlapping expression: " + trait_id)
	test.check(Controller.new().restore_snapshot(disk(game)), "Pending scout phenotype loss restores with joint expression conserved")
