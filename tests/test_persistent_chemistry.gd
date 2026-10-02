extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const TRAILS = preload("res://data/trails/default_trails.tres")


func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func experienced_game(seed_value: int = 3020) -> SimulationController:
	var game := Controller.new(seed_value)
	var pile: PileState = game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 250.0)
	game.dispatch_scout("home", 0.0)
	game.dispatch_scout("home", PI)
	game.advance(100.0)
	game.create_trail("home", "known:carb_exposed")
	game.create_trail("home", "known:carb_sheltered")
	for tick: int in 600:
		if pile.rain_trace_observed:
			break
		game.advance(0.25)
	game.set_trail_workers("route_1", 0)
	game.set_trail_workers("route_2", 0)
	game.advance(400.0)
	return game


func candidate_game(seed_value: int = 3020) -> SimulationController:
	var game := experienced_game(seed_value)
	var pile: PileState = game.run.colony.piles.home
	for attempt: int in 8:
		if pile.chemistry_candidate:
			break
		game.start_brood("home")
		game.advance(360.0)
	return game


func run(test: Object) -> bool:
	_test_opportunity(test)
	for trait_id: String in ["lean", "load"]:
		_test_combination(test, trait_id)
	_test_chemistry(test)
	_test_capture_and_loss(test)
	_test_ui(test)
	return true


func _test_opportunity(test: Object) -> void:
	var early := Controller.new(5701)
	var root := Root.new()
	root.simulation = early
	var before: Dictionary = early.run.to_dict()
	test.check(not early.start_adaptation("home", "persistent") and early.run.to_dict() == before and not root.inward_status("home").adaptation_options.has("persistent"), "Unobserved chemistry candidate has neither action nor hidden graph leaf")
	var game := experienced_game()
	var pile: PileState = game.run.colony.piles.home
	root.simulation = game
	test.check(pile.rain_trace_observed and not pile.chemistry_candidate and pile.genetics.established.is_empty(), "Rain and returned wet-route evidence do not purchase or reveal a trait alone")
	test.check(game.start_brood("home") and pile.brood_cohorts[0].rain_comparison and not pile.chemistry_candidate, "Brood laid after returned pressure captures a variation comparison")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Pressure-bearing comparison saves before its emergence")
	var old_rng: int = game.run.rng.state
	game.advance(360.0)
	copy.set_time_scale(4)
	copy.advance(90.0)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.rng.state == old_rng, "Brood variation uses a saved genetic stream without perturbing scout/ecology RNG")
	print("[GENETICS] first rain comparison candidate=", pile.chemistry_candidate)
	for attempt: int in 7:
		if pile.chemistry_candidate:
			break
		game.start_brood("home")
		game.advance(360.0)
	test.check(pile.chemistry_candidate and pile.genetics.established.is_empty() and root.inward_status("home").adaptation_options.has("persistent"), "Surviving brood can reveal a selectable candidate without adult expression")
	before = game.run.to_dict()
	pile.resources.protein = 15.0
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", "persistent") and game.run.to_dict() == before, "Chemistry trial resource rejection is atomic")
	pile.deposit_resource("protein", 100.0)
	var stores: Dictionary = pile.resources.duplicate()
	test.check(game.start_adaptation("home", "persistent") and pile.workers.count("adaptation:home") == 2 and is_equal_approx(pile.resources.carbohydrate, stores.carbohydrate - 14) and is_equal_approx(pile.resources.protein, stores.protein - 16) and is_equal_approx(pile.resources.water, stores.water - 8), "Chemistry trial pays authored stores and commits two real nurses")
	test.check(pile.chemistry_fraction() == 0 and pile.genetics.established.is_empty(), "Starting chemistry trial has no immediate genes or secretion benefit")
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", "lean") and game.run.to_dict() == before, "Independent trait branches still share one focused trial slot")
	game.advance(360.0)
	test.check(pile.genetics.established == ["persistent"] and pile.genetics.count_trait("persistent") == 8 and pile.adaptation_repertoire == "", "Chemistry can establish before a foraging choice without falsely creating foraging adults")
	var invalid: Dictionary = snapshot(game)
	invalid.colony.piles[0].genetics.living.persistent = 7
	test.check(not copy.restore_snapshot(invalid), "Impossible non-cohort chemistry lifetime rejects without immature-loss history")
	test.check(game.start_adaptation("home", "load"), "Foraging selection remains available after independent chemistry establishment")
	invalid = snapshot(game)
	invalid.colony.piles[0].brood_cohorts[0].inherited_traits = ["load"]
	test.check(not copy.restore_snapshot(invalid), "Focused trial cannot discard already established independent genes")
	root.free()


