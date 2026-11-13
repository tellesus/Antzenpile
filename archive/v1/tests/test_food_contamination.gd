extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Pressure = preload("res://src/presentation/colony_pressure.gd")
const Config = preload("res://data/resources/default_food_toxicity.tres")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func returning_spill(borrow_energy: bool = false) -> SimulationController:
	var game := Controller.new(80,"roadside")
	game.set_exploration(5)
	while game.run.simulation_time < 600 and not game.run.knowledge.nodes.has("known:carb_spill"): game.advance(0.25)
	if not game.run.knowledge.nodes.has("known:carb_spill"): return game
	game.set_exploration(0)
	if borrow_energy: game.run.colony.piles.home.resources.carbohydrate = 0
	game.create_trail("home","known:carb_spill")
	var route: TrailRouteState = game.run.trails.find_route("home","known:carb_spill")
	game.set_trail_workers(route.id,5)
	while game.run.simulation_time < 1200:
		if game.run.trails.cohorts.values().any(func(cohort): return cohort.contaminant_mass > 0): break
		game.advance(0.25)
	return game

func run(test: Object) -> bool:
	var game: SimulationController = returning_spill()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.run.knowledge.nodes.has("known:carb_spill") and game.run.trails.cohorts.values().any(func(cohort): return cohort.contaminant_mass > 0), "An ordinary scout finds returned food and real gatherers carry its hidden contaminant")
	test.check(pile.food_toxicity.mass == 0 and pile.food_toxicity.losses == 0, "Private inbound cargo does not contaminate home or report immediate failures")
	var root := Root.new(); root.simulation = game
	var summary: Dictionary = root.inward_status("home")
	test.check(not JSON.stringify(root.sensory_snapshot("home")).contains("contaminant") and summary.food_sharing.keys() == ["losses","age","recent"] and summary.food_sharing.losses == 0, "Normal sensory/local projections expose no chemical mass, dose or source identity")
	root.free()
	var saved: Dictionary = snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Hidden inbound material restores exactly")
	var start: float = game.run.simulation_time
	while game.run.simulation_time < start + 100 and pile.food_toxicity.mass == 0:
		game.advance(0.25); copy.advance(0.25)
	test.check(pile.food_toxicity.mass > 0 and pile.food_toxicity.losses == 0 and game.run.to_dict() == copy.run.to_dict(), "Actual home intake mixes toxin with no instant death and exact continued cargo")
	var first_intake: float = game.run.simulation_time
	while game.run.simulation_time < first_intake + 900 and pile.food_toxicity.losses == 0: game.advance(0.25)
	test.check(pile.food_toxicity.losses > 0 and game.run.simulation_time > first_intake + 1 and pile.workers.invariant_holds(), "Accumulated food exposure causes delayed ledger-conserved home losses")
	root = Root.new(); root.simulation = game
	summary = root.inward_status("home")
	test.check(summary.food_sharing.recent and Pressure.attention(summary).organ == "food_exchange" and Pressure.food_sources_needed(summary).has("carbohydrate"), "Locally observed food-sharing failures provide uncertain context and returned-food attention")
	test.check(summary.workers_total == pile.workers_total + game.run.trails.pending_for_pile("home"), "Home losses are immediately known while unreported exterior deaths retain their boundary")
	root.free()
	saved = snapshot(game); copy = Controller.new()
	test.check(copy.restore_snapshot(saved), "Observed local losses reconcile with physical/genetic saved accounting")
	game.advance(30); copy.advance(30)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Dose/decay/loss selection preserve exact JSON continuation")
	var intact: Dictionary = copy.run.to_dict()
	for bad: String in ["mass","dose","losses","time","world","cargo"]:
		var invalid: Dictionary = saved.duplicate(true)
		var home: Dictionary = invalid.colony.piles[0]
		match bad:
			"mass": home.food_toxicity.mass = home.resources.carbohydrate + 1
			"dose": home.food_toxicity.dose_units = Config.dose_threshold_units + 1
			"losses": home.food_toxicity.losses = home.workers.lost_total + 1
			"time": home.food_toxicity.last_loss_tick = int(invalid.clock.ticks) + 1
			"world": invalid.world.nodes[0].properties.contaminant_fraction = "poison"
			"cargo": invalid.trails.cohorts[0].contaminant_mass = invalid.trails.cohorts[0].payload + 1
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Malformed " + bad + " contamination snapshot rejects atomically")
	var legacy: Dictionary = snapshot(Controller.new(80))
	legacy.colony.piles[0].erase("food_toxicity")
	test.check(copy.restore_snapshot(legacy) and copy.run.colony.piles.home.food_toxicity.to_dict() == FoodToxicityState.new().to_dict(), "Older unexposed saves default to a clean pool without invented symptoms")
	_test_material(test)
	_test_jobs_and_traits(test)
	_test_speed(test,saved)
	_test_input(test,game)
	_test_recall(test)
	return true

