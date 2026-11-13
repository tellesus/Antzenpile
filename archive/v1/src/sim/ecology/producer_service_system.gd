class_name ProducerServiceSystem
extends RefCounted
const CONFIG=preload("res://data/ecology/backyard_honeydew.tres")
const TRAILS=preload("res://data/trails/default_trails.tres")
var _run: RunState
var last_error: String=""
func _init(run: RunState) -> void:_run=run
func _state(id: String) -> ProducerServiceState:
	return _run.honeydew.services.get(id)
func _route(id: String) -> TrailRouteState:return _run.trails.find_route(id,"known:"+CONFIG.source_id)
func _reject(reason: String) -> bool:last_error=reason;return false
func _cost(id: String, count: int) -> float:
	var pile: PileState=_run.colony.piles[id];var route: TrailRouteState=_route(id)
	if route==null:return 0
	var multiplier: float=AdaptationRules.energy_multiplier(pile.adaptation_repertoire,pile.adaptation_fraction())*(1.0+AdaptationRules.CHEMISTRY.extra_travel_energy*pile.chemistry_fraction())
	return snappedf(TRAILS.round_trip_energy_cost(count,pile.position.distance_to(route.estimated_destination),TrailSegmentState.terrain_cost_for(_run.world,pile.position,route.estimated_destination))*multiplier,0.00001)
func blocker(id: String, count: int) -> String:
	if not _run.colony.piles.has(id) or _run.colony.piles[id].relinquished:return "Choose an active pile"
	if not WorkerLedger.valid_count(count) or count>ProducerServiceState.CAP:return "Choose zero to sixteen whole attendants"
	if count==0:return ""
	var route: TrailRouteState=_route(id)
	if route==null or route.delivered_total<=0 or not _run.world.nodes.has(CONFIG.source_id):return "A local loaded honeydew return is required"
	var state: ProducerServiceState=_state(id)
	if state!=null and state.phase!="none":return ""
	var pile: PileState=_run.colony.piles[id]
	if pile.workers_assignable<count:return "Need %d available attendants; brood care held" % count
	if pile.resources.carbohydrate<_cost(id,count):return "Need %.3f carbs for the attendants' round trip" % _cost(id,count)
	return ""
func set_target(id: String, value: Variant) -> bool:
	if not WorkerLedger.valid_count(value) or value>ProducerServiceState.CAP:return _reject("Choose zero to sixteen whole attendants")
	var reason: String=blocker(id,int(value))
	if not reason.is_empty():return _reject(reason)
	var state: ProducerServiceState=_state(id)
	if state==null:
		if value==0:return _reject("No attendant duty is ordered")
		state=ProducerServiceState.new();_run.honeydew.services[id]=state
	if state.known_target()==value:return _reject("Attendant target already set")
	state.failure_goal_hidden=false;state.target=int(value)
	if state.phase in ["outbound","working"]:
		state.elapsed_ticks=state.leg_ticks-state.elapsed_ticks if state.phase=="outbound" else 0;state.phase="returning";state.recall_tick=_run.clock.tick_count
		if state.elapsed_ticks==state.leg_ticks:_return(id,state)
	elif state.phase=="none" and state.target>0:_depart(id,state)
	_sync();last_error="";return true
func _depart(id: String, state: ProducerServiceState) -> void:
	var reason: String=blocker(id,state.target)
	if not reason.is_empty():return
	var pile: PileState=_run.colony.piles[id];var route: TrailRouteState=_route(id);var pool: String="honeydew:"+id
	var made: bool=pile.workers.create_commitment(pool,"other",CONFIG.source_id);var assigned: bool=pile.allocate_workers(pool,state.target);var paid: bool=pile.consume_resources({"carbohydrate":_cost(id,state.target)});assert(made and assigned and paid)
	state.failure_goal_hidden=false;state.private_failure=false;state.count=state.target;state.phase="outbound";state.elapsed_ticks=0;state.destination=route.estimated_destination;state.leg_ticks=TRAILS.leg_ticks(pile.position.distance_to(state.destination));state.departed_tick=_run.clock.tick_count;state.recall_tick=0;state.legacy_onsite=false;state.recognition_share=_run.recognition_share(id);state.required=AdaptationRules.protection_workers(CONFIG.protection_workers,state.recognition_share)
	state.energy_multiplier=snappedf(AdaptationRules.energy_multiplier(pile.adaptation_repertoire,pile.adaptation_fraction())*(1.0+AdaptationRules.CHEMISTRY.extra_travel_energy*pile.chemistry_fraction()),0.00001);pile.recognition_experience=true
func tick() -> void:
	var ids: Array=_run.honeydew.services.keys();ids.sort()
	for id: String in ids:
		var state: ProducerServiceState=_state(id)
		if state.phase=="none":
			if state.target>0:_depart(id,state)
			continue
		if state.phase=="working":continue
		state.elapsed_ticks+=1
		if state.elapsed_ticks<state.leg_ticks:continue
		state.elapsed_ticks=0
		if state.phase=="outbound":
			var node: WorldNodeState=_run.world.nodes.get(CONFIG.source_id)
			if node!=null and node.definition_id=="carbohydrate" and node.position.distance_to(state.destination)<=TRAILS.interaction_radius:state.phase="working"
			else:state.phase="returning";state.target=0;state.recall_tick=_run.clock.tick_count;state.private_failure=true;state.failure_goal_hidden=true
		else:_return(id,state)
	_sync()
func _return(id: String, state: ProducerServiceState) -> void:
	var pile: PileState=_run.colony.piles[id];var pool: String="honeydew:"+id
	var released: bool=pile.workers.release(pool,state.count);var retired: bool=pile.workers.retire_commitment(pool);assert(released and retired)
	state.last_returned_tick=_run.clock.tick_count;state.last_result="not_found" if state.private_failure else "returned";state.private_failure=false;state.failure_goal_hidden=false;state.phase="none";state.count=0;state.elapsed_ticks=0;state.leg_ticks=0;state.destination=Vector2.ZERO;state.departed_tick=0;state.recall_tick=0;state.required=0;state.recognition_share=0;state.energy_multiplier=1;state.legacy_onsite=false
func _sync() -> void:
	var honey: HoneydewState=_run.honeydew;var home: ProducerServiceState=honey.services.get("home")
	honey.protection_workers=home.count if home!=null else 0;honey.recognition_share=home.recognition_share if home!=null else 0
	if not honey.services.is_empty():honey.relationship="tended" if honey.services.values().any(func(state: ProducerServiceState)->bool:return state.known_target()>0) else "exploited"
func summary(id: String) -> Dictionary:
	var state: ProducerServiceState=_state(id);var suggestion: int=AdaptationRules.protection_workers(CONFIG.protection_workers,_run.recognition_share(id))
	var target: int=state.known_target() if state!=null else 0
	return {"knowledge_id":"known:"+CONFIG.source_id,"relationship":"tended" if target>0 else _run.honeydew.relationship if _run.honeydew.relationship=="unknown" else "exploited","target":target,"protection_workers":state.count if state!=null else 0,"required_workers":suggestion,"captured_suggestion":state.required if state!=null and state.count>0 else suggestion,"cap":ProducerServiceState.CAP,"cost":_cost(id,target if target>0 else suggestion),"return_requested":state!=null and state.count>0 and state.known_target()!=state.count,"blocker":blocker(id,target if target>0 else suggestion),"last_returned_tick":state.last_returned_tick if state!=null else 0,"last_result":state.last_result if state!=null else ""}