func _test_combination(test: Object, trait_id: String) -> void:
	var game := candidate_game()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.start_adaptation("home", trait_id), "Combination begins foraging trial: " + trait_id)
	game.advance(360.0)
	test.check(game.start_adaptation("home", "persistent") and pile.trial_cohort().inherited_traits == ([trait_id, "persistent"] if trait_id == "load" else ["lean", "persistent"]), "Second trial captures joint inherited phenotype: " + trait_id)
	game.advance(180.0)
	var trial: BroodCohort = pile.trial_cohort()
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Joint trial saves with nurses and captured genes")
	game.advance(180.0)
	copy.set_time_scale(16)
	copy.advance(11.25)
	copy.set_time_scale(1)
	var key: String = GeneticRepertoire.profile([trait_id, "persistent"])
	var survivors: int = trial.count
	test.check(game.run.to_dict() == copy.run.to_dict() and survivors > 0 and survivors < 8 and pile.genetics.living.get(key) == survivors and pile.genetics.count_profiles() == 8 + survivors and pile.adapted_workers_total == 8 + survivors, "Surviving joint trial shares one disjoint bundle and exact continuation under guest pressure")
	test.check(game.set_trail_workers("route_1", 5), "Joint expression can fund ordinary traffic")
	var stores: float = pile.resources.carbohydrate
	game.advance(0.25)
	var cohort: TransitCohort = game.run.trails.cohorts.values()[0]
	var segment: TrailSegmentState = game.run.trails.segments.segment_1
	var base_cost: float = TRAILS.round_trip_energy_cost(5, segment.start.distance_to(segment.end), TrailSegmentState.terrain_cost_for(game.run.world, segment.start, segment.end))
	var expected_cost: float = base_cost * cohort.energy_multiplier * (1.0 + AdaptationRules.CHEMISTRY.extra_travel_energy * cohort.chemistry_fraction)
	test.check(cohort.chemistry_fraction > 0 and absf(stores - pile.resources.carbohydrate - expected_cost) < 0.00001, "Captured secretion share pays extra travel carbohydrate alongside " + trait_id)
	var captured: float = cohort.chemistry_fraction
	test.check(pile.lose_workers("available", 1, 1, "Known joint phenotype loss", key) and pile.genetics.count_trait("persistent") == survivors - 1 and pile.adapted_workers_total == 7 + survivors and pile.workers.lost_total == 1, "One joint adult loss reduces both trait expressions but only one worker")
	test.check(cohort.chemistry_fraction == captured and copy.restore_snapshot(snapshot(game)), "Journey keeps captured secretion after adult expression falls")
	for field: String in ["profiles", "candidate", "rain", "chemistry", "rng", "mixture"]:
		var invalid: Dictionary = snapshot(game)
		match field:
			"profiles": invalid.colony.piles[0].genetics.living[key] = 8
			"candidate": invalid.colony.piles[0].chemistry_candidate = false
			"rain": invalid.colony.piles[0].rain_trace_observed = false
			"chemistry": invalid.trails.cohorts[0].chemistry_fraction = 2.0
			"rng": invalid.genetic_rng_state = 0.5
			"mixture": invalid.trails.segments[0].persistent_chemistry = 1.1
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Malformed combined genetics rejects atomically: " + field)
	game.set_trail_workers("route_1", 0)
	game.advance(100.0)
	test.check(segment.persistent_chemistry > 0 and segment.persistent_chemistry <= segment.pheromone_strength, "Only a loaded home return reinforces durable chemistry")
	test.check(game.start_guest_rejection(), "Combined genetics run responds to reported internal brood losses")
	game.advance(180.0)
	test.check(game.run.guest.observation == "purged", "Ordinary rejection protects future inherited brood")
	test.check(game.start_brood("home") and pile.brood_cohorts[0].inherited_traits == GeneticRepertoire.traits_for(key), "Later ordinary brood captures both established traits")
	game.advance(360.0)
	test.check(pile.genetics.count_trait("persistent") == survivors + 7 and pile.adapted_workers_total == survivors + 15 and copy.restore_snapshot(snapshot(game)), "Joint inheritance and adult loss histories conserve lifetime emergence")


