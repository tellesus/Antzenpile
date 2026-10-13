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
var history := RunHistory.new()
var supply := InterpileSupplyState.new()
var daughter_supply := InterpileSupplyState.new()
var supply_origin: String = "home"
var reinforcement := WorkerReinforcementState.new()
var founding := FoundingState.new()
var connection_traffic: Dictionary[String,ConnectionTrafficState]={}
var extra_foundings: Dictionary[String,FoundingState]={}
var extra_exploration: Dictionary[String,ExplorationState]={}
var exploration: ExplorationState = Exploration.new()
var daughter_exploration: ExplorationState = Exploration.new()
var world: WorldState
var colony: ColonyState = Colony.new()
var scouts: Dictionary[String, ScoutAgent] = {}
var scout_missions: Dictionary[String, ScoutMissionMemory] = {}
var scout_losses: Dictionary[String, int] = {}
var next_scout_id: int = 1
var knowledge: KnowledgeBase = Knowledge.new()
var reports: ReportJournal = preload("res://src/sim/knowledge/report_journal.gd").new()
var trails: TrailNetwork = Trails.new()
var rain: RainState = Rain.new()
var honeydew: HoneydewState = Honeydew.new()
var swarm: SwarmState = Swarm.new()
var guest: GuestState = Guest.new()
var rival: RivalState = Rival.new()
var surface_impact := SurfaceImpactState.new()
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
	return exploration if pile_id == "home" else daughter_exploration if pile_id == "satellite_1" else extra_exploration.get(pile_id)


