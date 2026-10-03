class_name RunState
extends RefCounted

const Clock = preload("res://src/core/simulation_clock.gd")
const SNAPSHOT_VERSION: int = 5
const World = preload("res://src/sim/world/world_state.gd")
const Loader = preload("res://src/sim/world/world_loader.gd")
const Scenarios = preload("res://src/sim/world/scenario_catalog.gd")
const Colony = preload("res://src/sim/colony/colony_state.gd")
const Scout = preload("res://src/sim/scouting/scout_agent.gd")
const Knowledge = preload("res://src/sim/knowledge/knowledge_base.gd")
const MissionMemory = preload("res://src/sim/knowledge/scout_mission_memory.gd")
const Trails = preload("res://src/sim/trails/trail_network.gd")
const Rain = preload("res://src/sim/weather/rain_state.gd")
const Honeydew = preload("res://src/sim/ecology/honeydew_state.gd")
const HONEYDEW_CONFIG = preload("res://data/ecology/backyard_honeydew.tres")
const Swarm = preload("res://src/sim/ecology/swarm_state.gd")
const Guest = preload("res://src/sim/ecology/guest_state.gd")
const Rival = preload("res://src/sim/ecology/rival_state.gd")
const Predator = preload("res://src/sim/ecology/predator_state.gd")
const Evidence = preload("res://src/sim/scouting/observation.gd")
const SCOUT_CONFIG = preload("res://data/scouting/default_scouts.tres")
const Exploration = preload("res://src/sim/scouting/exploration_state.gd")
var supply := InterpileSupplyState.new()
var reinforcement := WorkerReinforcementState.new()
var founding := FoundingState.new()
var exploration: ExplorationState = Exploration.new()
var daughter_exploration: ExplorationState = Exploration.new()
var world: WorldState
var colony: ColonyState = Colony.new()
var scouts: Dictionary[String, ScoutAgent] = {}
var scout_missions: Dictionary[String, ScoutMissionMemory] = {}
var scout_losses: Dictionary[String, int] = {}
var next_scout_id: int = 1
var knowledge: KnowledgeBase = Knowledge.new()
var trails: TrailNetwork = Trails.new()
var rain: RainState = Rain.new()
var honeydew: HoneydewState = Honeydew.new()
var swarm: SwarmState = Swarm.new()
var guest: GuestState = Guest.new()
var rival: RivalState = Rival.new()
var predator: PredatorState = Predator.new()
var journey_response: JourneyResponseState = JourneyResponseState.new()
var delivered_observations: Dictionary[String, Observation] = {}

var run_seed: int:
	get: return _seed
var scenario_id: String:
	get: return _scenario_id
var clock: SimulationClock = Clock.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var genetic_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var simulation_time: float:
	get: return clock.simulation_time

var _seed: int
var _scenario_id: String


func exploration_for(pile_id: String) -> ExplorationState:
	if not colony.piles.has(pile_id): return null
	return exploration if pile_id == "home" else daughter_exploration if pile_id == "satellite_1" else null


func _init(seed_value: int = 482817, scenario: String = "backyard_slice") -> void:
	_seed = seed_value
	_scenario_id = scenario
	rng.seed = _seed
	genetic_rng.seed = _seed ^ 0x415450
	world = Loader.new().load_scenario(Scenarios.path_for(scenario))
	assert(world != null, "Run construction requires a registered authored scenario")
	colony.initialize_home(world.home_position)


func to_dict() -> Dictionary:
	var scout_records: Array[Dictionary] = []
	var ids: Array = scouts.keys()
	ids.sort()
	for id: String in ids:
		scout_records.append(scouts[id].to_dict())
	var delivered: Array[Dictionary] = []
	var missions: Array[Dictionary] = []
	ids = scout_missions.keys()
	ids.sort()
	for id: String in ids:
		missions.append(scout_missions[id].to_dict())
	ids = delivered_observations.keys()
	ids.sort()
	for id: String in ids:
		delivered.append(delivered_observations[id].to_dict())
	# JSON numbers cannot represent all 64-bit RNG states exactly.
	return {"version": SNAPSHOT_VERSION, "seed": str(_seed), "rng_state": str(rng.state), "genetic_rng_state": str(genetic_rng.state),
		"scenario_id": _scenario_id, "clock": clock.to_dict(), "world": world.to_dict(), "colony": colony.to_dict(),
		"scouts": scout_records, "scout_missions": missions, "scout_losses": scout_losses.duplicate(), "next_scout_id": next_scout_id, "delivered_observations": delivered,
		"reinforcement": reinforcement.to_dict(), "supply": supply.to_dict(), "founding": founding.to_dict(), "knowledge": knowledge.to_dict(), "trails": trails.to_dict(), "rain": rain.to_dict(), "exploration": exploration.to_dict(), "daughter_exploration": daughter_exploration.to_dict(),
		"honeydew": honeydew.to_dict(), "predator": predator.to_dict(), "rival": rival.to_dict(), "swarm": swarm.to_dict(), "guest": guest.to_dict(), "journey_response": journey_response.to_dict()}


