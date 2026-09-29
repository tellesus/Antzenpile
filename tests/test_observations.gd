extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Senses = preload("res://src/sim/scouting/scout_senses.gd")


func fixture() -> SimulationController:
	var controller := Controller.new(6241)
	var source: WorldNodeState = controller.run.world.nodes.carb_exposed
	source.position = Vector2(24.25, 22.25) # Off the original y=20 route, and off the grid.
	controller.run.world.nodes = {"carb_exposed": source}
	controller.dispatch_scout("home", 0.0)
	var agent: ScoutAgent = controller.run.scouts.scout_1
	agent.path.clear()
	for x: int in range(20, 31):
		agent.path.append(Vector2(x, 20))
	agent.mission_target = Vector2(30, 20)
	return controller


func run(test: Object) -> bool:
	var game := fixture()
	var agent: ScoutAgent = game.run.scouts.scout_1
	test.check(agent.observations.is_empty() and game.run.delivered_observations.is_empty(), "Hidden resource initially gives no evidence")
	var first_radius: float = 0.0
	var saw_investigation: bool = false
	var confirmed_distance: float = -1.0
	var saved: Dictionary = {}
	for index: int in range(110):
		game.advance(0.25)
		test.check(game.run.delivered_observations.is_empty(), "Unreturned encounters remain private")
		saw_investigation = saw_investigation or agent.investigating == "carb_exposed"
		if agent.observations.has("carb_exposed"):
			var evidence: Observation = agent.observations.carb_exposed
			if first_radius == 0.0:
				first_radius = evidence.uncertainty_radius
				saved = game.run.to_dict()
			if evidence.proximity_confirmed and confirmed_distance < 0:
				confirmed_distance = evidence.closest_distance
	test.check(first_radius > 1.0 and saw_investigation, "Off-path chemical cue creates broad estimate and redirects scout")
	test.check(confirmed_distance > 0.0 and confirmed_distance <= 1.0, "Close sensing confirms without physical point contact")
	test.check(agent.observations.size() == 1 and agent.observations.carb_exposed.uncertainty_radius < first_radius, "Repeated closer encounters refine one observation")
	var reference := Controller.new()
	var restored := Controller.new()
	test.check(reference.run.restore(saved) and restored.run.restore(JSON.parse_string(JSON.stringify(saved, "", true, true))), "Mid-investigation JSON restore")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.scouts[0].observations[0].uncertainty_radius = -1
	var before: Dictionary = reference.run.to_dict()
	test.check(not reference.run.restore(invalid) and reference.run.to_dict() == before, "Malformed evidence restore is atomic")
	invalid = saved.duplicate(true)
	invalid.scouts[0].observations.append(invalid.scouts[0].observations[0].duplicate(true))
	test.check(not reference.run.restore(invalid) and reference.run.to_dict() == before, "Duplicate carried evidence rejected")
	invalid = saved.duplicate(true)
	invalid.delivered_observations.append(invalid.scouts[0].observations[0].duplicate(true))
	test.check(not reference.run.restore(invalid) and reference.run.to_dict() == before, "Away scout cannot already have delivered evidence")
	for index: int in range(300):
		reference.advance(0.25)
		restored.advance(0.25)
		test.check(reference.run.to_dict() == restored.run.to_dict(), "Sensory and RNG continuation matches")
	test.check(reference.run.delivered_observations.size() == 1 and reference.run.scouts.is_empty(), "Exactly one delivered observation after return")
	before = reference.run.to_dict()
	invalid = before.duplicate(true)
	invalid.delivered_observations.append(invalid.delivered_observations[0].duplicate(true))
	test.check(not reference.run.restore(invalid) and reference.run.to_dict() == before, "Duplicate delivered evidence rejects atomically")
	var detached: Dictionary = reference.run.to_dict()
	detached.delivered_observations[0].estimated_position[0] = 0.0
	test.check(reference.run.to_dict() == before, "Delivered snapshot cannot mutate evidence")
	var delivered: Dictionary = reference.run.delivered_observations.values()[0].to_dict()
	reference.advance(10.0)
	test.check(reference.run.delivered_observations.size() == 1, "No duplicate delivery on later ticks")
	reference.run.world.nodes.carb_exposed.position = Vector2(35, 35)
	reference.run.world.nodes.carb_exposed.quantity = 0
	test.check(reference.run.delivered_observations.values()[0].to_dict() == delivered, "Hidden truth changes cannot refresh delivered memory")
	test.check(restored.run.restore(JSON.parse_string(JSON.stringify(reference.run.to_dict(), "", true, true))), "Stale delivered evidence survives snapshot")
	var blocked := fixture()
	blocked.advance(28.0)
	blocked.run.world.terrain.append({"id": "block", "bounds": [0.0, 0.0, 40.0, 40.0], "exposure": 0.0, "traversable": false, "movement_cost": 1.0})
	blocked.advance(10.0)
	test.check(blocked.run.scouts.scout_1.observations.size() == 1 and blocked.run.delivered_observations.is_empty() and blocked.run.colony.piles.home.workers_available == 39, "Blocked return keeps evidence private and worker committed")
	blocked.run.world.terrain.pop_back()
	blocked.advance(50.0)
	test.check(blocked.run.delivered_observations.size() == 1 and blocked.run.colony.piles.home.workers_available == 40, "Unblocked arrival delivers evidence once")
	var sensing := fixture()
	var sensor: ScoutAgent = sensing.run.scouts.scout_1
	var node: WorldNodeState = sensing.run.world.nodes.carb_exposed
	var rng_before: int = sensing.run.rng.state
	Senses.sample(sensor, sensing.run.world, sensing.scouting.config, sensing.run.rng, 0.0)
	test.check(sensor.observations.is_empty() and sensing.run.rng.state == rng_before, "Out-of-range source supplies no cue or random draw")
	sensor.position = node.position + Vector2(2, 0)
	node.active = false
	Senses.sample(sensor, sensing.run.world, sensing.scouting.config, sensing.run.rng, 0.0)
	node.active = true
	node.quantity = 0
	Senses.sample(sensor, sensing.run.world, sensing.scouting.config, sensing.run.rng, 0.0)
	test.check(sensor.observations.is_empty(), "Inactive and depleted sources supply no cue")
	node.quantity = 100
	Senses.sample(sensor, sensing.run.world, sensing.scouting.config, sensing.run.rng, 0.0)
	var measured: Dictionary = sensor.observations.carb_exposed.to_dict()
	rng_before = sensing.run.rng.state
	Senses.sample(sensor, sensing.run.world, sensing.scouting.config, sensing.run.rng, 1.0)
	test.check(sensor.observations.carb_exposed.to_dict() == measured and sensing.run.rng.state == rng_before, "Stationary repeats do not reroll or duplicate evidence")
	print("[SENSE] broad radius %.2fm narrowed to %.2fm; confirmation at %.2fm without point contact" % [first_radius, agent.observations.carb_exposed.uncertainty_radius, confirmed_distance])
	return true