func _init(seed_value: int = 482817, scenario: String = "backyard_slice") -> void:
	surface_impact.enabled = scenario == "roadside"
	_seed = seed_value
	_scenario_id = scenario
	rng.seed = _seed
	genetic_rng.seed = _seed ^ 0x415450
	world = Loader.new().load_scenario(Scenarios.path_for(scenario))
	assert(world != null, "Run construction requires a registered authored scenario")
	colony.initialize_home(world.home_position)
	history.record(self,true)


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
	var camps: Array[Dictionary]=[];var policies: Dictionary={};var traffic: Dictionary={}
	for connection: ConnectionTrafficState in all_connections():traffic[connection.route_id]=connection.to_dict()
	ids=extra_foundings.keys();ids.sort()
	for id: String in ids: camps.append(extra_foundings[id].to_dict())
	ids=extra_exploration.keys();ids.sort()
	for id: String in ids: policies[id]=extra_exploration[id].to_dict()
	# JSON numbers cannot represent all 64-bit RNG states exactly.
	return {"connection_traffic":traffic,"extra_foundings":camps,"extra_exploration":policies,"reports":reports.to_dict(), "history":history.to_dict(), "version": SNAPSHOT_VERSION, "seed": str(_seed), "rng_state": str(rng.state), "genetic_rng_state": str(genetic_rng.state),
		"scenario_id": _scenario_id, "clock": clock.to_dict(), "world": world.to_dict(), "colony": colony.to_dict(),
		"scouts": scout_records, "scout_missions": missions, "scout_losses": scout_losses.duplicate(), "next_scout_id": next_scout_id, "delivered_observations": delivered,
		"daughter_supply":daughter_supply.to_dict(), "supply_origin":supply_origin,
		"reinforcement": reinforcement.to_dict(), "supply": supply.to_dict(), "founding": founding.to_dict(), "knowledge": knowledge.to_dict(), "trails": trails.to_dict(), "rain": rain.to_dict(), "exploration": exploration.to_dict(), "daughter_exploration": daughter_exploration.to_dict(),
		"surface_impact":surface_impact.to_dict(), "honeydew": honeydew.to_dict(), "predator": predator.to_dict(), "rival": rival.to_dict(), "swarm": swarm.to_dict(), "guest": guest.to_dict(), "journey_response": journey_response.to_dict()}


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
	var restored_history := RunHistory.new()
	if data.has("history") and not restored_history.restore(data.history,restored_clock.tick_count,restored_world.bounds,restored_clock.paused): return false
	var restored_colony := Colony.new()
	if not data.colony is Dictionary or not restored_colony.restore(data.colony, restored_world.bounds, restored_world.home_position):
		return false
	var restored_exploration := Exploration.new()
	if data.has("exploration") and (not data.exploration is Dictionary or not restored_exploration.restore(data.exploration, restored_world, restored_clock.simulation_time)):
		return false
	var restored_daughter_exploration := Exploration.new()
	if data.has("daughter_exploration") and (not data.daughter_exploration is Dictionary or not restored_daughter_exploration.restore(data.daughter_exploration, restored_world, restored_clock.simulation_time)): return false
	if not restored_colony.piles.has("satellite_1") and restored_daughter_exploration.to_dict() != Exploration.new().to_dict(): return false
	var restored_extra_exploration: Dictionary[String,ExplorationState]={}
	var extra_policies: Variant=data.get("extra_exploration",{})
	if not extra_policies is Dictionary: return false
	for id: Variant in extra_policies:
		if not id is String or id in ["home","satellite_1"] or not restored_colony.piles.has(id) or not extra_policies[id] is Dictionary: return false
		var policy:=Exploration.new()
		if not policy.restore(extra_policies[id],restored_world,restored_clock.simulation_time): return false
		restored_extra_exploration[id]=policy
	var restored_policies: Dictionary[String,ExplorationState]={"home":restored_exploration,"satellite_1":restored_daughter_exploration}
	for id: String in restored_colony.piles:
		if id not in ["home","satellite_1"]:
			if not restored_extra_exploration.has(id): return false
			restored_policies[id]=restored_extra_exploration[id]
	var exploration_target: int=0
	for policy: ExplorationState in restored_policies.values(): exploration_target+=policy.target
	if exploration_target>SCOUT_CONFIG.active_cap: return false
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
		var policy: ExplorationState = restored_policies[origin_id]
		for agent: ScoutAgent in restored_scouts.values():
			if agent.standing and agent.origin_pile == origin_id:
				if not data.has("exploration" if origin_id == "home" else "daughter_exploration" if origin_id=="satellite_1" else "extra_exploration"): return false
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
	for policy: ExplorationState in restored_policies.values():
		for priority: String in policy.priorities:
			if not restored_knowledge.nodes.has(priority): return false
	for agent: ScoutAgent in restored_scouts.values():
		for source_id: String in agent.known_sources:
			if not restored_knowledge.nodes.has("known:" + source_id):
				return false
		if not agent.investigation_source_id.is_empty() and not restored_knowledge.nodes.has("known:" + agent.investigation_source_id):
			return false
	var restored_founding:=FoundingState.new()
	var founding_data: Variant=data.get("founding",restored_founding.to_dict())
	if not founding_data is Dictionary or not restored_founding.restore(founding_data,restored_colony,restored_clock.tick_count,restored_world): return false
	if restored_founding.origin_pile!="home" or restored_founding.destination_pile!="satellite_1": return false
	var restored_extra_foundings: Dictionary[String,FoundingState]={}
	var extra_camps: Variant=data.get("extra_foundings",[])
	if not extra_camps is Array or extra_camps.size()>restored_world.nodes.size()*restored_colony.piles.size(): return false
	for record: Variant in extra_camps:
		var camp:=FoundingState.new()
		if not record is Dictionary or not camp.restore(record,restored_colony,restored_clock.tick_count,restored_world) or camp.phase=="none" or camp.destination_pile=="satellite_1" or camp.route_id==restored_founding.route_id or restored_extra_foundings.has(camp.route_id): return false
		restored_extra_foundings[camp.route_id]=camp
	var restored_camps: Array[FoundingState]=[restored_founding]
	for camp: FoundingState in restored_extra_foundings.values(): restored_camps.append(camp)
	var restored_supply:=InterpileSupplyState.new()
	var supply_data: Variant=data.get("supply",restored_supply.to_dict())
	if not supply_data is Dictionary or not restored_supply.restore(supply_data,restored_colony,restored_founding,restored_clock.tick_count): return false
	var restored_daughter_supply := InterpileSupplyState.new()
	var daughter_supply_data: Variant = data.get("daughter_supply",restored_daughter_supply.to_dict())
	if not daughter_supply_data is Dictionary or not restored_daughter_supply.restore(daughter_supply_data,restored_colony,restored_founding,restored_clock.tick_count,"satellite_1"): return false
	var restored_supply_origin: Variant = data.get("supply_origin","home")
	if restored_supply_origin not in ["home","satellite_1"] or restored_supply_origin == "satellite_1" and not restored_colony.piles.has("satellite_1"): return false
	if restored_supply.phase != "none" and (restored_daughter_supply.phase != "none" or restored_supply_origin != "home"): return false
	if restored_daughter_supply.phase != "none" and restored_supply_origin != "satellite_1": return false
	var active_supply: InterpileSupplyState = restored_supply if restored_supply_origin == "home" else restored_daughter_supply
	var restored_reinforcement:=WorkerReinforcementState.new()
	var reinforcement_data: Variant=data.get("reinforcement",restored_reinforcement.to_dict())
	if not reinforcement_data is Dictionary or not restored_reinforcement.restore(reinforcement_data,restored_colony,restored_founding,restored_supply,restored_clock.tick_count): return false
	if restored_reinforcement.active() and (restored_daughter_supply.phase != "none" or restored_supply_origin != "home"): return false
	var restored_connections: Dictionary[String,ConnectionTrafficState]={}
	for camp: FoundingState in restored_camps:
		if camp.phase!="established":continue
		var connection:=ConnectionTrafficState.new(camp)
		if camp==restored_founding:
			connection.legacy=true;connection.payer_id=restored_supply_origin
			connection.supplies["home"]=restored_supply;connection.supplies["satellite_1"]=restored_daughter_supply;connection.migrations["home"]=restored_reinforcement
		restored_connections[camp.route_id]=connection
	var traffic_data: Variant=data.get("connection_traffic",{})
	if not traffic_data is Dictionary:return false
	if data.has("connection_traffic") and (traffic_data.size()!=restored_connections.size() or not traffic_data.has_all(restored_connections.keys())):return false
	for id: String in traffic_data:
		if not traffic_data[id] is Dictionary or not restored_connections[id].restore(traffic_data[id],restored_colony,_camp_from(restored_camps,id),restored_clock.tick_count):return false
	var restored_trails := Trails.new()
	if not data.trails is Dictionary or not restored_trails.restore(data.trails, restored_colony, restored_knowledge, restored_world, restored_clock.simulation_time, restored_founding, active_supply, restored_reinforcement, restored_supply_origin, restored_extra_foundings.values(),restored_connections):
		return false
	if not _valid_foundations(restored_colony,restored_camps,restored_trails,restored_clock.tick_count,restored_reinforcement,restored_connections) or not _valid_queen_transports(restored_colony,restored_connections) or not _valid_brood_transports(restored_colony,restored_connections) or not _valid_royal_transports(restored_colony,restored_connections,restored_camps) or not _valid_evacuations(restored_colony,restored_connections): return false
	# A paid young queen has one current body owner; founding history is not stock.
	var reproductive_bodies: Dictionary={}
	for pile: PileState in restored_colony.piles.values():
		reproductive_bodies[pile.queen.queen_id(pile.id)]=true
	for pile: PileState in restored_colony.piles.values():
		var groups: Array[Dictionary]=[]
		if pile.reproduction.phase!="none": groups.append(pile.reproduction.to_dict())
		if pile.queen.replacing(): groups.append(pile.queen.replacement_group)
		for group: Dictionary in groups:
			var identity: String=ReproductionState.body_identity(group,pile.id)
			if reproductive_bodies.has(identity): return false
			reproductive_bodies[identity]=true
	for camp: FoundingState in restored_camps:
		if camp.phase not in ["outbound","settling","messenger","returning","ready"]: continue
		var identity: String=ReproductionState.body_identity(camp.reproductive_group,camp.origin_pile)
		if reproductive_bodies.has(identity): return false
		reproductive_bodies[identity]=true
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
	for camp: FoundingState in restored_camps:
		if camp.site_report==null: continue
		var report: Observation=camp.site_report
		var suffix: String=report.scout_id.trim_prefix("scout_")
		if report.scout_id!="scout_"+suffix or not suffix.is_valid_int() or str(suffix.to_int())!=suffix or suffix.to_int()<1 or suffix.to_int()>=data.next_scout_id: return false
		if camp.reported_tick==0:
			if used_scout_ids.has(report.scout_id): return false
			used_scout_ids[report.scout_id]=true
		else:
			var delivered: Observation=restored_delivered.get(report.id,archived.get(report.id))
			if delivered==null or delivered.to_dict()!=report.to_dict(): return false
			if archived.has(report.id) and restored_knowledge._received_at[report.id]<camp.reported_tick*SimulationClock.TICK_INTERVAL: return false
	var active_detours: int = 0
	for cohort: TransitCohort in restored_trails.cohorts.values():
		var sample_ids: Array[String] = []
		if cohort.detour != null:
			active_detours += 1
			sample_ids.append(cohort.detour.id)
		elif cohort.detour_report != null:
			sample_ids.append(cohort.detour_report.scout_id)
		if cohort.harvest_report != null: sample_ids.append(cohort.harvest_report.scout_id)
		for scout_id: String in sample_ids:
			var suffix: String = scout_id.trim_prefix("scout_")
			if scout_id != "scout_" + suffix or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_scout_id or used_scout_ids.has(scout_id): return false
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
	if not response_data is Dictionary or not restored_response.restore(response_data,restored_colony,restored_trails,restored_clock.simulation_time,restored_world): return false
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
	var restored_impact := SurfaceImpactState.new()
	if not restored_impact.restore(data.get("surface_impact", restored_impact.to_dict()), restored_clock.tick_count, data.seed.to_int(), data.scenario_id): return false
	var impact_casualties: int = 0
	var casualties: int = 0
	var predator_casualties: int = 0
	var losses_by_pile: Dictionary[String, int] = {}
	for route: TrailRouteState in restored_trails.routes.values():
		var losses: int = route.reported_losses + restored_trails.pending_losses(route.id)
		var pile_losses: int = losses_by_pile.get(route.origin_pile, 0)
		if losses > restored_colony.piles[route.origin_pile].workers.lost_total - pile_losses or losses > restored_predator.kills_total + restored_swarm.player_losses + restored_impact.kills_total - casualties:
			return false
		if route.reported_losses - route.reported_impact_losses > 0 and route.last_loss_time < Predator.CONFIG.first_tick * Clock.TICK_INTERVAL:
			return false
		losses_by_pile[route.origin_pile] = pile_losses + losses
		casualties += losses
		impact_casualties += route.reported_impact_losses
		if not route.impact_report.is_empty() and (not restored_impact.enabled or route.impact_report.observed_at < SurfaceImpactState.first_tick(data.seed.to_int()) * Clock.TICK_INTERVAL): return false
		predator_casualties += route.reported_losses - route.reported_rival_losses - route.reported_impact_losses
		for cohort: TransitCohort in restored_trails.cohorts.values():
			if cohort.route_id == route.id:
				impact_casualties += cohort.impact_losses
				if cohort.impact_serial > restored_impact.serial or cohort.impact_losses > cohort.impact_serial or cohort.impact_witness_at > 0 and cohort.impact_witness_at < SurfaceImpactState.first_tick(data.seed.to_int()) * Clock.TICK_INTERVAL: return false
				predator_casualties += cohort.lost_workers - cohort.rival_losses - cohort.impact_losses
	if restored_response.impact_fraction >= 0 and not restored_impact.enabled: return false
	for id: String in restored_response.reports:
		var report: Dictionary = restored_response.reports[id]
		if report.finding == "surface" and (not restored_impact.enabled or report.observed_at < SurfaceImpactState.first_tick(data.seed.to_int()) * Clock.TICK_INTERVAL): return false
	for id: String in restored_response.orders.targets:
		var impact: Dictionary = restored_trails.routes[id].impact_report
		if restored_response.orders.targets[id] > 0 and not impact.is_empty() and impact.received_at >= restored_response.reports.get(id, {}).get("received_at", 0.0): return false
	if impact_casualties != restored_impact.kills_total: return false
	if predator_casualties + all_scout_losses != restored_predator.kills_total:
		return false
	for pile_id: String in restored_scout_losses:
		var recorded: int = losses_by_pile.get(pile_id, 0) + restored_scout_losses[pile_id]
		if recorded > restored_colony.piles[pile_id].workers.lost_total:
			return false
		losses_by_pile[pile_id] = recorded
	var defense: JourneyDefenseState = restored_response.defense
	if not PredatorCarcass.valid(restored_world, restored_predator): return false
	if defense.reported_losses + defense.lost != restored_predator.defense_losses: return false
	var defense_origin: String = restored_response.origin_id(restored_trails)
	for pile: PileState in restored_colony.piles.values():
		var owned_losses: int = defense.reported_for_pile(pile.id) + (defense.lost if pile.id == defense_origin else 0)
		if owned_losses > pile.workers.lost_total - losses_by_pile.get(pile.id,0): return false
		losses_by_pile[pile.id] = losses_by_pile.get(pile.id,0) + owned_losses
	if defense.outcome == "secured" and defense.observed_at != restored_predator.defeated_at: return false
	if defense.outcome == "secured" and defense.goal == "hunt" and not restored_predator.killed: return false
	for record: Dictionary in defense.outcomes.values():
		if record.outcome == "secured" and record.observed_at != restored_predator.defeated_at: return false
		if record.outcome == "secured" and record.get("goal", "clear") == "hunt" and not restored_predator.killed: return false
	if restored_response.phase == "fighting":
		var segment: TrailSegmentState = restored_trails.segments[restored_trails.routes[restored_response.route_id].segment_id]
		var point: Vector2 = segment.point_at(float(restored_response.elapsed_ticks) / JourneyResponseState.TRAILS.leg_ticks(segment.length()))
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
		if pile.queen.replacing() and (pile.queen.replacement_started>restored_clock.tick_count or pile.queen.replacement_progress>restored_clock.tick_count-pile.queen.replacement_started): return false
		for project: ChamberProject in pile.chambers.projects.values():
			if project.funded_tick>restored_clock.tick_count or project.progress_ticks>restored_clock.tick_count-project.funded_tick: return false
		var reproductive: ReproductionState = pile.reproduction
		var minimum_ticks: float = reproductive.progress_ticks()
		if reproductive.phase in ["larva","pupa","ready"]: minimum_ticks+=reproductive.CONFIG.egg_ticks
		if reproductive.phase in ["pupa","ready"]: minimum_ticks+=reproductive.CONFIG.larva_ticks
		if reproductive.phase=="ready": minimum_ticks+=reproductive.CONFIG.pupa_ticks
		if minimum_ticks > restored_clock.tick_count-reproductive.laid_tick: return false
		if pile.brood_lost_total != pile.brood_health.losses + (restored_guest.reported_losses if pile.id == "home" else 0):
			return false
	var restored_reports := preload("res://src/sim/knowledge/report_journal.gd").new()
	if not restored_reports.restore(data.get("reports",restored_reports.to_dict()),restored_colony,restored_knowledge,restored_trails,restored_clock.simulation_time): return false
	if not data.clock is Dictionary or not clock.restore(data.clock):
		return false
	_seed = data.seed.to_int()
	_scenario_id = data.scenario_id
	# Seed first: assigning seed resets generator state.
	rng.seed = _seed
	rng.state = data.rng_state.to_int()
	genetic_rng = restored_genetic_rng
	history = restored_history
	world = restored_world
	colony = restored_colony
	scouts = restored_scouts
	scout_missions = restored_missions
	scout_losses = restored_scout_losses
	next_scout_id = int(data.next_scout_id)
	delivered_observations = restored_delivered
	knowledge = restored_knowledge
	reports = restored_reports
	reinforcement = restored_reinforcement
	supply = restored_supply
	daughter_supply = restored_daughter_supply
	supply_origin = restored_supply_origin
	founding = restored_founding
	extra_foundings=restored_extra_foundings
	connection_traffic=restored_connections
	extra_exploration=restored_extra_exploration
	trails = restored_trails
	rain = restored_rain
	honeydew = restored_honeydew
	surface_impact = restored_impact
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

