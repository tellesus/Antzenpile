extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const CONFIG = preload("res://data/weather/default_heat.tres")

func fixture() -> SimulationController:
	var game := Controller.new(100)
	var pile: PileState = game.run.colony.piles.home
	# Focused fixture; ordinary evidence separately pays for Nursery and staffing.
	pile.nursery_state = "developed"
	pile.nursery_progress_seconds = preload("res://data/resources/default_nursery_development.tres").build_seconds
	for resource: String in PileState.RESOURCE_IDS: pile.deposit_resource(resource, 100)
	return game

func run(test: Object) -> bool:
	_schedule(test)
	_water_and_brood(test)
	_saves(test)
	return true

func _schedule(test: Object) -> void:
	var game := fixture()
	var old_clock: Dictionary = game.run.clock.to_dict()
	for offset: int in [-1, 0, 240, 480, 1920, 2160, 2400, 12480]:
		var clock: Dictionary = old_clock.duplicate(true)
		clock.ticks = str(CONFIG.first_tick + offset)
		clock.time = (CONFIG.first_tick + offset) * 0.25
		test.check(game.run.clock.restore(clock), "Thermal schedule clock fixture")
		var expected: int = { -1:26000, 0:26000, 240:31000, 480:36000, 1920:36000, 2160:31000, 2400:26000, 12480:36000 }[offset]
		test.check(game.heat.ambient() == expected, "Authored rising/plateau/falling/recurring air temperature: " + str(offset))
	game.run.rain.phase = "raining"
	test.check(game.heat.ambient() == 32000, "Actual rain cools the warm front")
	var primitive := Controller.new()
	primitive.run.clock.restore(game.run.clock.to_dict())
	for tick: int in 1000: primitive.heat.tick()
	test.check(primitive.run.colony.piles.home.temperature.temperature == CONFIG.baseline, "Primitive Nursery stays sheltered through later heat")

func _water_and_brood(test: Object) -> void:
	var game := fixture()
	var pile: PileState = game.run.colony.piles.home
	pile.temperature.temperature = 35000
	test.check(game.set_humidity_workers("home", 2) and pile.workers.count("humidity:home") == 2, "Existing climate workers provide cooling without another commitment")
	var water: float = pile.resources.water
	var workers: Dictionary = pile.workers.to_dict()
	game.heat.tick()
	test.check(pile.temperature.temperature == 34960 and pile.temperature.water_used_units == 200 and is_equal_approx(water - pile.resources.water, 0.002), "Two workers pay water for actual cooling after passive drift")
	test.check(pile.workers.to_dict() == workers, "Cooling never duplicates/debits climate workers")
	pile.resources.water = 0
	game.heat.tick()
	test.check(pile.temperature.temperature == 34950 and pile.temperature.water_used_units == 200, "Empty stores permit only passive cooling, never free active regulation")
	pile.resources.water = 0.00001
	game.heat.tick()
	test.check(pile.resources.water == 0.00001 and pile.temperature.water_used_units == 200, "Insufficient fractional water cannot buy an adjustment or be wasted")
	pile.resources.water = 10
	pile.temperature.temperature = 26000
	game.heat.tick()
	test.check(pile.temperature.water_used_units == 200 and pile.resources.water == 10, "Stable thermal conditions impose no extra water tax")
	pile.temperature.temperature = 35000
	pile.brood_cohorts[0].stage = "larva"
	var protein: float = pile.resources.protein
	game.brood.tick(1)
	test.check(pile.brood_cohorts[0].progress_seconds == 0.5 and is_equal_approx(protein - pile.resources.protein, 0.0045 * 8 * 0.5), "Severe heat slows larvae and food proportionally without compounded penalties")
	var root := Root.new()
	root.simulation = game
	var status: Dictionary = root.inward_status("home")
	test.check(status.temperature == {"condition":"hot", "larval_rate":0.5} and "HEAT" in ColonyPressure.nursery_causes(status), "Normal UI receives local coarse heat symptoms, not an ambient forecast")
	test.check(is_equal_approx(status.humidity.water_used, (pile.temperature.water_used_units + pile.humidity.water_used_units) / 100000.0), "Known climate water use includes both real debits")
	root.free()

func _saves(test: Object) -> void:
	var game := fixture()
	game.set_humidity_workers("home", 1)
	game.run.colony.piles.home.temperature.temperature = 35000
	game.advance(30)
	var saved: Dictionary = Snapshot.new().snapshot(game)
	var baseline := Controller.new()
	test.check(baseline.restore_snapshot(saved), "Thermal state and shared climate ownership restore")
	baseline.advance(90)
	for speed: int in [1,4,16,64]:
		var copy := Controller.new()
		test.check(copy.restore_snapshot(saved), "Heat save restores at speed " + str(speed))
		copy.set_time_scale(speed); copy.advance(90.0 / speed); copy.set_time_scale(1)
		test.check(copy.run.to_dict() == baseline.run.to_dict(), "Thermal exact continuation at speed " + str(speed))
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(20)
	test.check(game.run.to_dict() == paused, "Pause freezes thermal curve, cooling and water use")
	var before: Dictionary = baseline.run.to_dict()
	for patch: Dictionary in [{"temperature":21999}, {"temperature":36001}, {"temperature":26000.5}, {"water_used_units":-1}, {"water_used_units":"1"}, {"extra":0}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.colony.piles[0].temperature.merge(patch, true)
		test.check(not baseline.restore_snapshot(bad) and baseline.run.to_dict() == before, "Malformed thermal save rejects atomically: " + str(patch))
	var legacy := fixture()
	var old: Dictionary = Snapshot.new().snapshot(legacy)
	old.colony.piles[0].erase("temperature")
	test.check(legacy.restore_snapshot(old) and legacy.run.colony.piles.home.temperature.temperature == CONFIG.baseline, "Legacy Nursery starts without retroactive heat burden")
	old = Snapshot.new().snapshot(Controller.new())
	old.colony.piles[0].temperature.temperature = 35000
	test.check(not baseline.restore_snapshot(old) and baseline.run.to_dict() == before, "Primitive thermal state cannot claim developed exposure")
