extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const CONFIG = preload("res://data/resources/default_brood_health.tres")

func fixture(burden: int = 0) -> SimulationController:
	var game := Controller.new(99)
	var pile: PileState = game.run.colony.piles.home
	pile.midden.generated_units = 4000000
	pile.midden.revealed = true
	pile.brood_cohorts[0].stage = "larva"
	for resource: String in PileState.RESOURCE_IDS: pile.resources[resource] = 0.0
	pile.brood_health.burden = burden
	return game

func run(test: Object) -> bool:
	_onset_and_response(test)
	_losses_and_trials(test)
	_saved_continuation(test)
	_presentation(test)
	_source_precision(test)
	return true

func _onset_and_response(test: Object) -> void:
	var game := fixture()
	var pile: PileState = game.run.colony.piles.home
	game.advance(62.25)
	test.check(pile.brood_health.burden == 996 and game.brood_health.summary("home").condition == "stable", "Heavy refuse has delayed health symptoms")
	game.advance(0.25)
	test.check(game.brood_health.summary("home").condition == "strained" and pile.brood_health.losses == 0, "Symptoms precede losses without a hidden countdown")
	var original: int = pile.brood_health.burden
	test.check(game.set_sanitation_workers("home", 5), "Existing basic cleanup supplies a funded labor response")
	game.advance(180)
	test.check(pile.brood_health.burden < original and pile.midden.burden_units < 3600000, "Clearing heavy refuse permits gradual health recovery")
	game.advance(125)
	test.check(pile.brood_health.burden == 0 and game.brood_health.summary("home").condition == "stable", "Cleanup recovers without a cure purchase or magic reset")
	var dry := fixture()
	var damp := fixture()
	damp.run.colony.piles.home.nursery_state = "developed"
	damp.run.colony.piles.home.nursery_progress_seconds = 90.0
	damp.run.colony.piles.home.humidity.moisture = 850000
	dry.advance(50)
	damp.advance(50)
	test.check(damp.run.colony.piles.home.brood_health.burden > dry.run.colony.piles.home.brood_health.burden, "Damp developed Nursery accelerates heavy-refuse exposure")
	var clean := Controller.new()
	clean.set_sanitation_workers("home", 2) # Not revealed: command correctly rejects.
	clean.advance(100)
	test.check(clean.run.colony.piles.home.brood_health.burden == 0, "A new colony gains no arbitrary disease")
	game = fixture(CONFIG.symptom_threshold)
	pile = game.run.colony.piles.home
	for id: String in PileState.RESOURCE_IDS: pile.deposit_resource(id, 100)
	var protein: float = pile.resources.protein
	game.brood.tick(1)
	test.check(pile.brood_cohorts[0].progress_seconds == 0.5 and is_equal_approx(protein - pile.resources.protein, 0.0045 * 8 * 0.5), "Health combines by worst rate and proportional food, not compounded tax")

func _losses_and_trials(test: Object) -> void:
	var game := fixture(CONFIG.severe_threshold)
	var pile: PileState = game.run.colony.piles.home
	var adults: int = pile.workers_total
	game.advance(119.75)
	test.check(pile.brood_health.losses == 0 and pile.brood_cohorts[0].count == 8, "Severe strain does not kill immediately")
	game.advance(0.25)
	test.check(pile.brood_health.losses == 1 and pile.brood_lost_total == 1 and pile.brood_cohorts[0].lost_count == 1 and pile.workers_total == adults, "Health removes one larva through conserved brood accounting, never adult ledger")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Health loss reconciles with guest and total brood accounting")
	for stage: String in ["egg", "pupa"]:
		game = fixture(CONFIG.maximum)
		pile = game.run.colony.piles.home
		pile.brood_cohorts[0].stage = stage
		for tick: int in CONFIG.loss_ticks: game.brood_health.tick()
		test.check(pile.brood_health.losses == 0 and pile.brood_lost_total == 0 and pile.brood_health.severe_ticks == 0, "Health never removes " + stage + " brood")
	game = preload("res://tests/test_adaptation_queue.gd").new().funded()
	pile = game.run.colony.piles.home
	test.check(game.start_adaptation("home", "lean"), "Trial fixture pays normal resources/nurses")
	var cohort: BroodCohort = pile.trial_cohort()
	cohort.stage = "larva"
	# Exercise final-survivor ownership after seven conserved losses.
	for loss: int in 7:
		test.check(game.brood.lose_one("home", "larva"), "Conserved trial survivor fixture")
		pile.brood_health.losses += 1
		pile.brood_health.last_loss_tick = game.run.clock.tick_count
	pile.brood_health.burden = CONFIG.maximum
	pile.brood_health.severe_ticks = CONFIG.loss_ticks - 1
	pile.midden.generated_units = 4000000
	pile.midden.revealed = true
	game.advance(0.25)
	test.check(pile.trial_cohort() == null and pile.workers.count("adaptation:home") == -1 and pile.brood_lost_total == 8 and pile.workers.invariant_holds(), "Final sick trial larva releases nurses once and establishes no trait")
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Extinct trial with health losses restores exactly")
	game = fixture()
	game.advance(1000)
	game.advance(300)
	test.check(game.run.guest.reported_losses > 0 and game.run.colony.piles.home.brood_health.losses > 0 and copy.restore_snapshot(Snapshot.new().snapshot(game)), "Guest and health losses remain separate and reconcile together")