func all_foundings() -> Array[FoundingState]:
	var result: Array[FoundingState]=[founding]
	var keys: Array=extra_foundings.keys();keys.sort()
	for id: String in keys: result.append(extra_foundings[id])
	return result
func all_exploration() -> Dictionary[String,ExplorationState]:
	var result: Dictionary[String,ExplorationState]={"home":exploration}
	if colony.piles.has("satellite_1"):result.satellite_1=daughter_exploration
	for id: String in extra_exploration:result[id]=extra_exploration[id]
	return result
func other_exploration_target(pile_id: String) -> int:
	var total: int=0
	for id: String in all_exploration():
		if id!=pile_id: total+=all_exploration()[id].target
	return total

static func _profile_sum(into: Dictionary, pile_id: String, profiles: Dictionary) -> void:
	if not into.has(pile_id):into[pile_id]={}
	for key: String in profiles:into[pile_id][key]=into[pile_id].get(key,0)+profiles[key]
static func _valid_foundations(colony_state: ColonyState, camps: Array[FoundingState], network: TrailNetwork, tick: int, reinforcements: WorkerReinforcementState, connections: Dictionary={}) -> bool:
	var established: Dictionary={};var destinations: Dictionary={};var sites: Dictionary={};var active_origins: Dictionary={}
	var incoming: Dictionary={};var outgoing: Dictionary={};var gene_in: Dictionary={};var gene_out: Dictionary={}
	for camp: FoundingState in camps:
		if camp.phase=="none":continue
		if not network.routes.has(camp.route_id):return false
		var route: TrailRouteState=network.routes[camp.route_id]
		var parent: PileState=colony_state.piles[camp.origin_pile]
		if camp.departed_tick<parent.foundation.get("founded_tick",0):return false
		if camp.phase not in ["failed","established"]:
			if active_origins.has(parent.id):return false
			active_origins[parent.id]=true
		if camp.phase!="failed":
			if sites.has(route.destination_knowledge_id) or destinations.has(camp.destination_pile):return false
			sites[route.destination_knowledge_id]=true;destinations[camp.destination_pile]=true
		if camp.phase!="established":
			if camp.phase!="failed" and colony_state.piles.has(camp.destination_pile):return false
			continue
		if not colony_state.piles.has(camp.destination_pile):return false
		var child: PileState=colony_state.piles[camp.destination_pile]
		if child.foundation.is_empty() or child.foundation.parent_id!=parent.id or child.foundation.route_id!=route.id or child.position!=route.estimated_destination or child.foundation.queen_traits!=camp.reproductive_group.inherited_traits or child.foundation.get("site_profile","")!=camp.site_profile:return false
		if child.foundation.founded_tick<camp.reported_tick or child.foundation.founded_tick>tick:return false
		if not camp.profiles_recorded:
			# The only old foundation is exactly recoverable from its transfer history.
			if camp.origin_pile!="home" or camp.destination_pile!="satellite_1":return false
			camp.settler_profiles=child.genetics.imported.duplicate()
			for key: String in reinforcements.moved_profiles:
				var amount: int=camp.settler_profiles.get(key,0)-reinforcements.moved_profiles[key]
				if amount<0:return false
				if amount==0:camp.settler_profiles.erase(key)
				else:camp.settler_profiles[key]=amount
			if child.genetics.migration_count(camp.settler_profiles)!=FoundingState.CONFIG.workers-1:return false
			camp.profiles_recorded=true
		established[child.id]=true
		incoming[child.id]=incoming.get(child.id,0)+FoundingState.CONFIG.workers-1
		outgoing[parent.id]=outgoing.get(parent.id,0)+FoundingState.CONFIG.workers-1
		_profile_sum(gene_in,child.id,camp.settler_profiles);_profile_sum(gene_out,parent.id,camp.settler_profiles)
	if connections.is_empty():
		incoming["satellite_1"]=incoming.get("satellite_1",0)+reinforcements.moved_workers
		outgoing["home"]=outgoing.get("home",0)+reinforcements.moved_workers
		_profile_sum(gene_in,"satellite_1",reinforcements.moved_profiles);_profile_sum(gene_out,"home",reinforcements.moved_profiles)
	else:
		for connection: ConnectionTrafficState in connections.values():
			for source_id: String in connection.migrations:
				var target_id: String=connection.target(source_id)
				for migration: WorkerReinforcementState in [connection.migrations[source_id],connection.queens[source_id].movement,connection.broods[source_id].movement,connection.royals[source_id].movement,connection.evacuations[source_id].movement]:
					incoming[target_id]=incoming.get(target_id,0)+migration.moved_workers;outgoing[source_id]=outgoing.get(source_id,0)+migration.moved_workers
					_profile_sum(gene_in,target_id,migration.moved_profiles);_profile_sum(gene_out,source_id,migration.moved_profiles)
	for pile: PileState in colony_state.piles.values():
		if pile.id=="home" and not pile.foundation.is_empty() or pile.id!="home" and not established.has(pile.id):return false
		if pile.workers.transferred_in!=incoming.get(pile.id,0) or pile.workers.transferred_out!=outgoing.get(pile.id,0) or pile.genetics.imported!=gene_in.get(pile.id,{}) or pile.genetics.exported!=gene_out.get(pile.id,{}):return false
	return true

