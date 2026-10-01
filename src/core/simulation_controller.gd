class_name SimulationController
extends RefCounted
## Run-scoped composition; no scene tree, input, or graphics required.

const Run = preload("res://src/core/run_state.gd")
const Scouts = preload("res://src/sim/scouting/scout_system.gd")
const Trails = preload("res://src/sim/trails/trail_system.gd")
const Brood = preload("res://src/sim/colony/brood_system.gd")
const FoodExchange = preload("res://src/sim/colony/food_exchange_system.gd")
const Nursery = preload("res://src/sim/colony/nursery_development_system.gd")
const Adaptation = preload("res://src/sim/colony/adaptation_system.gd")
const Rain = preload("res://src/sim/weather/rain_system.gd")
const Swarm = preload("res://src/sim/ecology/swarm_system.gd")
const Rival = preload("res://src/sim/ecology/rival_system.gd")
const Predator = preload("res://src/sim/ecology/predator_system.gd")
const Ecology = preload("res://src/sim/ecology/ecology_system.gd")
var run: RunState
var scouting: RefCounted
var trails: RefCounted
var brood: RefCounted
var food_exchange: RefCounted
var nursery: NurseryDevelopmentSystem
var adaptation: RefCounted
var rain: RainSystem
var ecology: EcologySystem
var swarm: SwarmSystem
var rival: RivalSystem
var predator: PredatorSystem


func _init(seed_value: int = 482817) -> void:
	_attach_run(Run.new(seed_value))


func restore_snapshot(snapshot: Dictionary) -> bool:
	var candidate: RunState = Run.new()
	if not candidate.restore(snapshot):
		return false
	_attach_run(candidate)
	return true


func _attach_run(next_run: RunState) -> void:
	if run != null and run.clock.tick.is_connected(_tick):
		run.clock.tick.disconnect(_tick)
	run = next_run
	scouting = Scouts.new(run)
	rival = Rival.new(run)
	predator = Predator.new(run)
	trails = Trails.new(run, predator, rival)
	swarm = Swarm.new(run, trails.apply_loss)
	trails.swarm = swarm
	brood = Brood.new(run)
	food_exchange = FoodExchange.new(run)
	nursery = Nursery.new(run)
	adaptation = Adaptation.new(run)
	rain = Rain.new(run)
	ecology = Ecology.new(run)
	run.clock.tick.connect(_tick)


func dispatch_scout(origin_id: String, bearing: Variant = null) -> bool:
	return scouting.dispatch(origin_id, bearing)


func investigate_known_source(origin_id: String, knowledge_id: String) -> bool:
	return scouting.dispatch_investigation(origin_id, knowledge_id)


func advance(real_delta: float) -> bool:
	return run.clock.advance(real_delta)


func toggle_pause() -> void:
	run.clock.paused = not run.clock.paused


func set_time_scale(value: int) -> bool:
	return run.clock.set_time_scale(value)


func create_trail(origin_id: String, knowledge_id: String) -> bool:
	return trails.create_route(origin_id, knowledge_id)


func set_trail_workers(route_id: String, target: Variant) -> bool:
	return trails.set_workers(route_id, target)


func recheck_trail(route_id: String) -> bool:
	return trails.recheck(route_id)


func start_food_exchange(pile_id: String) -> bool:
	return food_exchange.start(pile_id)


func start_brood(pile_id: String) -> bool:
	return brood.start(pile_id)


func start_nursery_development(pile_id: String) -> bool:
	return nursery.start(pile_id)


func start_adaptation(pile_id: String, trait_id: String) -> bool:
	return adaptation.start(pile_id, trait_id)


func start_honeydew_tending(pile_id: String) -> bool:
	return ecology.start_tending(pile_id)


func stop_honeydew_tending(pile_id: String) -> bool:
	return ecology.stop_tending(pile_id)


func _tick(delta: float) -> void:
	scouting.tick(delta)
	if not run.delivered_observations.is_empty():
		if not run.knowledge.consume(run.delivered_observations, run.simulation_time):
			push_error("Knowledge delivery rejected: " + run.knowledge.last_error)
	rival.tick(delta)
	trails.tick(delta)
	swarm.tick()
	rain.tick(delta)
	ecology.tick(delta)
	food_exchange.tick(delta)
	nursery.tick(delta)
	brood.tick(delta)