func active_scout_count() -> int:
	var count: int = scouts.size()
	for cohort: TransitCohort in trails.cohorts.values():
		if cohort.detour != null:
			count += 1
	return count


func recognition_share(pile_id: String) -> float:
	# Internal staffing decisions use colony-expected adults until journey losses return.
	var pile: PileState = colony.piles[pile_id]
	var expected: int = pile.workers_total + pending_for_pile(pile_id)
	var security: int = pile.genetics.count_trait("security") + pending_trait(pile_id, "security")
	var tolerance: int = pile.genetics.count_trait("tolerance") + pending_trait(pile_id, "tolerance")
	return snappedf(float(security - tolerance) / expected, 0.00001) if expected > 0 else 0.0

func pending_for_pile(pile_id: String, adapted: bool = false) -> int:
	var total: int = trails.pending_for_pile(pile_id, adapted)
	if pile_id == journey_response.origin_id(trails):
		total += journey_response.defense.adapted_lost if adapted else journey_response.defense.lost
	for agent: ScoutAgent in scouts.values():
		if agent.origin_pile == pile_id and agent.lost:
			total += agent.pending_trait(colony.piles[pile_id].adaptation_repertoire) if adapted else 1
	return total

func pending_trait(pile_id: String, trait_id: String) -> int:
	var total: int = trails.pending_trait(pile_id,trait_id) + (journey_response.defense.pending_trait(trait_id) if pile_id == journey_response.origin_id(trails) else 0)
	for agent: ScoutAgent in scouts.values():
		if agent.origin_pile == pile_id:
			total += agent.pending_trait(trait_id)
	return total


func missing_scouts(pile_id: String) -> int:
	var total: int = scout_losses.get(pile_id, 0)
	for agent: ScoutAgent in scouts.values():
		if agent.origin_pile == pile_id and agent.lost:
			total -= 1
	return total