func camp_for_route(route_id: String) -> FoundingState:
	for camp: FoundingState in all_foundings():
		if camp.phase!="none" and camp.route_id==route_id:return camp
	return null

static func _camp_from(camps: Array[FoundingState], route_id: String) -> FoundingState:
	for camp: FoundingState in camps:
		if camp.route_id==route_id:return camp
	return null

func all_connections() -> Array[ConnectionTrafficState]:
	var result: Array[ConnectionTrafficState]=[]
	for camp: FoundingState in all_foundings():
		if camp.phase!="established":continue
		if not connection_traffic.has(camp.route_id):connection_traffic[camp.route_id]=ConnectionTrafficState.new(camp)
		var connection: ConnectionTrafficState=connection_traffic[camp.route_id]
		if camp==founding:
			connection.legacy=true;connection.payer_id=supply_origin
			connection.supplies["home"]=supply;connection.supplies["satellite_1"]=daughter_supply;connection.migrations["home"]=reinforcement
		result.append(connection)
	return result

func connection_for(route_id: String) -> ConnectionTrafficState:
	for connection: ConnectionTrafficState in all_connections():
		if connection.route_id==route_id:return connection
	return null

func connection_payer(route: TrailRouteState) -> String:
	var connection: ConnectionTrafficState=connection_for(route.id) if route.purpose=="interpile" else null
	return connection.payer_id if connection!=null else route.origin_pile

