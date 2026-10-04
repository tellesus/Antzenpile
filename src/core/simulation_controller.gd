class_name SimulationController
extends RefCounted
## Run-scoped composition; no scene tree, input, or graphics required.

const Run = preload("res://src/core/run_state.gd")
const Scouts = preload("res://src/sim/scouting/scout_system.gd")
const Trails = preload("res://src/sim/trails/trail_system.gd")
const Brood = preload("res://src/sim/colony/brood_system.gd")
const FoodExchange = preload("res://src/sim/colony/food_exchange_system.gd")
const Nursery = preload("res://src/sim/colony/nursery_development_system.gd")
const Sanitation = preload("res://src/sim/colony/sanitation_system.gd")
const Humidity = preload("res://src/sim/colony/humidity_system.gd")
const Adaptation = preload("res://src/sim/colony/adaptation_system.gd")
const Rain = preload("res://src/sim/weather/rain_system.gd")
const Swarm = preload("res://src/sim/ecology/swarm_system.gd")
const Guest = preload("res://src/sim/ecology/guest_system.gd")
const Rival = preload("res://src/sim/ecology/rival_system.gd")
const Predator = preload("res://src/sim/ecology/predator_system.gd")
const Ecology = preload("res://src/sim/ecology/ecology_system.gd")
var run: RunState
var scouting: RefCounted
var trails: RefCounted
var brood: RefCounted
var food_exchange: RefCounted
var nursery: NurseryDevelopmentSystem
var sanitation: RefCounted
var humidity: RefCounted
var adaptation: RefCounted
var rain: RainSystem
var ecology: EcologySystem
var brood_care: BroodCareRelief
var swarm: SwarmSystem
var guest: GuestSystem
var rival: RivalSystem
var surface_impact: SurfaceImpactSystem
var predator: PredatorSystem
var journey_response: JourneyResponseSystem
var food_toxicity: FoodToxicitySystem
var brood_health: BroodHealthSystem
var heat: HeatSystem
var supply: InterpileSupplySystem
var reinforcement: WorkerReinforcementSystem
var founding: FoundingSystem
var reproduction: ReproductionSystem


func _init(seed_value: int = 482817, scenario: String = "backyard_slice") -> void:
	_attach_run(Run.new(seed_value, scenario))


func restore_snapshot(snapshot: Dictionary) -> bool:
	var candidate: RunState = Run.new()
	if not candidate.restore(snapshot):
		return false
	_attach_run(candidate)
	return true


func start_new_run(seed_value: Variant, scenario: Variant = "backyard_slice") -> bool:
	if not seed_value is int or not scenario is String or not scenario in ScenarioCatalog.IDS:
		return false
	_attach_run(Run.new(seed_value, scenario))
	return true


func _attach_run(next_run: RunState) -> void:
	if run != null and run.clock.tick.is_connected(_tick):
		run.clock.tick.disconnect(_tick)
	run = next_run
	scouting = Scouts.new(run)
	rival = Rival.new(run)
	predator = Predator.new(run)
	journey_response = JourneyResponseSystem.new(run)
	trails = Trails.new(run, predator, rival)
	surface_impact = SurfaceImpactSystem.new(run, trails.apply_loss)
	trails.surface_impact = surface_impact
	swarm = Swarm.new(run, trails.apply_loss)
	trails.swarm = swarm
	adaptation = Adaptation.new(run)
	brood = Brood.new(run, adaptation)
	food_toxicity = FoodToxicitySystem.new(run)
	brood_health = BroodHealthSystem.new(run, brood.lose_one)
	heat = HeatSystem.new(run)
	supply = InterpileSupplySystem.new(run)
	reinforcement = WorkerReinforcementSystem.new(run)
	founding = FoundingSystem.new(run)
	reproduction = ReproductionSystem.new(run)
	guest = Guest.new(run, brood.lose_one)
	food_exchange = FoodExchange.new(run)
	nursery = Nursery.new(run)
	sanitation = Sanitation.new(run)
	humidity = Humidity.new(run)
	rain = Rain.new(run)
	ecology = Ecology.new(run)
	brood_care = BroodCareRelief.new(run, {"climate":humidity,"cleanup":sanitation,"aphids":ecology,"gatherers":trails,"scouts":scouting,"response":journey_response,"supplies":supply,"rejection":guest})
	run.clock.tick.connect(_tick)


func dispatch_scout(origin_id: String, bearing: Variant = null) -> bool:
	return scouting.dispatch(origin_id, bearing)


func recall_scout(id: String) -> bool:
	return scouting.recall(id)


func set_exploration(target: Variant, origin_id: String = "home") -> bool:
	return scouting.set_effort(target, origin_id)


func set_exploration_bias(bearing: Variant, origin_id: String = "home") -> bool:
	return scouting.set_bias(bearing, origin_id)


func set_investigation_priority(knowledge_id: String, enabled: bool, origin_id: String = "home") -> bool:
	return scouting.set_priority(knowledge_id, enabled, origin_id)


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


func set_brood_intent(pile_id: String, intent: Variant) -> bool:
	return brood.set_intent(pile_id, intent)


func start_nursery_development(pile_id: String) -> bool:
	return nursery.start(pile_id)


func start_nursery_expansion(pile_id: String) -> bool:
	return nursery.start_expansion(pile_id)


func set_sanitation_workers(pile_id: String, target: Variant) -> bool:
	return sanitation.set_workers(pile_id, target)


func start_midden(pile_id: String) -> bool:
	return sanitation.start(pile_id)


func set_humidity_workers(pile_id: String, target: Variant) -> bool:
	return humidity.set_workers(pile_id, target)


func start_adaptation(pile_id: String, trait_id: String) -> bool:
	return adaptation.start(pile_id, trait_id)


func queue_adaptation(pile_id: String, trait_id: Variant) -> bool:
	return adaptation.queue_choice(pile_id, trait_id)


func start_honeydew_tending(pile_id: String) -> bool:
	return ecology.start_tending(pile_id)


func stop_honeydew_tending(pile_id: String) -> bool:
	return ecology.stop_tending(pile_id)


func start_guest_rejection() -> bool:
	return guest.start_rejection()


func send_daughter_workers() -> bool:
	return reinforcement.start()

func recall_daughter_workers() -> bool:
	return reinforcement.recall()

func set_daughter_supply(enabled: Variant) -> bool:
	return supply.set_enabled(enabled)


func establish_daughter(knowledge_id: String) -> bool:
	return founding.establish(knowledge_id)


func start_founding(knowledge_id: String) -> bool:
	return founding.start(knowledge_id)


func start_reproduction(pile_id: String) -> bool:
	return reproduction.start(pile_id)


func stop_guest_rejection() -> bool:
	return guest.stop_rejection()


func _tick(delta: float) -> void:
	surface_impact.tick()
	scouting.tick(delta)
	if not run.delivered_observations.is_empty():
		if not run.knowledge.consume(run.delivered_observations, run.simulation_time):
			push_error("Knowledge delivery rejected: " + run.knowledge.last_error)
	scouting.maintain_effort()
	rival.tick(delta)
	trails.tick(delta)
	journey_response.tick()
	swarm.tick()
	rain.tick(delta)
	ecology.tick(delta)
	food_exchange.tick(delta)
	nursery.tick(delta)
	sanitation.tick()
	humidity.tick()
	heat.tick()
	guest.tick()
	brood_health.tick()
	brood.tick(delta)
	reproduction.tick()
	founding.tick()
	supply.tick()
	reinforcement.tick()
	food_toxicity.tick(delta)
