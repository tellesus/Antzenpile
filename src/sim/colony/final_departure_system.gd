class_name FinalDepartureSystem
extends WorkerReinforcementSystem
func _transport() -> EvacuationTransportState:return _connection().evacuations[_source_id]
func _state() -> WorkerReinforcementState:return _transport().movement if _connection()!=null else WorkerReinforcementState.new()
func _dependent_blocker() -> String:
	var source: PileState=_source()
	if source.queen.count>0 or source.queen.replacing() or not source.brood_cohorts.is_empty() or source.reproduction.phase!="none":return "Rescue the queen and funded brood before final departure"
	if source.queen.in_transit or source.royal_reserved or source.brood_reserved_space>0:return "Dependent return/receiving space is still promised"
	for connection: ConnectionTrafficState in _run.all_connections():
		if _source_id in [connection.parent_id,connection.child_id] and connection.busy():return "Finish or recall paid connection trips first"
	for scout: ScoutAgent in _run.scouts.values():
		if scout.origin_pile==_source_id:return "Recall local scouts and await their physical return"
	if source.workers_available!=source.workers_total:return "Release local staff and recall all external commitments first"
	return ""
func _viable_target() -> bool:
	var target: PileState=_target()
	return not target.relinquished and (target.queen.count>0 or target.queen.replacing() or target.reproduction.phase!="none")
func blocker(_count: int=CONFIG.reinforcement_workers) -> String:
	if _connection()==null or _connection().target(_source_id).is_empty():return "Choose an active adjacent destination"
	if _source().relinquished:return "This nest has already been relinquished"
	if _connection().closed:return "Reopen the selected connection for final departure"
	var dependents: String=_dependent_blocker()
	if not dependents.is_empty():return dependents
	if not _viable_target():return "Recipient needs an actual queen or paid reproductive continuation"
	if _transport().manifests.size()>=EvacuationTransportState.LIMIT:return "Final departure history is full"
	if _source().workers_total==0:return ""
	return super.blocker(_source().workers_total)
func _organs() -> Array[String]:
	var result: Array[String]=[];var source: PileState=_source()
	if source.nursery_state=="developed":result.append("nursery")
	if source.food_exchange_state=="developed":result.append("food_exchange")
	if source.midden.state=="developed":result.append("midden")
	for id: String in source.chambers.projects:
		if source.chambers.complete(id):result.append(id)
	return result
func start(_count: int=CONFIG.reinforcement_workers) -> bool:
	last_error=blocker()
	if not last_error.is_empty():return false
	var source: PileState=_source();var count: int=source.workers_total
	var profiles: Dictionary=source.genetics.migration_plan(count,count) if count>0 else {}
	if count>0 and not super.start(count):return false
	var state: EvacuationTransportState=_transport();state.source_id=source.id
	var sequence: int=1
	for connection: ConnectionTrafficState in _run.all_connections():
		if connection.evacuations.has(source.id):sequence+=connection.evacuations[source.id].manifests.size()
	state.manifests.append({"sequence":sequence,"departed_tick":_run.clock.tick_count,"arrived_tick":_run.clock.tick_count if count==0 else 0,"returned_tick":0,"workers":count,"profiles":profiles,"left_stores":source.resources.duplicate(),"left_organs":_organs(),"reason":""})
	source.relinquished=true;source.brood_intent="manual";source.queued_adaptation="";source.investments=InvestmentIntent.new();_run.all_exploration()[source.id].target=0
	for connection: ConnectionTrafficState in _run.all_connections():
		if source.id in [connection.parent_id,connection.child_id]:connection.closed=true;connection.policy_actor=source.id;connection.policy_tick=_run.clock.tick_count
	last_error="";return true
func recall() -> bool:
	if not _state().active():
		# A vacant source cannot learn a private landing from command rejection.
		if _source().relinquished and not _transport().current().is_empty():last_error="";return true
		return _reject("No outstanding final departure is known")
	if _state().phase=="outbound":_transport().current().reason="recalled"
	return super.recall()
func tick() -> void:
	var movement: WorkerReinforcementState=_state()
	if not movement.active():return
	movement.elapsed_ticks+=1
	if movement.elapsed_ticks<TRAILS.leg_ticks(_source().position.distance_to(_target().position)):return
	movement.elapsed_ticks=0
	if movement.phase=="outbound":
		if not _viable_target():_transport().current().reason="landing"
		elif _settle():
			_transport().current().arrived_tick=_run.clock.tick_count
			super._return_home();return
		else:_transport().current().reason="escorts"
		movement.phase="returning";_sync(_route())
	else:_return_home()
func _return_home() -> void:
	_transport().current().returned_tick=_run.clock.tick_count;_source().relinquished=false;super._return_home()
func summary(_count: int=CONFIG.reinforcement_workers) -> Dictionary:
	if _connection()==null:return {}
	var source: PileState=_source();var state: EvacuationTransportState=_transport();var known: Dictionary=state.current()
	var cost: float=_cost(source.workers_total) if source.workers_total>0 and not source.relinquished else 0.0
	var left: Dictionary=source.resources.duplicate()
	left.carbohydrate=maxf(0.0,roundf((left.carbohydrate-cost)*100000.0)/100000.0)
	if source.relinquished:left=_run.known_final_departure(source.id).left_stores
	return {"away":source.relinquished and not known.is_empty(),"workers":known.workers if source.relinquished and not known.is_empty() else source.workers_total,"cost":cost,"left_stores":left,"left_organs":known.left_organs.duplicate() if source.relinquished and not known.is_empty() else _organs(),"blocker":blocker(),"returned":not known.is_empty() and known.returned_tick>0,"relinquished":source.relinquished}