func queen_slot_reserved(pile_id: String) -> bool:
	for connection: ConnectionTrafficState in all_connections():
		if pile_id not in [connection.parent_id,connection.child_id]:continue
		for transport: QueenTransportState in connection.queens.values():
			if transport.active():return true
	return false

func queen_was_relocated(pile_id: String, queen_id: String) -> bool:
	for connection: ConnectionTrafficState in all_connections():
		if not connection.queens.has(pile_id):continue
		var transport: QueenTransportState=connection.queens[pile_id]
		for record: Dictionary in transport.manifests:
			if record.reported_tick>0 and record.arrived_tick>0 and record.body.identity==queen_id:return true
	return false

static func _valid_queen_transports(colony_state: ColonyState, connections: Dictionary) -> bool:
	var bodies: Dictionary={};var slots: Dictionary={};var historical: Dictionary={};var departing: Dictionary={}
	for pile: PileState in colony_state.piles.values():
		if pile.queen.count>0:bodies[pile.queen.queen_id(pile.id)]=true
	for connection: ConnectionTrafficState in connections.values():
		for source_id: String in connection.queens:
			var target_id: String=connection.target(source_id);var transport: QueenTransportState=connection.queens[source_id]
			if transport.active():
				departing[source_id]=true
				for id: String in [source_id,target_id]:
					if slots.has(id):return false
					slots[id]=true
				if colony_state.piles[source_id].queen.count!=0 or colony_state.piles[source_id].queen.replacing() or colony_state.piles[target_id].queen.replacing():return false
				if not transport.body.is_empty():
					var source: QueenState=colony_state.piles[source_id].queen
					if bodies.has(transport.body.identity) or source.queen_id(source_id)!=transport.body.identity or source.generation!=transport.body.generation or source.inherited_traits!=transport.body.inherited_traits or source.parent_identity!=transport.body.parent_identity:return false
					bodies[transport.body.identity]=true
				elif colony_state.piles[target_id].queen.queen_id(target_id)!=transport.current().body.identity:return false
			for record: Dictionary in transport.manifests:
				if record.arrived_tick==0:continue
				if not historical.has(target_id):historical[target_id]=[]
				historical[target_id].append(record.previous_mother)
				historical[target_id].append({"identity":record.body.identity,"generation":record.body.generation,"inherited_traits":record.body.inherited_traits})
	for connection: ConnectionTrafficState in connections.values():
		for source_id: String in connection.broods:
			for record: Dictionary in connection.broods[source_id].manifests:
				var receiver: String=connection.target(source_id) if record.arrived_tick>0 else source_id if record.reported_tick>0 else ""
				if receiver.is_empty():continue
				var cohort:=BroodCohort.new();var parsed: bool=cohort.restore(record.body);assert(parsed)
				if cohort.parent_queen_id.is_empty():continue
				if not historical.has(receiver):historical[receiver]=[]
				historical[receiver].append(cohort.mother_record())
	for connection: ConnectionTrafficState in connections.values():
		for source_id: String in connection.royals:
			for record: Dictionary in connection.royals[source_id].manifests:
				var receiver: String=connection.target(source_id) if record.arrived_tick>0 else source_id if record.reported_tick>0 else ""
				if receiver.is_empty() or record.body.parent_queen_id.is_empty():continue
				if not historical.has(receiver):historical[receiver]=[]
				historical[receiver].append({"identity":record.body.parent_queen_id,"generation":record.body.parent_generation,"inherited_traits":record.body.inherited_traits})
	for pile: PileState in colony_state.piles.values():
		var queen: QueenState=pile.queen
		if queen.in_transit!=departing.has(pile.id):return false
		for mother_record: Dictionary in queen.previous_mothers:
			var proved: bool=false
			for former: Dictionary in historical.get(pile.id,[]):
				if former.identity!=mother_record.identity or former.generation!=mother_record.generation:continue
				proved=true
				for trait_id: String in former.inherited_traits:
					if trait_id not in mother_record.inherited_traits:proved=false
				for trait_id: String in mother_record.inherited_traits:
					if trait_id not in former.inherited_traits and trait_id not in pile.genetics.established:proved=false
				if proved:break
			if not proved:return false
		if queen.arrival_record.is_empty():continue
		var ref: Dictionary=queen.arrival_record
		if not connections.has(ref.route_id):return false
		var connection: ConnectionTrafficState=connections[ref.route_id]
		if connection.target(ref.source_id)!=pile.id:return false
		var transport: QueenTransportState=connection.queens[ref.source_id]
		if ref.index>=transport.manifests.size():return false
		var record: Dictionary=transport.manifests[ref.index]
		if record.arrived_tick==0 or record.body.identity!=queen.queen_id(pile.id) or record.body.parent_identity!=queen.parent_identity or record.body.generation!=queen.generation:return false
		for trait_id: String in record.body.inherited_traits:
			if trait_id not in queen.inherited_traits:return false
		for trait_id: String in queen.inherited_traits:
			if trait_id not in record.body.inherited_traits and trait_id not in pile.genetics.established:return false
		if not AdaptationRules.compatible(PileState._merged_traits(pile.planned_trait_union(),queen.inherited_traits)):return false
	return true