func _test_material(test: Object):
	var game := Controller.new(80); var pile: PileState = game.run.colony.piles.home
	var before: Dictionary = pile.to_dict()
	for inputs: Array in [["water",10,1],["carbohydrate",1,2],["carbohydrate",1,-1],["unknown",1,0]]:
		test.check(not pile.deposit_resource(inputs[0],inputs[1],inputs[2]) and pile.to_dict() == before, "Invalid contaminated deposit remains atomic")
	pile.resources.carbohydrate = 0
	pile.deposit_resource("carbohydrate",10,2)
	pile.deposit_resource("carbohydrate",10)
	test.check(pile.food_toxicity.mass == 2 and pile.resources.carbohydrate == 20, "Clean intake dilutes a mixed pool while conserving toxic mass")
	pile.consume_resources({"carbohydrate":10.0})
	test.check(pile.resources.carbohydrate == 10 and pile.food_toxicity.mass == 1, "Energy consumption removes proportional contaminant material")
	before = pile.to_dict()
	test.check(not pile.consume_resources({"carbohydrate":11.0}) and pile.to_dict() == before, "Failed food debit does not remove hidden material")
	for tick: int in 720: game.food_toxicity.tick(0.25)
	test.check(absf(pile.food_toxicity.mass - 0.5) < 0.00001, "Authored detox half-life reduces mass without deleting stored energy")
	pile.food_toxicity.mass = 0.00000001; pile.food_toxicity.dose_units = 0
	game.food_toxicity.tick(0.25)
	test.check(pile.food_toxicity.mass == 0, "Fine-precision decay cannot leave an immortal rounding residue")
	pile.food_toxicity.mass = 0; pile.food_toxicity.dose_units = 1000
	game.food_toxicity.tick(0.25)
	test.check(pile.food_toxicity.dose_units == 500, "Residual exposure recovers gradually rather than clearing with a single command")
	game = returning_spill(); pile = game.run.colony.piles.home
	var route: TrailRouteState = game.run.trails.find_route("home","known:carb_spill")
	var cohort: TransitCohort
	for candidate: TransitCohort in game.run.trails.cohorts.values():
		if candidate.payload > 0: cohort = candidate; break
	var ratio: float = cohort.contaminant_mass / cohort.payload
	game.trails.apply_loss(cohort,route,"predator")
	test.check(is_equal_approx(cohort.contaminant_mass / cohort.payload,ratio), "A cargo casualty scales toxic material with remaining carrying capacity")
	game = returning_spill(true); pile = game.run.colony.piles.home
	for candidate: TransitCohort in game.run.trails.cohorts.values():
		if candidate.payload > 0: cohort = candidate; break
	var net: float = cohort.payload - cohort.unpaid_energy_cost
	var expected_ratio: float = cohort.contaminant_mass / cohort.payload
	var leg: int = cohort.remaining_ticks
	for tick: int in leg: game.advance(0.25)
	test.check(cohort.unpaid_energy_cost > 0 and pile.resources.carbohydrate <= net and absf(pile.food_toxicity.mass / pile.resources.carbohydrate - expected_ratio * pow(0.5,0.25 / Config.half_life_seconds)) < 0.00001, "Energy borrowed against returning food reduces net delivered toxin proportionally through same-tick larval consumption")

