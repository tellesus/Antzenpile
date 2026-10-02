extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const CONFIG = preload("res://data/resources/default_humidity.tres")

func fixture() -> SimulationController:
	var game := Controller.new(66)
	var pile: PileState = game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 150)
	var begun: bool = game.start_nursery_development("home")
	assert(begun)
	game.advance(90)
	return game

func run(test: Object) -> bool:
	_test_regulation(test)
	_test_pressure(test)
	_test_continuation(test)
	_test_view(test)
	return true

func _test_regulation(test: Object) -> void:
	var game := Controller.new()
	var pile: PileState = game.run.colony.piles.home
	var initial: Dictionary = game.run.to_dict()
	test.check(not game.set_humidity_workers("home", 1) and game.run.to_dict() == initial, "Tiny primitive Nursery cannot staff expanded climate work")
	game.advance(800)
	test.check(pile.humidity.moisture == CONFIG.starting and pile.humidity.water_used_units == 0, "Primitive brood climate remains stable without new upkeep")
	game = fixture()
	pile = game.run.colony.piles.home
	var moisture: int = pile.humidity.moisture
	game.advance(100)
	test.check(pile.humidity.moisture == moisture - CONFIG.dry_step * 400 and pile.humidity.larval_rate() == 1.0, "Developed Nursery dries slowly without instant pressure")
	initial = game.run.to_dict()
	for invalid: Variant in [-1, 5, 1.5, "2", true]:
		test.check(not game.set_humidity_workers("home", invalid) and game.run.to_dict() == initial, "Invalid climate staffing rejects atomically")
	test.check(not game.set_humidity_workers("missing", 2) and game.run.to_dict() == initial, "Unknown pile cannot borrow climate labor")
	test.check(game.set_humidity_workers("home", 1) and pile.workers.count("humidity:home") == 1, "Climate work uses its own internal commitment")
	var water: float = pile.resources.water
	var used: int = pile.humidity.water_used_units
	moisture = pile.humidity.moisture
	for tick: int in 4:
		game.humidity.tick()
	test.check(pile.humidity.moisture == moisture + 500 and is_equal_approx(water - pile.resources.water, (pile.humidity.water_used_units - used) / 100000.0), "Humidifying recovery pays exactly its recorded stored water")
	var available: int = pile.workers_available
	test.check(game.set_humidity_workers("home", 0) and pile.workers_available == available + 1 and pile.workers.count("humidity:home") == -1, "Stopping internal climate work releases immediately")
	# Unit fixture isolates airing from scheduled rain/home water deposits.
	pile.humidity.moisture = 850000
	test.check(game.set_humidity_workers("home", 2), "Airing staff assigned")
	water = pile.resources.water
	game.humidity.tick()
	test.check(pile.humidity.moisture == 849375 and pile.resources.water == water, "Airing removes excess moisture without water debit")
	pile.humidity.moisture = 400000
	pile.consume_resources({"water": pile.resources.water})
	pile.deposit_resource("water", 0.00002)
	used = pile.humidity.water_used_units
	game.humidity.tick()
	test.check(pile.humidity.moisture == 399877 and pile.resources.water == 0 and pile.humidity.water_used_units - used == 2, "Scarce water pays only affordable humidity adjustment and never goes negative")
	game.humidity.tick()
	test.check(pile.humidity.moisture == 399752 and pile.resources.water == 0, "Unfunded carers cannot manufacture moisture")
	pile.deposit_resource("water", 1)
	game.set_humidity_workers("home", 0)
	game.run.rain.phase = "raining"
	moisture = pile.humidity.moisture
	game.humidity.tick()
	test.check(pile.humidity.moisture == moisture + CONFIG.wet_step, "Local rain gradually increases developed Nursery moisture")

func _test_pressure(test: Object) -> void:
	var game := fixture()
	var pile: PileState = game.run.colony.piles.home
	var cohort: BroodCohort = pile.brood_cohorts[0]
	for moisture: int in [CONFIG.starting, 400000, 200000, 900000, 980000]:
		pile.humidity.moisture = moisture
		cohort.stage = "larva"
		cohort.progress_seconds = 0
		var water: float = pile.resources.water
		game.brood.tick(1)
		var rate: float = pile.humidity.larval_rate()
		test.check(cohort.progress_seconds == rate and cohort.care == 1 and cohort.nutrition == 1, "Humidity pressure is separate from nurses and nutrition")
		test.check(is_equal_approx(water - pile.resources.water, 8 * 0.0075 * rate), "Larval water use scales with actual development")
	pile.humidity.moisture = 400000
	pile.midden.generated_units = pile.midden.CONFIG.strain_units
	pile.midden.revealed = true
	cohort.progress_seconds = 0
	game.brood.tick(1)
	test.check(cohort.progress_seconds == 0.75 and pile.brood_lost_total == 0, "Climate/sanitation use the worse slowdown without multiplying or causing deaths")
	pile.midden.isolated_units = pile.midden.generated_units
	game.set_humidity_workers("home", 4)
	game.advance(15)
	test.check(pile.humidity.larval_rate() == 1, "Climate carers restore the favorable band through real time/water")
	cohort.stage = "egg"
	cohort.progress_seconds = 0
	pile.humidity.moisture = 200000
	game.brood.tick(1)
	test.check(cohort.progress_seconds == 1, "Humidity does not add egg slowdown in this bounded prototype")