func departed_queen(pile_id: String, queen_id: String) -> Dictionary:
	for connection: ConnectionTrafficState in all_connections():
		if not connection.queens.has(pile_id):continue
		var transport: QueenTransportState=connection.queens[pile_id]
		if transport.active() and transport.current().body.identity==queen_id:return transport.current().body.duplicate(true)
	return {}

func refresh_brood_reservations() -> void:
	for pile: PileState in colony.piles.values():
		pile.brood_reserved_groups=0;pile.brood_reserved_space=0;pile.brood_reserved_trial="";pile.brood_reserved_traits.clear()
	var plans: Dictionary=_brood_reservations(connection_traffic)
	for id: String in plans:
		var pile: PileState=colony.piles[id];var plan: Dictionary=plans[id]
		pile.brood_reserved_groups=plan.groups;pile.brood_reserved_space=plan.space;pile.brood_reserved_trial=plan.trial;pile.brood_reserved_traits.assign(plan.traits)

static func _brood_reservations(connections: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for connection: ConnectionTrafficState in connections.values():
		for source_id: String in connection.broods:
			var transport: BroodTransportState=connection.broods[source_id]
			if not transport.active():continue
			var record: Dictionary=transport.current().body
			var receivers: Array[String]=[source_id]
			if not transport.movement.settled:receivers.append(connection.target(source_id))
			for id: String in receivers:
				if not result.has(id):result[id]={"groups":0,"space":0,"trial":"","traits":[]}
				result[id].groups+=1;result[id].space+=int(record.count)
				if record.adaptation_trial:
					if not result[id].trial.is_empty():result[id].trial="invalid"
					else:result[id].trial=record.adaptation_id
				for trait_id: String in record.inherited_traits:
					if trait_id not in result[id].traits:result[id].traits.append(trait_id)
	for plan: Dictionary in result.values():plan.traits.sort()
	return result

static func _valid_brood_transports(colony_state: ColonyState, connections: Dictionary) -> bool:
	var incoming: Dictionary={};var outgoing: Dictionary={};var received: Dictionary={};var records_by_body: Dictionary={};var bodies: Dictionary={}
	var reservations: Dictionary=_brood_reservations(connections)
	for pile: PileState in colony_state.piles.values():
		var expected: Dictionary=reservations.get(pile.id,{"groups":0,"space":0,"trial":"","traits":[]})
		if pile.brood_reserved_groups!=expected.groups or pile.brood_reserved_space!=expected.space or pile.brood_reserved_trial!=expected.trial or pile.brood_reserved_traits!=expected.traits:return false
		if expected.trial=="invalid" or not expected.trial.is_empty() and pile.trial_cohort()!=null:return false
		for cohort: BroodCohort in pile.brood_cohorts:
			var uid: String=cohort.uid(pile.id);var origin: String=cohort.origin_pile if not cohort.origin_pile.is_empty() else pile.id
			if bodies.has(uid) or not colony_state.piles.has(origin) or int(cohort.id.trim_prefix("brood_"))>colony_state.piles[origin].brood_started_total:return false
			if cohort.transport_count==0 and origin!=pile.id:return false
			bodies[uid]={"owner":pile.id,"moves":cohort.transport_count,"traits":cohort.inherited_traits,"count":cohort.count}
	for connection: ConnectionTrafficState in connections.values():
		for source_id: String in connection.broods:
			var transport: BroodTransportState=connection.broods[source_id]
			for record: Dictionary in transport.manifests:
				var cohort:=BroodCohort.new();var parsed: bool=cohort.restore(record.body);assert(parsed)
				var uid: String=cohort.uid(source_id)
				if not colony_state.piles.has(cohort.origin_pile) or int(cohort.id.trim_prefix("brood_"))>colony_state.piles[cohort.origin_pile].brood_started_total:return false
				if not records_by_body.has(uid):records_by_body[uid]=[]
				records_by_body[uid].append({"record":record,"target":connection.target(source_id)})
				outgoing[source_id]=outgoing.get(source_id,0)+cohort.count
				var recipient: String=connection.target(source_id) if record.arrived_tick>0 else source_id if record.reported_tick>0 else ""
				if not recipient.is_empty():
					incoming[recipient]=incoming.get(recipient,0)+cohort.count
					if not received.has(recipient):received[recipient]={}
					received[recipient][uid]=cohort.inherited_traits.duplicate()
			if not transport.body.is_empty():
				var cohort:=BroodCohort.new();var parsed: bool=cohort.restore(transport.body);assert(parsed)
				var uid: String=cohort.uid(source_id)
				if bodies.has(uid):return false
				bodies[uid]={"owner":"transit","moves":cohort.transport_count,"traits":cohort.inherited_traits,"count":cohort.count}
	for uid: String in records_by_body:
		var records: Array=records_by_body[uid];records.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.record.departed_tick<b.record.departed_tick)
		var previous_owner: String=uid.get_slice(":",0);var ready: int=0;var previous_count: int=BroodCohort.CONFIG.starting_count
		var immutable: Array[String]=["origin_pile","id","parent_queen_id","parent_generation","adaptation_id","adaptation_trial","inherited_traits","rain_comparison","recognition_comparison","repair_comparison"]
		var first: Dictionary=records[0].record.body
		for index: int in records.size():
			var entry: Dictionary=records[index];var record: Dictionary=entry.record;var body: Dictionary=record.body
			if int(body.transport_count)!=index+1 or record.source_id!=previous_owner or record.departed_tick<ready or body.count>previous_count:return false
			for key: String in immutable:
				if body[key]!=first[key]:return false
			previous_count=int(body.count)
			previous_owner=entry.target if record.arrived_tick>0 else record.source_id if record.reported_tick>0 else "transit"
			ready=int(record.arrived_tick if record.arrived_tick>0 else record.reported_tick)
		if bodies.has(uid):
			var current_body: Dictionary=bodies[uid]
			if current_body.owner!=previous_owner or current_body.moves!=records.size() or current_body.traits!=first.inherited_traits or current_body.count>previous_count:return false
		elif previous_owner=="transit":return false
	for uid: String in bodies:
		if bodies[uid].moves>0 and not records_by_body.has(uid):return false
	for pile: PileState in colony_state.piles.values():
		if pile.brood_transferred_in!=incoming.get(pile.id,0) or pile.brood_transferred_out!=outgoing.get(pile.id,0) or pile.brood_lineages!=received.get(pile.id,{}):return false
	return true