func _test_jobs_and_traits(test: Object):
	var game := Controller.new(80); var pile: PileState = game.run.colony.piles.home
	pile.resources.carbohydrate = 100; pile.food_toxicity.mass = 50; pile.food_toxicity.dose_units = Config.dose_threshold_units
	pile.workers.create_commitment("test:busy","other","busy"); pile.workers.allocate("test:busy",40)
	game.food_toxicity.tick(0.25)
	test.check(pile.workers.total == 40 and pile.workers.count("test:busy") == 40, "First contamination milestone never tears down committed worker jobs")
	pile.workers.release("test:busy",1); game.food_toxicity.tick(0.25)
	test.check(pile.workers.total == 39 and pile.workers.count("test:busy") == 39 and pile.queen_count == 1 and pile.brood_cohorts[0].count == 8, "Local adult loss uses only available ledger workers and preserves queen/brood")
	game = Controller.new(80); pile = game.run.colony.piles.home
	pile.genetics.emerge(["load","persistent"],40,"load"); pile.adaptation_repertoire = "load"; pile.adapted_workers_total = 40
	pile.resources.carbohydrate = 100; pile.food_toxicity.mass = 50; pile.food_toxicity.dose_units = Config.dose_threshold_units
	game.food_toxicity.tick(0.25)
	test.check(pile.workers.total == 39 and pile.adapted_workers_total == 39 and pile.genetics.count_profiles() == 39 and pile.genetics.count_trait("persistent",true) == 1 and pile.adapted_workers_lost == 1, "A poisoned adult expressing two traits remains one conserved adult loss")

func _test_speed(test: Object,saved: Dictionary):
	var reference := Controller.new(); reference.restore_snapshot(saved); reference.advance(100)
	for speed: int in [1,4,16,64]:
		var game := Controller.new(); game.restore_snapshot(saved); game.set_time_scale(speed); game.advance(100.0 / speed); game.set_time_scale(1)
		test.check(game.run.to_dict() == reference.run.to_dict(), "Material/dose/loss mechanics use identical fixed time at " + str(speed) + "x")
	var frozen: Dictionary = reference.run.to_dict(); reference.toggle_pause(); frozen.clock.paused = true; reference.advance(100)
	test.check(reference.run.to_dict() == frozen, "Pause freezes hidden detox/exposure and local failures")

func _test_input(test: Object,game: SimulationController):
	var root := Root.new(); test.get_root().add_child(root); root.set_process(false); root.simulation = game; game.toggle_pause()
	var view := View.new(); root.add_child(view); root._inward_view = view; view.selected_id = "food_exchange"
	view.status_provider = root.inward_status.bind("home"); view.food_sources_command = root.browse_food_sources
	var outward := Outward.new(); root.add_child(outward); root._outward_view = outward
	outward.status_provider = root.outward_status.bind("home"); outward.signal_provider = root.sensory_snapshot.bind("home")
	root.set_mode("inward"); view._process(0)
	var before: Dictionary = game.run.to_dict()
	var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = view._food_source_rect("carbohydrate").get_center()
	view._unhandled_input(touch)
	test.check(root.mode == "outward" and outward.sources_open and outward.source_category == "carbohydrate" and game.run.to_dict() == before, "Locally observed failures permit free returned-food browsing through the actual touch path")
	test.check(view._food_source_rect("carbohydrate").size.y == 44 and view._food_source_rect("carbohydrate").end.y < view._button_rect("pause").position.y, "Home-loss review stays touch-sized and above clock controls")
	root.free()

func _test_recall(test: Object):
	var game: SimulationController = returning_spill()
	var pile: PileState = game.run.colony.piles.home
	var route: TrailRouteState = game.run.trails.find_route("home","known:carb_spill")
	var workers: int = pile.workers_available
	test.check(game.set_trail_workers(route.id,0) and pile.food_toxicity.mass == 0 and not game.run.trails.cohorts.is_empty(), "Stop Traffic cannot erase or teleport already-returning toxic cargo")
	var start: float = game.run.simulation_time
	while not game.run.trails.cohorts.is_empty() and game.run.simulation_time < start + 300: game.advance(0.25)
	test.check(pile.food_toxicity.mass > 0 and route.allocated_workers == 0 and pile.workers_available >= workers + 5, "Recalled travelers deliver remaining material and physically release their labor at home")
	game.advance(900); game.advance(600)
	test.check(pile.food_toxicity.dose_units == 0 and not game.food_toxicity.summary("home").recent and pile.workers.invariant_holds(), "With no further suspect intake the pool settles gradually and local pressure clears")