func _test_chemistry(test: Object) -> void:
	var baseline := TrailSegmentState.new()
	var durable := TrailSegmentState.new()
	baseline.reinforce_chemistry(0.8, 0.0)
	durable.reinforce_chemistry(0.8, 1.0)
	baseline.decay_chemistry(1.0)
	durable.decay_chemistry(1.0)
	test.check(is_equal_approx(baseline.pheromone_strength, 0.4) and durable.pheromone_strength > baseline.pheromone_strength, "Authored persistent component fades more slowly through baseline or exposed rain decay")
	durable.reinforce_chemistry(2.0, 0.0)
	test.check(durable.pheromone_strength == 1 and durable.persistent_chemistry < 0.5, "Saturation blends ordinary incoming secretion rather than upgrading all scent")
	durable.decay_chemistry(100.0)
	test.check(durable.pheromone_strength == 0 and durable.persistent_chemistry == 0, "Durable trail chemistry still eventually disappears")
	var old: Dictionary = snapshot(Controller.new(5702))
	old.erase("genetic_rng_state")
	old.colony.piles[0].erase("rain_trace_observed")
	old.colony.piles[0].erase("chemistry_candidate")
	for record: Dictionary in old.colony.piles[0].brood_cohorts:
		record.erase("rain_comparison")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(old) and not copy.run.colony.piles.home.chemistry_candidate, "Old saves default genetic pressure and stream without invented opportunities")


func _test_capture_and_loss(test: Object) -> void:
	var game := candidate_game()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.start_nursery_development("home"), "Overlapping-trait fixture develops real Nursery capacity")
	game.advance(90.0)
	test.check(game.start_adaptation("home", "persistent") and game.start_brood("home"), "Focused trial and ordinary brood can use separate developed Nursery slots")
	var ordinary: BroodCohort = pile.brood_cohorts[1]
	test.check(ordinary.inherited_traits.is_empty(), "Ordinary brood laid before establishment retains its captured baseline")
	game.advance(360.0)
	test.check("persistent" in pile.genetics.established and pile.genetics.count_profiles() < pile.brood_matured_total and ordinary.inherited_traits.is_empty(), "Parallel ordinary brood is not retrofitted when another cohort establishes genes")
	var starved := candidate_game()
	var starved_pile: PileState = starved.run.colony.piles.home
	starved.advance(800.0)
	test.check(starved.start_adaptation("home", "persistent") and starved_pile.consume_resources({"protein": starved_pile.resources.protein}), "Fully-lost trial fixture spends real resources before larval food shortage")
	starved.advance(200.0)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(starved)), "Food-stalled partial trial saves while the guest remains harmful")
	var genetic_rng: int = starved.run.genetic_rng.state
	starved.advance(600.0)
	copy.set_time_scale(64)
	copy.advance(9.375)
	copy.set_time_scale(1)
	test.check(starved.run.to_dict() == copy.run.to_dict() and starved_pile.trial_cohort() == null and starved_pile.genetics.established.is_empty() and starved_pile.chemistry_candidate and starved_pile.workers.count("adaptation:home") == -1, "Wholly lost trial releases nurses and retains only a candidate with exact accelerated continuation")
	test.check(starved.run.genetic_rng.state == genetic_rng and starved_pile.chemistry_fraction() == 0, "Wholly lost trial cannot establish expression or roll surviving variation")
	starved.toggle_pause()
	var paused: Dictionary = starved.run.to_dict()
	starved.advance(20.0)
	test.check(starved.run.to_dict() == paused, "Pause freezes genetic pressure, brood and chemistry along with the run")


func _test_ui(test: Object) -> void:
	var root := Root.new()
	root.simulation = candidate_game()
	var view := View.new()
	test.get_root().add_child(view)
	view.status_provider = func() -> Dictionary: return root.inward_status("home")
	view.adaptation_command = root.start_adaptation
	view._process(0.0)
	view.selected_id = "adaptation"
	var before: Dictionary = root.simulation.run.to_dict()
	# Layout fixture includes the conditional fifth leaf, using delivered-style data only.
	view._status.honeydew = {"relationship": "unknown"}
	for size: Vector2 in [Vector2(1280,720), Vector2(900,600)]:
		var points: Dictionary = Web.positions(size)
		var ids: Array[String] = Web.visible_nodes(view._status)
		for id: String in ids:
			test.check(Web.node_at(points[id], size, view._status) == id and points[id].x + 44 < size.x - 316 and points[id].y + 64 < size.y - 104, "Expanded graph has separated touch targets/context: " + id)
			for other: String in ids:
				if id < other:
					test.check(points[id].distance_to(points[other]) > 88, "Expanded graph touch targets do not overlap")
	view.web_selection = "persistent"
	test.check(root.simulation.run.to_dict() == before and view._can_choose_adaptation(), "Candidate inspection is free and has one contextual action")
	test.check(view.activate_at(view._adaptation_rect("persistent").get_center()), "Shared mouse/touch action targets the selected chemistry trait")
	view._process(0.0)
	test.check(not view._can_choose_adaptation() and root.simulation.run.colony.piles.home.trial_cohort().adaptation_id == "persistent", "Contextual command starts biology and disables duplicate purchase")
	view.free()
	root.free()

