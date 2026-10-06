extends RefCounted
const Queue = preload("res://tests/test_adaptation_queue.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Surface = preload("res://tests/test_surface_disturbance.gd")
const Swarm = preload("res://tests/test_swarm.gd")
const Root = preload("res://src/core/game_root.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")

func funded_trial() -> SimulationController:
	var game: SimulationController = Queue.new().funded()
	game.adaptation.queue_choice("home","fighter"); game.advance(0.25)
	return game

func breed(game: SimulationController) -> void:
	for resource: String in PileState.RESOURCE_IDS: game.run.colony.piles.home.deposit_resource(resource,500)
	game.adaptation.queue_choice("home","fighter")
	for tick: int in 3600:
		if game.run.colony.piles.home.genetics.count_trait("fighter") > 0: break
		game.advance(0.25)

func run(test: Object) -> bool:
	var game: SimulationController = Queue.new().funded()
	var pile: PileState = game.run.colony.piles.home
	var stores: Dictionary = pile.resources.duplicate()
	test.check(game.adaptation.queue_choice("home","fighter") and pile.resources == stores, "Fighting trait queues without prepayment or immediate adult strength")
	test.check(game.adaptation.queue_choice("home","lean") and game.adaptation.queue_choice("home","fighter") and pile.queued_adaptation == "fighter", "Changing the unlaid choice replaces it rather than appending")
	game.advance(0.25)
	test.check(pile.trial_cohort().adaptation_id == "fighter" and pile.combat_multiplier() == 1 and pile.workers.count("adaptation:home") == 2, "Laid fighter brood locks two real nurses and has no egg-stage strength")
	test.check(is_equal_approx(stores.protein-pile.resources.protein,20) and is_equal_approx(stores.carbohydrate-pile.resources.carbohydrate,16), "Fighter trial pays its authored higher development cost")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.adaptation.queue_choice("home","fighter") and game.run.to_dict() == before, "Locked trial cannot be requeued or paid twice")
	game.advance(180)
	var plain: SimulationController = Queue.new().funded(); plain.start_brood("home"); plain.advance(180.25)
	var fighter_food: float = pile.resources.protein; var plain_food: float = plain.run.colony.piles.home.resources.protein
	game.advance(1); plain.advance(1)
	test.check(is_equal_approx((fighter_food-pile.resources.protein)/(plain_food-plain.run.colony.piles.home.resources.protein),1.4), "Actual fighter larvae consume 40 percent more feeding than baseline larvae")
	var twin := SimulationController.new()
	test.check(twin.restore_snapshot(Queue.new().snapshot(game)), "Growing fighter trial restores with its captured genetics")
	game.advance(180); twin.advance(180)
	test.check(game.run.to_dict() == twin.run.to_dict() and pile.genetics.count_trait("fighter") == 8 and pile.combat_multiplier() > 1, "Only emerged surviving carriers produce strength, with exact continuation")
	test.check(game.start_brood("home") and "fighter" in pile.brood_cohorts[0].inherited_traits, "Ordinary subsequent brood inherits fighting and recurring feeding costs")
	var reserve: Dictionary = game.brood.remaining_food_reserve(pile)
	test.check(reserve.protein > plain.brood.remaining_food_reserve(plain.run.colony.piles.home).protein, "Auto Brood's intrinsic food reserve includes inherited fighter demand")
	# Actual paid ambusher dispatch and reinforcement carry distinct departure mixes.
	var defended: SimulationController = Defense.new().ready_game()
	breed(defended)
	test.check(defended.run.colony.piles.home.genetics.count_trait("fighter") == 8 and defended.journey_response.defend("route_1"), "Real matured fighters join a worker-funded defense")
	var captured: float = defended.run.journey_response.defense.combat_multiplier
	test.check(captured > 1 and defended.run.journey_response.workers == 12, "Combat weight increases without creating or displaying phantom workers")
	test.check(twin.restore_snapshot(Queue.new().snapshot(defended)), "Captured defensive combat mix restores in actual travel")
	for tick: int in 200:
		if defended.run.journey_response.phase == "fighting": break
		defended.advance(0.25); twin.advance(0.25)
	test.check(defended.journey_response.reinforce("route_1") and defended.run.journey_response.defense.extra_combat_multiplier > 1, "Reinforcement captures its payer's real fighting expression")
	test.check(twin.restore_snapshot(Queue.new().snapshot(defended)), "Traveling fighter reinforcement round-trips")
	for tick: int in 1000:
		if not defended.run.journey_response.active(): break
		defended.advance(0.25); twin.advance(0.25)
	test.check(defended.run.to_dict() == twin.run.to_dict() and defended.run.journey_response.defense.outcomes.route_1.sent == 16, "Fighter combat, messenger, reinforcement, casualty and real return remain reproducible")
	var raw: Dictionary = Queue.new().snapshot(defended); raw.journey_response.defense.combat_multiplier = 3
	test.check(not twin.restore_snapshot(raw), "Forged combat multipliers reject atomically")
	# Rival gathering uses the same captured cohort weights; no new army worker pool.
	var rival: SimulationController = Swarm.new().forming_fixture()
	rival.set_trail_workers("route_1",0); rival.advance(60)
	breed(rival)
	rival.set_trail_workers("route_1",0); rival.advance(60); rival.set_trail_workers("route_1",5); rival.advance(0.25)
	var empowered: bool = false
	for cohort: TransitCohort in rival.run.trails.cohorts.values(): empowered = empowered or cohort.combat_multiplier > 1
	test.check(empowered and twin.restore_snapshot(Queue.new().snapshot(rival)), "New rival-route travelers capture fighter weight and preserve strict cohort accounting")
	var surface: SimulationController = Surface.new().returned(); breed(surface)
	before = surface.run.to_dict()
	test.check(not surface.journey_response.set_force("route_1",24) and surface.run.to_dict() == before, "Fighting genetics cannot turn a surface catastrophe into an attackable enemy")
	var root := Root.new(); root.simulation = game
	var view := View.new(); view._status = root.inward_status("home"); view.selected_id = "adaptation"; view.web_family = "combat"
	test.check(Web.visible_nodes(view._status,"combat") == ["foraging","fighter"] and Web.trait_state(view._status,"fighter").begins_with("Inherited"), "Separate Combat family names inherited expression without duplicate purchase controls")
	for size: Vector2 in [Vector2(1280,720),Vector2(900,600)]:
		test.check(Web.node_at(Web.positions(size).fighter,size,view._status,"combat") == "fighter", "Combat leaf remains a separate 44-pixel inspection target")
	view.free(); root.free()
	return true
