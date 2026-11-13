extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Snapshot = preload("res://tests/test_guest.gd")

func fixture(tick: int = 15600) -> SimulationController:
	var game := Controller.new(101)
	var clock: Dictionary = game.run.clock.to_dict()
	clock.ticks = str(tick); clock.time = tick * 0.25
	game.run.clock.restore(clock)
	return game

func run(test: Object) -> bool:
	var hot := fixture()
	var ordinary := fixture(1200)
	var wet := fixture()
	wet.run.rain.phase = "raining"
	for game: SimulationController in [hot, ordinary, wet]:
		game.run.world.nodes.carb_sheltered.quantity = 0
		game.run.world.nodes.aphid_01.quantity = 0
		game.ecology.tick(0.25)
	test.check(hot.run.world.nodes.carb_sheltered.quantity == 9 and ordinary.run.world.nodes.carb_sheltered.quantity == 12 and wet.run.world.nodes.carb_sheltered.quantity == 12, "Hot dry nectar output falls to 75%; rain/ordinary conditions preserve normal output")
	test.check(is_equal_approx(hot.run.world.nodes.aphid_01.quantity, ordinary.run.world.nodes.aphid_01.quantity * 0.75), "Honeydew output responds physically while condition/interval remain unchanged")
	test.check(hot.run.honeydew.condition == ordinary.run.honeydew.condition, "Heat does not multiply tending/producer condition pressure")
	var pile: PileState = hot.run.colony.piles.home
	var stores: Dictionary = pile.resources.duplicate()
	var initial: float = hot.run.world.nodes.water_01.quantity
	for tick: int in 400: hot.heat.tick()
	test.check(is_equal_approx(initial - hot.run.world.nodes.water_01.quantity, 1) and stores == pile.resources, "One hundred hot dry seconds evaporate one exterior water unit, never Home stores")
	# 400 ticks = 100 seconds at 0.25s, and 0.01/sec = one unit.
	test.check(hot.run.knowledge.nodes.is_empty() and hot.run.delivered_observations.is_empty(), "Unknown drying/producer changes reveal no source information")
	hot.run.world.nodes.water_01.quantity = 0.001
	hot.heat.tick()
	test.check(hot.run.world.nodes.water_01.quantity == 0 and not hot.run.world.nodes.water_01.active, "Drying clamps to zero with no negative resource")
	hot.run.rain.phase = "raining"
	hot.heat.tick()
	hot.rain._refill_exterior_water(1)
	test.check(hot.run.world.nodes.water_01.active and hot.run.world.nodes.water_01.quantity == 0.4 and not HeatSystem.hot_dry(hot.run), "Actual rain ends drying and refills an exhausted source")
	var known := Controller.new(101)
	known.set_exploration(5)
	known.advance(500)
	var memory: Dictionary = known.run.knowledge.to_dict()
	var clock: Dictionary = known.run.clock.to_dict()
	clock.ticks = "15600"; clock.time = 3900.0
	known.run.clock.restore(clock)
	known.run.world.nodes.carb_sheltered.quantity = 0
	known.ecology.tick(0.25)
	test.check(known.run.knowledge.to_dict() == memory, "Existing returned resource memories stay stale during physical heat changes")
	var root := Root.new()
	root.simulation = ordinary
	test.check(root.outward_status("home").home_air == "", "Ordinary air stays quiet")
	root.simulation = wet
	test.check(root.outward_status("home").home_air == "Rain-cooled air at Home", "Current Home rain cue has no schedule or remote effect forecast")
	root.simulation = fixture()
	test.check(root.outward_status("home").home_air == "Hot, dry air at Home", "Home hot-air cue remains observable with sheltered Nursery")
	root.free()
	return true