func restore(data: Dictionary) -> bool:
	if not data.has_all(["version", "seed", "rng_state", "scenario_id", "clock", "world", "colony", "scouts", "next_scout_id", "delivered_observations", "knowledge", "trails", "rain"]):
		return false
	if data.version != SNAPSHOT_VERSION or not data.scenario_id is String or data.scenario_id.is_empty():
		return false
	for field: String in ["seed", "rng_state"]:
		if not data[field] is String or not data[field].is_valid_int() or str(data[field].to_int()) != data[field]:
			return false
	var restored_genetic_rng := RandomNumberGenerator.new()
	restored_genetic_rng.seed = data.seed.to_int() ^ 0x415450
	if data.has("genetic_rng_state"):
		if not data.genetic_rng_state is String or not data.genetic_rng_state.is_valid_int() or str(data.genetic_rng_state.to_int()) != data.genetic_rng_state:
			return false
		restored_genetic_rng.state = data.genetic_rng_state.to_int()
	var restored_world := World.new()
	var restored_clock := Clock.new()
	if not data.clock is Dictionary or not restored_clock.restore(data.clock):
		return false
	if not data.world is Dictionary or not restored_world.restore(data.world, Loader.definition_ids()):
		return false
	var restored_colony := Colony.new()
	if not data.colony is Dictionary or not restored_colony.restore(data.colony, restored_world.bounds, restored_world.home_position):
		return false
	var restored_exploration := Exploration.new()
	if data.has("exploration") and (not data.exploration is Dictionary or not restored_exploration.restore(data.exploration, restored_world, restored_clock.simulation_time)):
		return false
	var restored_daughter_exploration := Exploration.new()
	if data.has("daughter_exploration") and (not data.daughter_exploration is Dictionary or not restored_daughter_exploration.restore(data.daughter_exploration, restored_world, restored_clock.simulation_time)): return false
	if not restored_colony.piles.has("satellite_1") and restored_daughter_exploration.to_dict() != Exploration.new().to_dict(): return false
	if restored_exploration.target + restored_daughter_exploration.target > SCOUT_CONFIG.active_cap: return false
	if not data.scouts is Array or data.scouts.size() > SCOUT_CONFIG.active_cap or not WorkerLedger.valid_count(data.next_scout_id) or data.next_scout_id < 1:
		return false
	var restored_scouts: Dictionary[String, ScoutAgent] = {}
	for value: Variant in data.scouts:
		var agent := Scout.new()
		if not value is Dictionary or not agent.restore(value, restored_world, restored_colony, restored_clock.simulation_time) or restored_scouts.has(agent.id):
			return false
		var suffix: String = agent.id.trim_prefix("scout_")
		if not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_scout_id:
			return false
		restored_scouts[agent.id] = agent
	var scout_loss_data: Variant = data.get("scout_losses", {})
	if not scout_loss_data is Dictionary:
		return false
	var restored_scout_losses: Dictionary[String, int] = {}
	var all_scout_losses: int = 0
	for key: Variant in scout_loss_data:
		if not key is String or not restored_colony.piles.has(key) or not WorkerLedger.valid_count(scout_loss_data[key]) or scout_loss_data[key] < 1 or scout_loss_data[key] > restored_colony.piles[key].workers.lost_total:
			return false
		restored_scout_losses[key] = int(scout_loss_data[key])
		all_scout_losses += int(scout_loss_data[key])
	for pile: PileState in restored_colony.piles.values():
		var pending: int = 0
		for agent: ScoutAgent in restored_scouts.values():
			pending += 1 if agent.origin_pile == pile.id and agent.lost else 0
		if pending > restored_scout_losses.get(pile.id, 0):
			return false
	for pile: PileState in restored_colony.piles.values():
		for id: String in pile.workers.to_dict().commitments:
			if id.begins_with("scout_") and (not restored_scouts.has(id) or restored_scouts[id].origin_pile != pile.id):
				return false
	for origin_id: String in restored_colony.piles:
		var exploring_standing: int = 0
		var policy: ExplorationState = restored_exploration if origin_id == "home" else restored_daughter_exploration
		for agent: ScoutAgent in restored_scouts.values():
			if agent.standing and agent.origin_pile == origin_id:
				if not data.has("exploration" if origin_id == "home" else "daughter_exploration"): return false
				exploring_standing += 1 if not agent.lost and agent.phase not in ["returning", "blocked_returning"] else 0
		if exploring_standing > policy.target: return false
	if not data.delivered_observations is Array:
		return false
	var restored_missions: Dictionary[String, ScoutMissionMemory] = {}
	var returned_count: int = 0
	if data.has("scout_missions"):
		if not data.scout_missions is Array or data.scout_missions.size() > SCOUT_CONFIG.active_cap + MissionMemory.RECENT_RETURNS:
			return false
		for value: Variant in data.scout_missions:
			var memory := MissionMemory.new()
			if not value is Dictionary or not memory.restore(value, restored_colony, restored_scouts, int(data.next_scout_id), restored_clock.simulation_time) or restored_missions.has(memory.id):
				return false
			returned_count += 1 if memory.completed_at() >= 0.0 else 0
			restored_missions[memory.id] = memory
		if returned_count > MissionMemory.RECENT_RETURNS:
			return false
		for pile: PileState in restored_colony.piles.values():
			var known_missing: int = 0
			var pending_missing: int = 0
			for memory: ScoutMissionMemory in restored_missions.values():
				known_missing += 1 if memory.origin_pile == pile.id and memory.missing_at >= 0.0 else 0
			for agent: ScoutAgent in restored_scouts.values():
				pending_missing += 1 if agent.origin_pile == pile.id and agent.lost else 0
			if known_missing + pending_missing > restored_scout_losses.get(pile.id, 0):
				return false
	var restored_delivered: Dictionary[String, Observation] = {}
	for value: Variant in data.delivered_observations:
		var evidence := Evidence.new()
		if not value is Dictionary or not evidence.restore(value, restored_world, restored_colony, restored_clock.simulation_time):
			return false
		var suffix: String = evidence.scout_id.trim_prefix("scout_")
		if evidence.scout_id != "scout_" + suffix or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_scout_id:
			return false
		if restored_scouts.has(evidence.scout_id) or restored_delivered.has(evidence.id):
			return false
		restored_delivered[evidence.id] = evidence
	if not data.knowledge is Dictionary or not data.knowledge.has("observations") or not data.knowledge.observations is Array:
		return false
	var archived: Dictionary[String, Observation] = {}
	for record: Variant in data.knowledge.observations:
		var evidence := Evidence.new()
		if not record is Dictionary or not record.has("evidence") or not record.evidence is Dictionary or not evidence.restore(record.evidence, restored_world, restored_colony, restored_clock.simulation_time):
			return false
		var suffix: String = evidence.scout_id.trim_prefix("scout_")
		if evidence.scout_id != "scout_" + suffix or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_scout_id:
			return false
		if restored_scouts.has(evidence.scout_id) or archived.has(evidence.id) or restored_delivered.has(evidence.id):
			return false
		archived[evidence.id] = evidence
	var restored_knowledge := Knowledge.new()
	if not restored_knowledge.restore(data.knowledge, archived, restored_clock.simulation_time):
		return false
	for memory: ScoutMissionMemory in restored_missions.values():
		if memory.target_knowledge_id.is_empty(): continue # Legacy/general departures have no named target.
		if not restored_knowledge.nodes.has(memory.target_knowledge_id): return false
		if restored_scouts.has(memory.id) and "known:" + restored_scouts[memory.id].investigation_source_id != memory.target_knowledge_id: return false
	for priority: String in restored_exploration.priorities + restored_daughter_exploration.priorities:
		if not restored_knowledge.nodes.has(priority):
			return false
	for agent: ScoutAgent in restored_scouts.values():
		for source_id: String in agent.known_sources:
			if not restored_knowledge.nodes.has("known:" + source_id):
				return false
		if not agent.investigation_source_id.is_empty() and not restored_knowledge.nodes.has("known:" + agent.investigation_source_id):
			return false
	var restored_founding:=FoundingState.new()
	var founding_data: Variant=data.get("founding",restored_founding.to_dict())
	if not founding_data is Dictionary or not restored_founding.restore(founding_data,restored_colony,restored_clock.tick_count): return false
	var restored_supply:=InterpileSupplyState.new()
	var supply_data: Variant=data.get("supply",restored_supply.to_dict())
	if not supply_data is Dictionary or not restored_supply.restore(supply_data,restored_colony,restored_founding,restored_clock.tick_count): return false
	var restored_reinforcement:=WorkerReinforcementState.new()
	var reinforcement_data: Variant=data.get("reinforcement",restored_reinforcement.to_dict())
	if not reinforcement_data is Dictionary or not restored_reinforcement.restore(reinforcement_data,restored_colony,restored_founding,restored_supply,restored_clock.tick_count): return false
	var restored_trails := Trails.new()
	if not data.trails is Dictionary or not restored_trails.restore(data.trails, restored_colony, restored_knowledge, restored_world, restored_clock.simulation_time, restored_founding, restored_supply, restored_reinforcement):
		return false
	# One paid, physically reported foundation owns the only current daughter.
	var daughter: PileState=restored_colony.piles.get("satellite_1")
	if (daughter!=null)!=(restored_founding.phase=="established"): return false
	for pile: PileState in restored_colony.piles.values():
		if pile.id not in ["home","satellite_1"]: return false
		if pile.id=="home" and (not pile.foundation.is_empty() or pile.workers.transferred_in>0): return false
	if daughter!=null:
		var parent: PileState=restored_colony.piles.home
		var route: TrailRouteState=restored_trails.routes[restored_founding.route_id]
		if daughter.foundation.is_empty() or daughter.foundation.route_id!=route.id or daughter.position!=route.estimated_destination or daughter.foundation.queen_traits!=restored_founding.reproductive_group.inherited_traits: return false
		if daughter.foundation.founded_tick<restored_founding.reported_tick or daughter.foundation.founded_tick>restored_clock.tick_count: return false
		var migrants: int=FoundingState.CONFIG.workers-1+restored_reinforcement.arrivals*WorkerReinforcementState.CONFIG.reinforcement_workers
		if parent.workers.transferred_out!=migrants or daughter.workers.transferred_in!=migrants or daughter.workers.transferred_out!=0: return false
		if daughter.genetics.imported!=parent.genetics.exported: return false
	for agent: ScoutAgent in restored_scouts.values():
		for route_id: String in agent.avoid_routes:
			if not restored_trails.routes.has(route_id) or restored_trails.routes[route_id].origin_pile != agent.origin_pile or restored_trails.routes[route_id].reported_losses < 1:
				return false
		if not agent.trunk_route_id.is_empty():
			if not restored_trails.routes.has(agent.trunk_route_id):
				return false
			var route: TrailRouteState = restored_trails.routes[agent.trunk_route_id]
			if route.origin_pile != agent.origin_pile or route.delivered_total <= 0 or route.estimated_destination.round() != agent.trunk_path.back():
				return false
	var used_scout_ids: Dictionary[String, bool] = {}
	for id: String in restored_scouts:
		used_scout_ids[id] = true
	for evidence: Observation in restored_delivered.values():
		used_scout_ids[evidence.scout_id] = true
	for evidence: Observation in archived.values():
		used_scout_ids[evidence.scout_id] = true
	var active_detours: int = 0
	for cohort: TransitCohort in restored_trails.cohorts.values():
		var scout_id: String = ""
		if cohort.detour != null:
			active_detours += 1
			scout_id = cohort.detour.id
		elif cohort.detour_report != null:
			scout_id = cohort.detour_report.scout_id
		if scout_id.is_empty():
			continue
		var suffix: String = scout_id.trim_prefix("scout_")
		if scout_id != "scout_" + suffix or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_scout_id or used_scout_ids.has(scout_id):
			return false
		used_scout_ids[scout_id] = true
	if restored_scouts.size() + active_detours > SCOUT_CONFIG.active_cap:
		return false
	var restored_rain := Rain.new()
	if not data.rain is Dictionary or not restored_rain.restore(data.rain, restored_clock.tick_count):
		return false
	var restored_honeydew := Honeydew.new()
	if data.has("honeydew") and (not data.honeydew is Dictionary or not restored_honeydew.restore(data.honeydew)):
		return false
	if not _valid_honeydew(restored_honeydew, restored_world, restored_colony, restored_knowledge, restored_trails):
		return false
	var restored_rival := Rival.new()
	if data.has("rival") and (not data.rival is Dictionary or not restored_rival.restore(data.rival, restored_world, restored_clock.tick_count)):
		return false
	var restored_response := JourneyResponseState.new()
	var response_data: Variant = data.get("journey_response",restored_response.to_dict())
	if not response_data is Dictionary or not restored_response.restore(response_data,restored_colony,restored_trails,restored_clock.simulation_time): return false
	var contacts: int = restored_rival.unreturned_contacts + (1 if restored_response.foreign_seen else 0)
	for route: TrailRouteState in restored_trails.routes.values():
		if (route.conflict_report != "" and route.conflict_observed_at < Rival.CONFIG.first_tick * Clock.TICK_INTERVAL) or route.foreign_reports > restored_rival.contacts_total - contacts or (route.foreign_reports > 0 and route.last_foreign_time < Rival.CONFIG.first_tick * Clock.TICK_INTERVAL):
			return false
		contacts += route.foreign_reports
	for cohort: TransitCohort in restored_trails.cohorts.values():
		if cohort.conflict_report != "" and cohort.conflict_observed_at < Rival.CONFIG.first_tick * Clock.TICK_INTERVAL:
			return false
		if cohort.foreign_contact:
			contacts += 1
	if contacts != restored_rival.contacts_total:
		return false
	var restored_swarm := Swarm.new()
	if data.has("swarm") and (not data.swarm is Dictionary or not restored_swarm.restore(data.swarm, restored_trails, restored_rival, restored_world, restored_clock.tick_count)):
		return false
	if not data.has("swarm"):
		for cohort: TransitCohort in restored_trails.cohorts.values():
			if cohort.swarm_engaged or cohort.rival_losses > 0 or cohort.conflict_report != "":
				return false
		for route: TrailRouteState in restored_trails.routes.values():
			if route.reported_rival_losses > 0 or route.conflict_report != "":
				return false
	var restored_predator := Predator.new()
	if data.has("predator") and (not data.predator is Dictionary or not restored_predator.restore(data.predator, restored_clock.tick_count)):
		return false
	var casualties: int = 0
	var predator_casualties: int = 0
	var losses_by_pile: Dictionary[String, int] = {}
	for route: TrailRouteState in restored_trails.routes.values():
		var losses: int = route.reported_losses + restored_trails.pending_losses(route.id)
		var pile_losses: int = losses_by_pile.get(route.origin_pile, 0)
		if losses > restored_colony.piles[route.origin_pile].workers.lost_total - pile_losses or losses > restored_predator.kills_total + restored_swarm.player_losses - casualties:
			return false
		if route.reported_losses > 0 and route.last_loss_time < Predator.CONFIG.first_tick * Clock.TICK_INTERVAL:
			return false
		losses_by_pile[route.origin_pile] = pile_losses + losses
		casualties += losses
		predator_casualties += route.reported_losses - route.reported_rival_losses
		for cohort: TransitCohort in restored_trails.cohorts.values():
			if cohort.route_id == route.id:
				predator_casualties += cohort.lost_workers - cohort.rival_losses
	if predator_casualties + all_scout_losses != restored_predator.kills_total:
		return false
	for pile_id: String in restored_scout_losses:
		var recorded: int = losses_by_pile.get(pile_id, 0) + restored_scout_losses[pile_id]
		if recorded > restored_colony.piles[pile_id].workers.lost_total:
			return false
		losses_by_pile[pile_id] = recorded
	var defense: JourneyDefenseState = restored_response.defense
	if defense.reported_losses + defense.lost != restored_predator.defense_losses: return false
	var defense_origin: String = restored_response.origin_id(restored_trails)
	for pile: PileState in restored_colony.piles.values():
		var owned_losses: int = defense.reported_for_pile(pile.id) + (defense.lost if pile.id == defense_origin else 0)
		if owned_losses > pile.workers.lost_total - losses_by_pile.get(pile.id,0): return false
		losses_by_pile[pile.id] = losses_by_pile.get(pile.id,0) + owned_losses
	if defense.outcome == "secured" and defense.observed_at != restored_predator.defeated_at: return false
	for record: Dictionary in defense.outcomes.values():
		if record.outcome == "secured" and record.observed_at != restored_predator.defeated_at: return false
	if restored_response.phase == "fighting":
		var segment: TrailSegmentState = restored_trails.segments[restored_trails.routes[restored_response.route_id].segment_id]
		var point: Vector2 = segment.start.lerp(segment.end,float(restored_response.elapsed_ticks) / JourneyResponseState.TRAILS.leg_ticks(segment.start.distance_to(segment.end)))
		if restored_predator.defeated_at > 0 or restored_clock.tick_count < Predator.CONFIG.first_tick or point.distance_to(Predator.CONFIG.position) > Predator.CONFIG.radius: return false
	for pile: PileState in restored_colony.piles.values():
		var pending: int = restored_trails.pending_for_pile(pile.id) + (defense.lost if pile.id == defense_origin else 0)
		var pending_adapted: int = restored_trails.pending_for_pile(pile.id,true) + (defense.adapted_lost if pile.id == defense_origin else 0)
		var profiles: Dictionary[String,int] = {}
		if pile.id==defense_origin: profiles.assign(defense.lost_profiles)
		for agent: ScoutAgent in restored_scouts.values():
			if agent.origin_pile == pile.id and agent.lost:
				pending += 1
				pending_adapted += agent.pending_trait(pile.adaptation_repertoire)
				if agent.lost_profile != "":
					profiles[agent.lost_profile] = profiles.get(agent.lost_profile, 0) + 1
		if pending_adapted > pile.adapted_workers_lost or pending > WorkerLedger.MAX_COUNT - pile.workers_total:
			return false
		if pile.food_toxicity.last_loss_tick > restored_clock.tick_count or pile.food_toxicity.losses > pile.workers.lost_total - losses_by_pile.get(pile.id,0): return false
		if pile.rain_trace_observed and restored_rain.phase == "waiting":
			return false
		for trait_id: String in pile.genetics.established:
			var pending_count: int = restored_trails.pending_trait(pile.id, trait_id) + (defense.pending_trait(trait_id) if pile.id == defense_origin else 0)
			for agent: ScoutAgent in restored_scouts.values():
				if agent.origin_pile == pile.id:
					pending_count += agent.pending_trait(trait_id)
			if pending_count > pile.genetics.count_trait(trait_id, true):
				return false
		for cohort: TransitCohort in restored_trails.cohorts.values():
			if restored_trails.routes[cohort.route_id].origin_pile == pile.id:
				for key: String in cohort.lost_profiles: profiles[key] = profiles.get(key,0) + cohort.lost_profiles[key]
		for key: String in profiles:
			if profiles[key] > pile.genetics.lost.get(key,0): return false
	var restored_guest := Guest.new()
	if data.has("guest") and (not data.guest is Dictionary or not restored_guest.restore(data.guest, restored_colony.piles.home, restored_clock.tick_count)):
		return false
	if restored_colony.piles.home.recognition_experience and restored_guest.phase == "absent" and restored_honeydew.relationship != "tended":
		# A withdrawn relationship still has an observable loaded route history.
		if restored_honeydew.relationship == "unknown":
			return false
	for pile: PileState in restored_colony.piles.values():
		for commitment: String in pile.workers.to_dict().commitments:
			if commitment.begins_with("rejection:") and (pile.id != "home" or commitment != "rejection:home" or restored_guest.phase != "rejecting"):
				return false
		if pile.brood_health.last_loss_tick > restored_clock.tick_count:
			return false
		if pile.reproduction.laid_tick > restored_clock.tick_count: return false
		var reproductive: ReproductionState = pile.reproduction
		var minimum_ticks: float = float(reproductive.progress_quarters)/4.0
		if reproductive.phase in ["larva","pupa","ready"]: minimum_ticks+=reproductive.CONFIG.egg_ticks
		if reproductive.phase in ["pupa","ready"]: minimum_ticks+=reproductive.CONFIG.larva_ticks
		if reproductive.phase=="ready": minimum_ticks+=reproductive.CONFIG.pupa_ticks
		if minimum_ticks > restored_clock.tick_count-reproductive.laid_tick: return false
		if pile.brood_lost_total != pile.brood_health.losses + (restored_guest.reported_losses if pile.id == "home" else 0):
			return false
	if not data.clock is Dictionary or not clock.restore(data.clock):
		return false
	_seed = data.seed.to_int()
	_scenario_id = data.scenario_id
	# Seed first: assigning seed resets generator state.
	rng.seed = _seed
	rng.state = data.rng_state.to_int()
	genetic_rng = restored_genetic_rng
	world = restored_world
	colony = restored_colony
	scouts = restored_scouts
	scout_missions = restored_missions
	scout_losses = restored_scout_losses
	next_scout_id = int(data.next_scout_id)
	delivered_observations = restored_delivered
	knowledge = restored_knowledge
	reinforcement = restored_reinforcement
	supply = restored_supply
	founding = restored_founding
	trails = restored_trails
	rain = restored_rain
	honeydew = restored_honeydew
	predator = restored_predator
	journey_response = restored_response
	rival = restored_rival
	swarm = restored_swarm
	guest = restored_guest
	exploration = restored_exploration
	daughter_exploration = restored_daughter_exploration
	return true