func _saved_continuation(test: Object) -> void:
	var game := fixture(CONFIG.severe_threshold)
	game.advance(30)
	var saved: Dictionary = Snapshot.new().snapshot(game)
	var baseline := Controller.new()
	test.check(baseline.restore_snapshot(saved), "Active health burden and severe interval survive JSON")
	baseline.advance(150)
	for speed: int in [1, 4, 16, 64]:
		var copy := Controller.new()
		test.check(copy.restore_snapshot(saved), "Health continuation restores at speed " + str(speed))
		copy.set_time_scale(speed)
		copy.advance(150.0 / speed)
		copy.set_time_scale(1)
		test.check(copy.run.to_dict() == baseline.run.to_dict(), "Exact health/save/RNG continuation at speed " + str(speed))
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(60)
	test.check(paused == game.run.to_dict(), "Pause freezes exposure, recovery and losses")
	var before: Dictionary = baseline.run.to_dict()
	for patch: Dictionary in [{"burden": -1}, {"burden": 10001}, {"burden": 1.5}, {"severe_ticks":480}, {"burden":0}, {"losses":1}, {"last_loss_tick":999999}, {"extra":0}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.colony.piles[0].brood_health.merge(patch, true)
		test.check(not baseline.restore_snapshot(bad) and baseline.run.to_dict() == before, "Malformed health rejects atomically: " + str(patch))
	var legacy := Controller.new()
	var old: Dictionary = Snapshot.new().snapshot(legacy)
	old.colony.piles[0].erase("brood_health")
	test.check(legacy.restore_snapshot(old) and legacy.run.colony.piles.home.brood_health.burden == 0, "Old saves start clean without retroactive disease")

func _presentation(test: Object) -> void:
	var root := Root.new()
	root.simulation = fixture(CONFIG.symptom_threshold)
	var status: Dictionary = root.inward_status("home")
	test.check(status.brood_health.condition == "strained" and not status.brood_health.has("burden") and not status.brood_health.has("severe_ticks"), "Detached UI exposes symptoms but no private disease units or forecast")
	test.check("BROOD HEALTH" in ColonyPressure.nursery_causes(status) and ColonyPressure.attention(status).organ == "nursery", "Known symptoms prompt voluntary Nursery attention")
	status.brood_health.condition = "stable"
	test.check(root.inward_status("home").brood_health.condition == "strained", "UI copies cannot change health reality")
	root.free()

func _source_precision(test: Object) -> void:
	var game: SimulationController = preload("res://tests/test_observations.gd").new().fixture()
	game.advance(85)
	test.check(game.create_trail("home", "known:carb_exposed"), "Fractional pickup regression uses a returned known route")
	var route: TrailRouteState = game.run.trails.find_route("home", "known:carb_exposed")
	var node: WorldNodeState = game.run.world.nodes.carb_exposed
	node.quantity = 120.0
	var cohort := TransitCohort.new()
	cohort.worker_count = 1
	cohort.carry_multiplier = 0.6
	for pickup: int in 5: game.trails._collect(cohort, route)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)) and copy.run.world.to_dict() == game.run.world.to_dict(), "Fractional source pickup has exact JSON quantity continuation")
	game.advance(10)
	copy.advance(10)
	test.check(copy.run.to_dict() == game.run.to_dict(), "Fractional pickup save preserves subsequent gameplay exactly")

	var rain_game := Controller.new()
	rain_game.run.world.nodes.water_01.quantity = 95.75
	rain_game.rain._refill_exterior_water(1.0)
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(rain_game)) and copy.run.world.to_dict() == rain_game.run.world.to_dict(), "Rain refill avoids decimal snapping residue across JSON saves")

	var coverage_game := Controller.new()
	coverage_game.run.exploration.coverage["8:7"] = roundf(0.0440158423 * 1e10) / 1e10
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(coverage_game)) and copy.run.to_dict() == coverage_game.run.to_dict(), "Coverage restore retains authored ten-decimal search precision")
