class_name FoundingSystem
extends RefCounted
const CONFIG = preload("res://data/resources/default_founding.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
var _run: RunState
var last_error: String=""
func _init(run_state: RunState) -> void: _run=run_state
func blocker(knowledge_id: String) -> String:
	if not _run.knowledge.nodes.has(knowledge_id) or _run.knowledge.nodes[knowledge_id].definition_id!="nest_site": return "A returned shelter memory is required"
	if _run.founding.phase not in ["none","failed"]: return "A founding party is already committed"
	var pile: PileState=_run.colony.piles.home
	if pile.reproduction.phase!="ready": return "Raise a reproductive group at Queen first"
	var endpoint: Vector2=_run.knowledge.nodes[knowledge_id].estimated_position
	if endpoint==pile.position: return "Shelter has no usable direction"
	var prior: TrailRouteState=_run.trails.find_route("home",knowledge_id)
	if prior!=null and (prior.purpose!="founding" or prior.status!="inactive" or pile.workers.count("trail:"+prior.id)!=-1): return "Shelter route is already committed"
	if _run.founding.phase=="failed" and _run.trails.routes[_run.founding.route_id].destination_knowledge_id!=knowledge_id: return "Recheck the prior shelter before retrying"
	if prior==null and pile.workers.count("trail:route_%d" % _run.trails.next_route_id)!=-1: return "Founding commitment unavailable"
	if _run.trails.next_route_id>=WorkerLedger.MAX_COUNT: return "Route ID unavailable"
	if pile.workers_assignable<CONFIG.workers: return "Need %d available founding workers" % CONFIG.workers
	var costs: Dictionary=_costs(endpoint)
	for id: String in PileState.RESOURCE_IDS:
		if pile.resources[id]<costs[id]: return "Need %.2f %s for founding" % [costs[id],id]
	return ""
func _costs(endpoint: Vector2) -> Dictionary:
	var start: Vector2=_run.colony.piles.home.position
	var costs: Dictionary=CONFIG.supplies()
	costs.carbohydrate+=TRAILS.round_trip_energy_cost(CONFIG.workers,start.distance_to(endpoint),TrailSegmentState.terrain_cost_for(_run.world,start,endpoint))
	return costs
func start(knowledge_id: String) -> bool:
	last_error=blocker(knowledge_id)
	if not last_error.is_empty(): return false
	var pile: PileState=_run.colony.piles.home
	var endpoint: Vector2=_run.knowledge.nodes[knowledge_id].estimated_position
	var route: TrailRouteState=_run.trails.find_route("home",knowledge_id)
	if route==null:
		route=TrailRouteState.new(); route.id="route_%d" % _run.trails.next_route_id; route.segment_id="segment_%d" % _run.trails.next_route_id
		route.origin_pile="home"; route.destination_knowledge_id=knowledge_id; route.estimated_destination=endpoint; route.purpose="founding"
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
	state.leg_ticks=TRAILS.leg_ticks(pile.position.distance_to(endpoint)); state.departed_tick=_run.clock.tick_count
	state.reproductive_group=pile.reproduction.to_dict()
	state.contaminant_mass=roundf(pile.food_toxicity.mass*CONFIG.carbohydrate/pile.resources.carbohydrate*100000000.0)/100000000.0
	var paid: bool=pile.consume_resources(_costs(endpoint)); assert(paid)
	pile.reproduction=ReproductionState.new(); _run.founding=state
	route.desired_workers=CONFIG.workers; route.allocated_workers=CONFIG.workers; route.active_workers=CONFIG.workers; route.status="active"
	last_error=""; return true
func establish(knowledge_id: String) -> bool:
	var state: FoundingState=_run.founding
	if state.phase!="ready" or _run.colony.piles.has("satellite_1"):
		last_error="A returned founding-camp report is required"; return false
	var route: TrailRouteState=_run.trails.routes[state.route_id]
	if route.destination_knowledge_id!=knowledge_id:
		last_error="This shelter has no reported camp"; return false
	var parent: PileState=_run.colony.piles.home
	var daughter:=PileState.new()
	daughter.id="satellite_1"; daughter.position=route.estimated_destination
	daughter.brood_started_total=0
	var traits: Array[String]=[]; traits.assign(state.reproductive_group.inherited_traits)
	daughter.foundation={"parent_id":"home","route_id":route.id,"queen_traits":traits,"founded_tick":_run.clock.tick_count}
	daughter.genetics.established=traits.duplicate()
	# Experienced settlers bring the colony's existing knowledge, not live exterior truth.
	daughter.rain_trace_observed=parent.rain_trace_observed; daughter.chemistry_candidate=parent.chemistry_candidate
	daughter.recognition_experience=parent.recognition_experience; daughter.recognition_candidate=parent.recognition_candidate
	if not parent.move_workers_to(daughter,"trail:"+route.id,CONFIG.workers-1):
		last_error="Settler transfer unavailable"; return false
	var retired: bool=parent.workers.retire_commitment("trail:"+route.id); assert(retired)
	for id: String in PileState.RESOURCE_IDS:
		var deposited: bool=daughter.deposit_resource(id,CONFIG.supplies()[id],state.contaminant_mass if id=="carbohydrate" else 0.0); assert(deposited)
	_run.colony.piles[daughter.id]=daughter
	route.purpose="interpile"; route.desired_workers=0; route.allocated_workers=0; route.active_workers=0; route.status="inactive"
	state.phase="established"
	last_error=""; return true
func tick() -> void:
	var state: FoundingState=_run.founding
	if not state.awaiting(): return
	state.elapsed_ticks+=1
	var route: TrailRouteState=_run.trails.routes[state.route_id]
	if state.phase=="settling":
		if state.elapsed_ticks>=CONFIG.preparation_ticks: state.phase="messenger"; state.elapsed_ticks=0
		return
	if state.elapsed_ticks<state.leg_ticks: return
	state.elapsed_ticks=0
	if state.phase=="outbound":
		# Test the remembered place physically; never navigate to the hidden coordinate.
		var site: WorldNodeState=_run.world.nodes.get(_run.knowledge.nodes[route.destination_knowledge_id].source_node_id)
		state.phase="settling" if site!=null and site.definition_id=="nest_site" and site.active and site.quantity>0 and site.position.distance_to(route.estimated_destination)<=TRAILS.interaction_radius else "returning"
		return
	var pile: PileState=_run.colony.piles.home
	var returning: int=1 if state.phase=="messenger" else CONFIG.workers
	var released: bool=pile.workers.release("trail:"+route.id,returning); assert(released)
	route.active_workers-=returning; route.allocated_workers-=returning; route.desired_workers-=returning
	state.reported_tick=_run.clock.tick_count
	if state.phase=="messenger": state.phase="ready"
	else:
		state.phase="failed"; route.status="inactive"
		var retired: bool=pile.workers.retire_commitment("trail:"+route.id); assert(retired)
		for id: String in PileState.RESOURCE_IDS:
			var deposited: bool=pile.deposit_resource(id,CONFIG.supplies()[id],state.contaminant_mass if id=="carbohydrate" else 0.0); assert(deposited)
		var restored:=ReproductionState.new()
		var valid: bool=restored.restore(state.reproductive_group,pile.workers,"home",pile.genetics.established,pile.brood_matured_total,pile.nursery_state,pile.food_exchange_state,pile.queen_count); assert(valid)
		pile.reproduction=restored
	var segment: TrailSegmentState=_run.trails.segments[route.segment_id]
	segment.reinforce_chemistry(returning*TRAILS.pheromone_per_returning_worker,0.0)
	segment.route_familiarity=minf(1.0,snappedf(segment.route_familiarity+returning*TRAILS.familiarity_per_returning_worker,0.0000000001)); segment.traffic+=returning
func summary(knowledge_id: String) -> Dictionary:
	var state: FoundingState=_run.founding
	var for_site: bool=state.phase!="none" and _run.trails.routes[state.route_id].destination_knowledge_id==knowledge_id
	var result: Dictionary={"status":"awaiting" if for_site and state.awaiting() else state.phase if for_site else "none","workers":CONFIG.workers,"supplies":CONFIG.supplies(),"blocker":blocker(knowledge_id)}
	if for_site:
		result.age=(_run.clock.tick_count-state.departed_tick)*SimulationClock.TICK_INTERVAL
		if state.phase in ["ready","failed","established"]:
			result.reported_at=state.reported_tick*SimulationClock.TICK_INTERVAL
			result.settlers=CONFIG.workers-1 if state.phase=="ready" else 0
	if for_site and state.phase=="established": result.daughter_id="satellite_1"
	return result
