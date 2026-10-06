extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const ObservationFixture = preload("res://tests/test_observations.gd")
const AdaptationFixture = preload("res://tests/test_adaptation_queue.gd")
const DaughterFixture = preload("res://tests/test_daughter_gathering.gd")
const Root = preload("res://src/core/game_root.gd")
const DefenseFixture = preload("res://tests/test_ambusher_defense.gd")

func gathered() -> SimulationController:
	var game: SimulationController = ObservationFixture.new().fixture()
	game.advance(85)
	for resource: String in PileState.RESOURCE_IDS: game.run.colony.piles.home.deposit_resource(resource, 500)
	game.create_trail("home", "known:carb_exposed")
	return game

func legacy_stalled() -> SimulationController:
	var game := gathered()
	var pile: PileState = game.run.colony.piles.home
	game.set_trail_workers("route_1", 38)
	# Reproduce a valid pre-safeguard assignment, without inventing workers/deaths.
	pile.workers.allocate("trail:route_1", 2)
	var route: TrailRouteState = game.run.trails.routes.route_1
	route.allocated_workers = 40; route.desired_workers = 40
	while route.active_workers < route.allocated_workers: game.trails._depart(route)
	game.advance(0.25)
	return game

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func run(test: Object) -> bool:
	var game := gathered()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.set_trail_workers("route_1",38) and pile.workers_available == 2 and pile.workers_assignable == 0, "Gathering may use every free worker while preserving two real carers")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.dispatch_scout("home",0.0) and not game.start_nursery_development("home") and game.run.to_dict() == before, "Scout and chamber orders cannot take the last carers or partially spend")
	var pools: Dictionary = pile.workers.to_dict()
	var stores: Dictionary = pile.resources.duplicate(true)
	test.check(game.set_trail_workers("route_1",39) and game.run.trails.routes.route_1.waiting_workers == 1 and pile.workers.to_dict() == pools and pile.resources == stores and pile.workers_available == 2, "Unfunded gathering waits without spending resources or protected care")
	game.scouting.set_effort(8)
	var twin := Controller.new()
	test.check(twin.restore_snapshot(snapshot(game)), "Saturated care-protected commitments restore without a new saved pool")
	game.advance(300); twin.advance(300)
	test.check(game.run.to_dict() == twin.run.to_dict() and pile.brood_matured_total == 8 and pile.workers.invariant_holds(), "Automatic scouts do not steal care; physical brood emergence breaks saturation exactly")

	game = legacy_stalled(); pile = game.run.colony.piles.home
	test.check(pile.workers_available == 0 and pile.brood_cohorts[0].care == 0, "Pre-safeguard save can genuinely have all workers away and stalled brood")
	twin = Controller.new()
	test.check(twin.restore_snapshot(snapshot(game)), "Already-stalled existing saves remain valid")
	var plan: Dictionary = game.brood_care.plan("home")
	test.check(plan.get("kind") == "gatherers" and plan.target == 38 and game.brood_care.apply("home",plan), "Recovery explicitly reduces a named gathering assignment by two")
	test.check(pile.workers_available == 0 and game.run.trails.routes.route_1.desired_workers == 38, "Away caregivers must return physically; click creates no workers")
	before = game.run.to_dict()
	test.check(game.brood_care.plan("home").get("kind") == "returning" and not game.brood_care.apply("home",plan) and before == game.run.to_dict(), "Pending recall avoids repeated reductions or stealing another assignment")
	twin = Controller.new()
	test.check(twin.restore_snapshot(snapshot(game)), "Pending care recovery restores with the ordinary trail recall state")
	for tick: int in 800:
		game.advance(0.25); twin.advance(0.25)
		if pile.workers_available >= 2: break
	test.check(pile.workers_available >= 2 and pile.brood_cohorts[0].care == 1 and game.run.to_dict() == twin.run.to_dict(), "Real returned workers restore care, remain protected and match saved continuation")
	before = game.run.to_dict()
	test.check(not game.brood_care.apply("home",plan) and game.run.to_dict() == before, "Stale care relief rejects without changing another assignment")
	game.advance(360)
	test.check(pile.brood_matured_total == 8 and pile.workers.total == 48, "Legacy stalled brood actually hatches after recall, without duplicating adults")

	game = AdaptationFixture.new().funded(); pile = game.run.colony.piles.home
	test.check(game.start_adaptation("home","lean") and pile.brood_care_workers_required() == 0, "Dedicated trial nurses satisfy their own cohort; no duplicate reserve")
	game.start_nursery_development("home"); game.advance(90)
	test.check(game.start_brood("home") and pile.brood_care_workers_required() == 2 and pile.nursery_care_capacity() == 16, "Overlapping ordinary/trial brood reserves only the extra carers")
	pile.workers.create_commitment("test:busy","other","test")
	pile.workers.allocate("test:busy",pile.workers_assignable)
	before = game.run.to_dict()
	test.check(not game.dispatch_scout("home",0.0) and game.run.to_dict() == before and pile.nursery_care_capacity() == 16, "Trial nurses plus held available carers preserve both cohorts")
	pile.workers.release("test:busy",pile.workers.count("test:busy")); pile.workers.retire_commitment("test:busy")
	game.advance(500)
	test.check(pile.brood_cohorts.is_empty() and pile.brood_care_workers_required() == 0 and pile.workers_assignable == pile.workers_available, "Emergence releases derived reserve and trial nurses exactly once")

	game = AdaptationFixture.new().funded(); pile = game.run.colony.piles.home
	game.start_nursery_development("home"); game.advance(90); game.start_brood("home")
	pile.workers.create_commitment("test:busy","other","test"); pile.workers.allocate("test:busy",pile.workers_assignable)
	before = game.run.to_dict()
	test.check(not game.start_brood("home") and game.brood.last_error == "More workers at home required for brood care" and game.run.to_dict() == before, "Manual laying cannot add an unsupported cohort that stalls existing brood")
	pile.workers.release("test:busy",2)
	test.check(game.start_brood("home") and pile.brood_care_workers_required() == 4, "Two simultaneous ordinary cohorts reserve four caregivers")

	game = AdaptationFixture.new().funded(); pile = game.run.colony.piles.home
	game.start_nursery_development("home"); game.advance(90); game.set_humidity_workers("home",4); game.start_brood("home")
	pile.workers.create_commitment("test:busy","other","test"); pile.workers.allocate("test:busy",pile.workers_available)
	plan = game.brood_care.plan("home")
	test.check(plan.get("kind") == "climate" and plan.workers == 2 and game.brood_care.apply("home",plan), "Legacy internal staffing offers a named two-worker climate reduction")
	test.check(pile.humidity.carers == 2 and pile.workers_available == 2 and pile.workers_assignable == 0 and pile.workers.invariant_holds(), "Care relief uses the climate owner ledger and preserves its remaining workers")

	game = DefenseFixture.new().ready_game(); pile = game.run.colony.piles.home
	if pile.brood_cohorts.is_empty(): game.start_brood("home")
	pile.workers.create_commitment("test:busy","other","test"); pile.workers.allocate("test:busy",pile.workers_assignable)
	test.check(game.journey_response.set_force("route_1",12) and not game.run.journey_response.active() and pile.workers_available == 2, "A waiting force order cannot borrow brood caregivers")
	pile.workers.release("test:busy",12); game.advance(0.25)
	test.check(game.run.journey_response.active() and pile.workers_available == 2 and pile.brood_cohorts[0].care == 1, "Freed labor funds the waiting force while actual carers remain home")

	game = DaughterFixture.new().fixture()
	var daughter: PileState = game.run.colony.piles.satellite_1
	game.start_brood("satellite_1")
	test.check(daughter.brood_care_workers_required() == 2 and game.create_trail("satellite_1","known:carb_exposed"), "Daughter reserves its own carers for local gathering")
	test.check(game.set_trail_workers("route_2",daughter.workers_available+5-2) if game.run.trails.routes.has("route_2") else false, "Daughter gathering can consume only its free local workforce")
	var root := Root.new(); root.simulation = game
	var status: Dictionary = root.inward_status("satellite_1")
	test.check(status.brood_care.held == 2 and status.workers_assignable == 0 and status.brood_care.relief.is_empty(), "Detached daughter summary separates free workers from held care")
	root.free()
	return true