func unreported_transfers(pile_id: String, trait_id: String="*") -> int:
	var total: int=0
	for connection: ConnectionTrafficState in all_connections():
		if not connection.migrations.has(pile_id):continue
		var evacuation: EvacuationTransportState=connection.evacuations[pile_id]
		if colony.piles[pile_id].relinquished and not evacuation.current().is_empty() and evacuation.current().arrived_tick>0:
			if trait_id=="*":total+=int(evacuation.current().workers)
			else:
				for key: String in evacuation.current().profiles:
					if trait_id in GeneticRepertoire.traits_for(key):total+=int(evacuation.current().profiles[key])
		for movement: WorkerReinforcementState in [connection.migrations[pile_id],connection.queens[pile_id].movement,connection.broods[pile_id].movement,connection.royals[pile_id].movement]:
			if not movement.active() or not movement.settled:continue
			if trait_id=="*":total+=movement.settlers
			else:
				for key: String in movement.party_profiles:
					if trait_id in GeneticRepertoire.traits_for(key):total+=movement.party_profiles[key]
	return total

func royal_departed(pile_id: String) -> bool:
	for connection: ConnectionTrafficState in all_connections():
		if connection.royals.has(pile_id) and connection.royals[pile_id].active():return true
	return false

static func _royal_reservations(connections: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for connection: ConnectionTrafficState in connections.values():
		for source_id: String in connection.royals:
			var transport: RoyalTransportState=connection.royals[source_id]
			if not transport.active():continue
			var body: Dictionary=transport.current().body;var receivers: Array[String]=[source_id]
			if not transport.movement.settled:receivers.append(connection.target(source_id))
			for id: String in receivers:
				if result.has(id):result[id].invalid=true;continue
				var traits: Array[String]=[];traits.assign(body.inherited_traits);traits.sort()
				result[id]={"space":ReproductionState.CONFIG.space if body.phase!="ready" else 0,"traits":traits,"invalid":false}
	return result

func refresh_royal_reservations() -> void:
	var plans: Dictionary=_royal_reservations(connection_traffic)
	for pile: PileState in colony.piles.values():
		var plan: Dictionary=plans.get(pile.id,{"space":0,"traits":[]})
		pile.royal_reserved=plans.has(pile.id);pile.royal_reserved_space=plan.space;pile.royal_reserved_traits.assign(plan.traits)

static func _valid_royal_transports(colony_state: ColonyState, connections: Dictionary, camps: Array[FoundingState]) -> bool:
	var reservations: Dictionary=_royal_reservations(connections);var bodies: Dictionary={};var records: Dictionary={}
	for pile: PileState in colony_state.piles.values():
		var expected: Dictionary=reservations.get(pile.id,{"space":0,"traits":[],"invalid":false})
		if expected.invalid or pile.royal_reserved!=reservations.has(pile.id) or pile.royal_reserved_space!=expected.space or pile.royal_reserved_traits!=expected.traits:return false
		if pile.royal_reserved and (pile.reproduction.phase!="none" or pile.queen.replacing()):return false
		for group: Dictionary in [pile.reproduction.to_dict(),pile.queen.replacement_group]:
			if group.is_empty() or group.phase=="none":continue
			var identity: String=ReproductionState.body_identity(group,pile.id)
			if bodies.has(identity) or group.transport_count==0 and not group.origin_pile.is_empty() and group.origin_pile!=pile.id:return false
			bodies[identity]={"owner":pile.id,"body":group}
	for camp: FoundingState in camps:
		if camp.phase in ["none","failed","established"]:continue
		var identity: String=ReproductionState.body_identity(camp.reproductive_group,camp.origin_pile)
		if bodies.has(identity):return false
		bodies[identity]={"owner":camp.origin_pile,"body":camp.reproductive_group}
	for connection: ConnectionTrafficState in connections.values():
		for source_id: String in connection.royals:
			var transport: RoyalTransportState=connection.royals[source_id]
			for record: Dictionary in transport.manifests:
				var body: Dictionary=record.body;var identity: String=ReproductionState.body_identity(body,source_id)
				if not colony_state.piles.has(body.origin_pile) or body.laid_tick<colony_state.piles[body.origin_pile].foundation.get("founded_tick",0) or record.departed_tick<body.laid_tick:return false
				if not records.has(identity):records[identity]=[]
				records[identity].append({"record":record,"target":connection.target(source_id)})
			if not transport.body.is_empty():
				var identity: String=ReproductionState.body_identity(transport.body,source_id)
				if bodies.has(identity):return false
				bodies[identity]={"owner":"transit","body":transport.body}
	for identity: String in records:
		var chain: Array=records[identity];chain.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.record.departed_tick<b.record.departed_tick)
		var first: Dictionary=chain[0].record.body;var owner: String=first.origin_pile;var available_tick: int=0;var previous_stage: int=-1;var previous_progress: float=0
		var origin: PileState=colony_state.piles[owner]
		if not QueenState.known_parent(first.parent_queen_id,int(first.parent_generation),origin.queen.queen_id(owner),origin.queen.generation,origin.queen.previous_mothers):return false
		for trait_id: String in first.inherited_traits:
			if trait_id not in origin.known_lineage_traits():return false
		for index: int in chain.size():
			var entry: Dictionary=chain[index];var record: Dictionary=entry.record;var body: Dictionary=record.body
			if body.transport_count!=index+1 or record.source_id!=owner or record.departed_tick<available_tick:return false
			for key: String in ["origin_pile","laid_tick","parent_queen_id","parent_generation","inherited_traits"]:
				if body[key]!=first[key]:return false
			var stage: int=["egg","larva","pupa","ready"].find(body.phase);var progress: float=float(body.progress_quarters)*0.25+float(body.progress_remainder)/80.0
			if stage<previous_stage or stage==previous_stage and progress<previous_progress:return false
			previous_stage=stage;previous_progress=progress
			owner=entry.target if record.arrived_tick>0 else record.source_id if record.reported_tick>0 else "transit"
			available_tick=int(record.arrived_tick if record.arrived_tick>0 else record.reported_tick)
		if bodies.has(identity):
			var current: Dictionary=bodies[identity];var body: Dictionary=current.body
			if current.owner!=owner or body.transport_count!=chain.size() or body.parent_queen_id!=first.parent_queen_id or body.parent_generation!=first.parent_generation or body.inherited_traits!=first.inherited_traits:return false
		elif owner=="transit":return false
		# A consumed ready group may now own a living mother at its receiver/founded nest.
		for pile: PileState in colony_state.piles.values():
			if pile.queen.count==0 or pile.queen.queen_id(pile.id)!=identity:continue
			if bodies.has(identity) or first.parent_queen_id!=pile.queen.parent_identity or first.parent_generation+1!=pile.queen.generation:return false
			for trait_id: String in first.inherited_traits:
				if trait_id not in pile.queen.inherited_traits:return false
	for identity: String in bodies:
		if bodies[identity].body.get("transport_count",0)>0 and not records.has(identity):return false
	return true