func _test_continuation(test: Object) -> void:
	var game := fixture()
	game.set_humidity_workers("home", 2)
	game.advance(20)
	var saved: Dictionary = Snapshot.new().snapshot(game)
	var reference := Controller.new()
	test.check(reference.restore_snapshot(saved), "Climate counters and committed carers restore")
	reference.advance(30)
	for scale: int in [1, 4, 16, 64]:
		var replay := Controller.new()
		test.check(replay.restore_snapshot(saved), "Climate restores at speed " + str(scale))
		replay.set_time_scale(scale)
		replay.advance(30.0 / scale)
		replay.set_time_scale(1)
		test.check(replay.run.to_dict() == reference.run.to_dict(), "Climate water/material continuation is exact at speed " + str(scale))
	var initial: Dictionary = reference.run.to_dict()
	reference.toggle_pause()
	var paused: Dictionary = reference.run.to_dict()
	reference.advance(10)
	test.check(reference.run.to_dict() == paused, "Pause freezes moisture/regulation/water debit")
	reference.toggle_pause()
	for field: String in ["moisture", "carers", "water_used_units"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.colony.piles[0].humidity[field] = {"moisture": 1000001, "carers": 5, "water_used_units": -1}[field]
		test.check(not reference.restore_snapshot(bad) and reference.run.to_dict() == initial, "Malformed climate state rejects atomically: " + field)
	var bad: Dictionary = saved.duplicate(true)
	bad.colony.piles[0].workers.commitments["humidity:home"].count = 1
	bad.colony.piles[0].workers.available += 1
	test.check(not reference.restore_snapshot(bad) and reference.run.to_dict() == initial, "Climate carers must reconcile the ledger")
	var old: Dictionary = saved.duplicate(true)
	old.colony.piles[0].erase("humidity")
	test.check(not reference.restore_snapshot(old), "Legacy default cannot erase an existing climate job")
	var legacy := Controller.new()
	old = Snapshot.new().snapshot(legacy)
	old.colony.piles[0].erase("humidity")
	test.check(legacy.restore_snapshot(old) and legacy.run.colony.piles.home.humidity.moisture == CONFIG.starting, "Legacy saves start at stable humidity with no retroactive burden")
	var pile: PileState = game.run.colony.piles.home
	game.set_humidity_workers("home", 0)
	pile.workers.create_commitment("test:busy", "other", "test")
	pile.workers.allocate("test:busy", pile.workers_available)
	initial = game.run.to_dict()
	test.check(not game.set_humidity_workers("home", 1) and game.run.to_dict() == initial, "Other commitments cannot be borrowed for climate care")

func _test_view(test: Object) -> void:
	var root := Root.new()
	root.simulation = fixture()
	var view: InwardView = View.new()
	test.get_root().add_child(view)
	view.status_provider = root.inward_status.bind("home")
	view.humidity_command = root.set_humidity_workers
	view.selected_id = "nursery"
	view._process(0)
	var before: Dictionary = root.simulation.run.to_dict()
	root.simulation.run.world.nodes.water_01.quantity = 0
	test.check(root.inward_status("home").humidity.moisture == 65.0 - 0.0125, "Hidden exterior water does not become a climate report")
	for target: int in [1, 2, 4, 0]:
		test.check(view.activate_at(view._humidity_rect(target).get_center()) and root.simulation.run.colony.piles.home.humidity.carers == target, "Shared input path assigns climate carers: " + str(target))
	view._process(0)
	test.check(not view._humidity_rect(4).intersects(view._brood_rect()), "Climate staffing remains separate from laying brood")
	var summary: Dictionary = root.inward_status("home")
	summary.humidity.moisture = 0
	test.check(root.inward_status("home").humidity.moisture > 0, "Climate summary is detached from authoritative moisture")
	view.free()
	root.free()
