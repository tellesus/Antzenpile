class_name QueenRelocationSystem
extends WorkerReinforcementSystem
## Same paid ledger/travel family, with one extra physically owned mother.
func _transport() -> QueenTransportState:return _connection().queens[_source_id]
func _state() -> WorkerReinforcementState:
	return _transport().movement if _connection()!=null and _connection().queens.has(_source_id) else WorkerReinforcementState.new()
func _provisions() -> Dictionary:
	var seconds: float=TRAILS.leg_ticks(_source().position.distance_to(_target().position))*2*SimulationClock.TICK_INTERVAL
	var result: Dictionary=QueenState.CONFIG.care_costs(1)
	for id: String in PileState.RESOURCE_IDS:result[id]=snappedf(result[id]*seconds,0.00001)
	return result
func blocker(count: int=CONFIG.reinforcement_workers) -> String:
	var ordinary: String=super.blocker(count)
	if not ordinary.is_empty():return ordinary
	if count<QueenState.CONFIG.replacement_nurses:return "Need at least two settling queen escorts and one messenger"
	var source: PileState=_source();var target: PileState=_target()
	if source.queen.count!=1 or source.queen.replacing():return "A living laying mother is required"
	if target.queen.count>0 or target.queen.replacing():return "Recipient already has a queen or a funded replacement"
	if _run.queen_slot_reserved(source.id) or _run.queen_slot_reserved(target.id):return "Queen journey already reserves one of these nests"
	if _transport().manifests.size()>=QueenTransportState.LIMIT:return "Queen movement history is full"
	var inherited: Array[String]=target.planned_trait_union()
	for trait_id: String in source.queen.inherited_traits:
		if trait_id not in inherited:inherited.append(trait_id)
	if not AdaptationRules.compatible(inherited):return "Queen inheritance conflicts with recipient adults or funded brood"
	if target.queen.previous_mothers.size()>=64:return "Recipient mother history is full"
	var costs: Dictionary=_provisions();costs.carbohydrate+=_cost(count)
	for id: String in PileState.RESOURCE_IDS:
		if source.resources[id]<costs[id]:return "Need %.3f %s at %s for queen travel and care" % [costs[id],id,source.display_title()]
	return ""
func start(escorts: int=CONFIG.reinforcement_workers) -> bool:
	last_error=blocker(escorts)
	if not last_error.is_empty():return false
	var source: PileState=_source();var provisions: Dictionary=_provisions()
	if not super.start(escorts):return false
	var state: QueenTransportState=_transport();state.source_id=_source_id
	state.body=QueenTransportState.biological(source.queen,source.id)
	state.manifests.append({"reason":"","source_id":source.id,"departed_tick":_run.clock.tick_count,"arrived_tick":0,"reported_tick":0,"body":state.body.duplicate(true),"previous_mother":{}})
	var paid: bool=source.consume_resources(provisions);assert(paid)
	var released: bool=QueenSystem.new(_run).set_care(source.id,0);assert(released)
	source.queen.count=0;source.queen.condition=0;source.queen.in_transit=true
	source.queued_adaptation="";source.investments=InvestmentIntent.new()
	return true
func tick() -> void:
	var state: WorkerReinforcementState=_state()
	if not state.active():return
	state.elapsed_ticks+=1
	if state.elapsed_ticks<TRAILS.leg_ticks(_source().position.distance_to(_target().position)):return
	state.elapsed_ticks=0
	if state.phase=="outbound":
		if not _can_land():_transport().current().reason="landing"
		elif _settle():_land()
		else:_transport().current().reason="escorts"
		state.phase="returning";_sync(_route())
	else:_return_home()
func _can_land() -> bool:
	var target: PileState=_target()
	if target.queen.count!=0 or target.queen.replacing():return false
	var traits: Array[String]=target.planned_trait_union()
	for trait_id: String in _transport().body.inherited_traits:
		if trait_id not in traits:traits.append(trait_id)
	return AdaptationRules.compatible(traits)
func _land() -> void:
	var state: QueenTransportState=_transport();var target: PileState=_target();var queen: QueenState=target.queen
	var former: Dictionary=queen.mother(target.id);state.current().previous_mother=former
	if former.identity!=state.body.identity and not queen.previous_mothers.any(func(value: Dictionary)->bool:return value.identity==former.identity):queen.previous_mothers.append(former)
	queen.previous_mothers=queen.previous_mothers.filter(func(value: Dictionary)->bool:return value.identity!=state.body.identity)
	queen.identity=state.body.identity;queen.parent_identity=state.body.parent_identity;queen.generation=int(state.body.generation);queen.condition=int(state.body.condition);queen.count=1;queen.inherited_traits.assign(state.body.inherited_traits)
	queen.arrival_record={"route_id":_connection().route_id,"source_id":_source_id,"index":state.manifests.size()-1}
	state.current().arrived_tick=_run.clock.tick_count;state.body.clear()
func _return_home() -> void:
	var transport: QueenTransportState=_transport()
	if not transport.body.is_empty():
		var queen: QueenState=_source().queen
		assert(queen.count==0 and queen.queen_id(_source_id)==transport.body.identity)
		queen.count=1;queen.condition=int(transport.body.condition);transport.body.clear()
	_source().queen.in_transit=false
	transport.current().reported_tick=_run.clock.tick_count
	super._return_home()
func summary(count: int=CONFIG.reinforcement_workers) -> Dictionary:
	var result: Dictionary=super.summary(count)
	if result.is_empty():return result
	result.blocker=blocker(count) if not result.away else ""
	var transport: QueenTransportState=_transport()
	result.mother=transport.current().body.identity if transport.active() else _source().queen.queen_id(_source_id)
	result.generation=int(transport.current().body.generation) if transport.active() else _source().queen.generation
	result.queen_available=_source().queen.count==1 or transport.active()
	result.provisions=_provisions();result.minimum_escorts=QueenState.CONFIG.replacement_nurses
	result.queen_deliveries=transport.movement.reported_arrivals()
	var report: Dictionary=transport.last_report()
	result.last_result=report.get("reason","")
	return result