static func _valid_evacuations(colony_state: ColonyState, connections: Dictionary) -> bool:
	var latest: Dictionary={};var orders: Dictionary={}
	for connection: ConnectionTrafficState in connections.values():
		for source_id: String in connection.evacuations:
			var state: EvacuationTransportState=connection.evacuations[source_id]
			for record: Dictionary in state.manifests:
				if not orders.has(source_id):orders[source_id]=[]
				orders[source_id].append(record)
				if not latest.has(source_id) or record.sequence>latest[source_id].sequence:latest[source_id]=record
			if state.active() and (state.movement.settled or state.current().workers!=colony_state.piles[source_id].workers_total):return false
	for records: Array in orders.values():
		records.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.sequence<b.sequence)
		for index: int in records.size():
			if records[index].sequence!=index+1:return false
			if index>0 and (records[index-1].arrived_tick>0 or records[index-1].returned_tick==0 or records[index].departed_tick<records[index-1].returned_tick):return false
	for pile: PileState in colony_state.piles.values():
		var record: Dictionary=latest.get(pile.id,{})
		if pile.relinquished!=(not record.is_empty() and record.returned_tick==0):return false
		if not pile.relinquished:continue
		if pile.queen.count>0 or pile.queen.replacing() or pile.queen.in_transit or not pile.brood_cohorts.is_empty() or pile.reproduction.phase!="none" or pile.brood_reserved_space>0 or pile.royal_reserved:return false
		if pile.workers_available!=0 or pile.brood_intent!="manual" or not pile.queued_adaptation.is_empty() or pile.investments.reproduction:return false
		for connection: ConnectionTrafficState in connections.values():
			if pile.id in [connection.parent_id,connection.child_id] and not connection.closed:return false
	return true

func known_final_departure(pile_id: String) -> Dictionary:
	var result: Dictionary={}
	for connection: ConnectionTrafficState in all_connections():
		if not connection.evacuations.has(pile_id):continue
		var state: EvacuationTransportState=connection.evacuations[pile_id]
		if state.current().is_empty() or not result.is_empty() and state.current().sequence<=result.sequence:continue
		var record: Dictionary=state.current()
		result={"sequence":record.sequence,"departed_tick":record.departed_tick,"destination_id":connection.target(pile_id),"destination_name":colony.piles[connection.target(pile_id)].display_title(),"workers":record.workers,"left_stores":record.left_stores.duplicate(),"left_organs":record.left_organs.duplicate(),"returned":record.returned_tick>0}
	return result
