class_name FoundingCampSystem
extends RefCounted
const CONFIG = preload("res://data/resources/default_founding.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
var _run: RunState
var last_error: String=""
var origin_id: String="home"
var destination_id: String="satellite_1"
var camp_key: String=""
var _empty_state:=FoundingState.new()
func _init(run_state: RunState, origin: String="home", destination: String="satellite_1", key: String="") -> void:
	_run=run_state;origin_id=origin;destination_id=destination;camp_key=key
	_empty_state.origin_pile=origin;_empty_state.destination_pile=destination
func state() -> FoundingState:
	return _run.founding if camp_key.is_empty() else _run.extra_foundings.get(camp_key,_empty_state)
func _commit(state_value: FoundingState) -> void:
	if camp_key.is_empty(): _run.founding=state_value
	else: _run.extra_foundings[camp_key]=state_value
func blocker(knowledge_id: String) -> String:
	if not _run.knowledge.nodes.has(knowledge_id) or _run.knowledge.nodes[knowledge_id].definition_id!="nest_site": return "A returned shelter memory is required"
	if state().phase not in ["none","failed"]: return "A founding party is already committed"
	var pile: PileState=_run.colony.piles[origin_id]
	if pile.reproduction.phase!="ready": return "Raise a reproductive group at Queen first"
	var endpoint: Vector2=_run.knowledge.nodes[knowledge_id].estimated_position
	if endpoint==pile.position: return "Shelter has no usable direction"
	var prior: TrailRouteState=_run.trails.find_route(origin_id,knowledge_id)
	if prior!=null and (prior.purpose!="founding" or prior.status!="inactive" or pile.workers.count("trail:"+prior.id)!=-1): return "Shelter route is already committed"
	if state().phase=="failed" and _run.trails.routes[state().route_id].destination_knowledge_id!=knowledge_id: return "Recheck the prior shelter before retrying"
	if prior==null and pile.workers.count("trail:route_%d" % _run.trails.next_route_id)!=-1: return "Founding commitment unavailable"
	if _run.knowledge.nodes[knowledge_id].site_profile.is_empty() and _run.next_scout_id>=WorkerLedger.MAX_COUNT: return "Site report identity unavailable"
	if _run.trails.next_route_id>=WorkerLedger.MAX_COUNT: return "Route ID unavailable"
	if pile.workers_assignable<CONFIG.workers: return "Need %d available founding workers" % CONFIG.workers
	var costs: Dictionary=_costs(endpoint,_run.knowledge.nodes[knowledge_id].site_profile)
	for id: String in PileState.RESOURCE_IDS:
		if pile.resources[id]<costs[id]: return "Need %.2f %s for founding" % [costs[id],id]
	return ""
func _costs(endpoint: Vector2, profile_id: String="") -> Dictionary:
	var start: Vector2=_run.colony.piles[origin_id].position
	var costs: Dictionary=CONFIG.supplies()
	costs.carbohydrate+=SiteCatalog.get_profile(profile_id).extra_carbohydrate
	costs.carbohydrate+=TRAILS.round_trip_energy_cost(CONFIG.workers,start.distance_to(endpoint),TrailSegmentState.terrain_cost_for(_run.world,start,endpoint))
	return costs
func start(knowledge_id: String) -> bool:
	last_error=blocker(knowledge_id)
	if not last_error.is_empty(): return false
	var pile: PileState=_run.colony.piles[origin_id]
	var endpoint: Vector2=_run.knowledge.nodes[knowledge_id].estimated_position
	var route: TrailRouteState=_run.trails.find_route(origin_id,knowledge_id)
	if route==null:
		route=TrailRouteState.new(); route.id="route_%d" % _run.trails.next_route_id; route.segment_id="segment_%d" % _run.trails.next_route_id
		route.origin_pile=origin_id; route.destination_knowledge_id=knowledge_id; route.estimated_destination=endpoint; route.purpose="founding"
		var segment:=TrailSegmentState.new(); segment.id=route.segment_id; segment.route_id=route.id; segment.start=pile.position; segment.end=endpoint
		segment.exposure=TrailSegmentState.exposure_for(_run.world,segment.start,segment.end)
		_run.trails.routes[route.id]=route; _run.trails.segments[segment.id]=segment; _run.trails.next_route_id+=1
	route.estimated_destination=endpoint
	var infrastructure: TrailSegmentState=_run.trails.segments[route.segment_id]
	infrastructure.end=endpoint; infrastructure.exposure=TrailSegmentState.exposure_for(_run.world,infrastructure.start,endpoint)
	var commitment: String="trail:"+route.id
	var created: bool=pile.workers.create_commitment(commitment,"trail",route.id); assert(created)
	var allocated: bool=pile.allocate_workers(commitment,CONFIG.workers); assert(allocated)
	var state:=FoundingState.new(); state.phase="outbound"; state.route_id=route.id
	state.origin_pile=origin_id;state.destination_pile=destination_id
	state.leg_ticks=TRAILS.leg_ticks(pile.position.distance_to(endpoint)); state.departed_tick=_run.clock.tick_count
	state.site_profile=_run.knowledge.nodes[knowledge_id].site_profile
	state.quoted_site_profile=state.site_profile
	state.preparation_ticks=SiteCatalog.get_profile(state.site_profile).preparation_ticks
	state.reproductive_group=pile.reproduction.to_dict()
	state.contaminant_mass=roundf(pile.food_toxicity.mass*CONFIG.carbohydrate/pile.resources.carbohydrate*100000000.0)/100000000.0
	var paid: bool=pile.consume_resources(_costs(endpoint,state.site_profile)); assert(paid)
	pile.reproduction=ReproductionState.new(); _commit(state)
	route.desired_workers=CONFIG.workers; route.allocated_workers=CONFIG.workers; route.active_workers=CONFIG.workers; route.status="active"
	last_error=""; return true
func establish(knowledge_id: String) -> bool:
	var state: FoundingState=state()
	if state.phase!="ready" or _run.colony.piles.has(destination_id):
		last_error="A returned founding-camp report is required"; return false
	var route: TrailRouteState=_run.trails.routes[state.route_id]
	if route.destination_knowledge_id!=knowledge_id:
		last_error="This shelter has no reported camp"; return false
	var parent: PileState=_run.colony.piles[origin_id]
	var daughter:=PileState.new()
	daughter.id=destination_id; daughter.position=route.estimated_destination
	daughter.brood_started_total=0
	var traits: Array[String]=[]; traits.assign(state.reproductive_group.inherited_traits)
	var transferred_profiles: Dictionary[String,int]=parent.genetics.migration_plan(CONFIG.workers-1,parent.workers_total)
	daughter.foundation={"parent_id":origin_id,"route_id":route.id,"queen_traits":traits,"founded_tick":_run.clock.tick_count,"site_profile":state.site_profile}
	daughter.genetics.established=traits.duplicate()
	daughter.queen.inherited_traits=traits.duplicate()
	if not state.reproductive_group.get("parent_queen_id","").is_empty():
		daughter.queen.identity=ReproductionState.body_identity(state.reproductive_group,origin_id)
		daughter.queen.parent_identity=state.reproductive_group.parent_queen_id
		daughter.queen.generation=int(state.reproductive_group.parent_generation)+1
	# Experienced settlers bring the colony's existing knowledge, not live exterior truth.
	daughter.rain_trace_observed=parent.rain_trace_observed; daughter.chemistry_candidate=parent.chemistry_candidate
	daughter.recognition_experience=parent.recognition_experience; daughter.recognition_candidate=parent.recognition_candidate
	if not parent.move_workers_to(daughter,"trail:"+route.id,CONFIG.workers-1):
		last_error="Settler transfer unavailable"; return false
	state.settler_profiles=transferred_profiles
	var retired: bool=parent.workers.retire_commitment("trail:"+route.id); assert(retired)
	for id: String in PileState.RESOURCE_IDS:
		var deposited: bool=daughter.deposit_resource(id,state.carried_supplies()[id],state.contaminant_mass if id=="carbohydrate" else 0.0); assert(deposited)
	_run.colony.piles[daughter.id]=daughter
	if daughter.id!="satellite_1": _run.extra_exploration[daughter.id]=ExplorationState.new()
	route.purpose="interpile"; route.desired_workers=0; route.allocated_workers=0; route.active_workers=0; route.status="inactive"
	state.phase="established"
	last_error=""; return true
func tick() -> void:
	var state: FoundingState=state()
	if not state.awaiting(): return
	state.elapsed_ticks+=1
	var route: TrailRouteState=_run.trails.routes[state.route_id]
	if state.phase=="settling":
		if state.elapsed_ticks>=state.preparation_ticks: state.phase="messenger"; state.elapsed_ticks=0
		return
	if state.elapsed_ticks<state.leg_ticks: return
	state.elapsed_ticks=0
	if state.phase=="outbound":
		# Test the remembered place physically; never navigate to the hidden coordinate.
		var site: WorldNodeState=_run.world.nodes.get(_run.knowledge.nodes[route.destination_knowledge_id].source_node_id)
		var confirmed: bool=site!=null and site.definition_id=="nest_site" and site.active and site.quantity>0 and site.position.distance_to(route.estimated_destination)<=TRAILS.interaction_radius
		if confirmed and state.site_profile.is_empty() and not site.site_profile.is_empty():
			_learn_site(state,route,site)
		state.phase="settling" if confirmed and site.site_profile==state.site_profile else "returning"
		return
	var pile: PileState=_run.colony.piles[origin_id]
	var returning: int=1 if state.phase=="messenger" else CONFIG.workers
	var released: bool=pile.workers.release("trail:"+route.id,returning); assert(released)
	route.active_workers-=returning; route.allocated_workers-=returning; route.desired_workers-=returning
	state.reported_tick=_run.clock.tick_count
	if state.site_report!=null: _run.delivered_observations[state.site_report.id]=state.site_report.detached_copy()
	if state.phase=="messenger": state.phase="ready"
	else:
		state.phase="failed"; route.status="inactive"
		var retired: bool=pile.workers.retire_commitment("trail:"+route.id); assert(retired)
		for id: String in PileState.RESOURCE_IDS:
			var deposited: bool=pile.deposit_resource(id,state.carried_supplies()[id],state.contaminant_mass if id=="carbohydrate" else 0.0); assert(deposited)
		var restored:=ReproductionState.new()
		var valid: bool=restored.restore(state.reproductive_group,pile.workers,origin_id,pile.genetics.established,pile.brood_matured_total,pile.nursery_state,pile.food_exchange_state,pile.queen_count); assert(valid)
		pile.reproduction=restored
	var segment: TrailSegmentState=_run.trails.segments[route.segment_id]
	segment.reinforce_chemistry(returning*TRAILS.pheromone_per_returning_worker,0.0)
	segment.route_familiarity=minf(1.0,snappedf(segment.route_familiarity+returning*TRAILS.familiarity_per_returning_worker,0.0000000001)); segment.traffic+=returning
func summary(knowledge_id: String) -> Dictionary:
	var state: FoundingState=state()
	var for_site: bool=state.phase!="none" and _run.trails.routes[state.route_id].destination_knowledge_id==knowledge_id
	var profile_id: String=_run.knowledge.nodes[knowledge_id].site_profile if _run.knowledge.nodes.has(knowledge_id) else ""
	if for_site and state.reported_tick>0: profile_id=state.site_profile
	var profile: SiteDefinition=SiteCatalog.get_profile(profile_id)
	var result: Dictionary={"site_profile":profile_id,"site_cues":profile.cues,"site_tradeoff":profile.tradeoff,"preparation_seconds":profile.preparation_ticks*SimulationClock.TICK_INTERVAL,"preparation_carbohydrate":profile.extra_carbohydrate,"status":"awaiting" if for_site and state.awaiting() else state.phase if for_site else "none","workers":CONFIG.workers,"supplies":state.carried_supplies() if for_site and state.reported_tick>0 else CONFIG.supplies(),"blocker":blocker(knowledge_id)}
	if for_site:
		result.age=(_run.clock.tick_count-state.departed_tick)*SimulationClock.TICK_INTERVAL
		if state.phase in ["ready","failed","established"]:
			result.reported_at=state.reported_tick*SimulationClock.TICK_INTERVAL
			result.settlers=CONFIG.workers-1 if state.phase=="ready" else 0
	if for_site and state.phase=="established": result.daughter_id=destination_id
	return result

func _learn_site(state: FoundingState, route: TrailRouteState, site: WorldNodeState) -> void:
	# Real campers can identify the entrance; unknown preparation spends carried food.
	var profile: SiteDefinition=SiteCatalog.get_profile(site.site_profile)
	state.site_profile=site.site_profile;state.preparation_ticks=profile.preparation_ticks
	state.preparation_from_pack=profile.extra_carbohydrate>0
	if state.preparation_from_pack: state.contaminant_mass=roundf(state.contaminant_mass*float(CONFIG.carbohydrate-profile.extra_carbohydrate)/CONFIG.carbohydrate*100000000.0)/100000000.0
	var report:=Observation.new();report.scout_id="scout_%d" % _run.next_scout_id;_run.next_scout_id+=1
	report.id=report.scout_id+":"+site.id;report.origin_pile=origin_id;report.source_node_id=site.id;report.definition_id="nest_site";report.site_profile=site.site_profile
	report.first_observed_at=_run.simulation_time;report.observed_at=_run.simulation_time
	report.estimated_position=route.estimated_destination;report.uncertainty_radius=TRAILS.interaction_radius;report.closest_distance=0;report.proximity_confirmed=true
	state.site_report=report