static func _valid_honeydew(state: HoneydewState, restored_world: WorldState, restored_colony: ColonyState, restored_knowledge: KnowledgeBase, restored_trails: TrailNetwork) -> bool:
	var source_id: String = HONEYDEW_CONFIG.source_id
	var commitment_id: String = "honeydew:home"
	var has_source: bool = restored_world.nodes.has(source_id)
	if has_source and restored_world.nodes[source_id].definition_id != "carbohydrate":
		return false
	if not has_source and state.relationship != "unknown":
		return false
	if state.relationship != "unknown":
		if not restored_knowledge.nodes.has("known:" + source_id):
			return false
		var route: TrailRouteState = restored_trails.find_route("home", "known:" + source_id)
		if route == null or route.delivered_total <= 0.0:
			return false
	for pile: PileState in restored_colony.piles.values():
		var commitments: Dictionary = pile.workers.to_dict().commitments
		for id: String in commitments:
			if id.begins_with("honeydew:") and (pile.id != "home" or id != commitment_id):
				return false
		if pile.id == "home":
			if state.recognition_share > 0 and "security" not in pile.genetics.established or state.recognition_share < 0 and "tolerance" not in pile.genetics.established:
				return false
			if state.relationship == "tended":
				if not commitments.has(commitment_id) or commitments[commitment_id].kind != "other" or commitments[commitment_id].owner_id != source_id or commitments[commitment_id].count != state.protection_workers:
					return false
			elif commitments.has(commitment_id):
				return false
	return true
