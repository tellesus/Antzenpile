class_name RoyalRescueSystem
extends WorkerReinforcementSystem
const ROYAL=preload("res://data/resources/default_reproduction.tres")
const BROOD=preload("res://data/resources/default_brood.tres")
const FOOD=preload("res://data/resources/default_food_exchange.tres")
func _transport() -> RoyalTransportState:return _connection().royals[_source_id]
func _state() -> WorkerReinforcementState:return _transport().movement if _connection()!=null else WorkerReinforcementState.new()
func _payload() -> ReproductionState:
	if not _transport().active():return _source().reproduction
	var group:=ReproductionState.new();var body: Dictionary=_transport().current().body
	group.phase=body.phase;group.inherited_traits.assign(body.inherited_traits);group.parent_generation=int(body.parent_generation)
	return group
func _provisions() -> Dictionary:
	var result: Dictionary={"carbohydrate":0.0,"protein":0.0,"water":0.0};var group: ReproductionState=_payload()
	if group.phase!="larva":return result
	var seconds: float=TRAILS.leg_ticks(_source().position.distance_to(_target().position))*2*SimulationClock.TICK_INTERVAL
	var multiplier: float=FOOD.developed_larval_food_multiplier*TraitCatalog.reproductive_food_multiplier(group.inherited_traits)
	result.carbohydrate=snappedf(ROYAL.space*seconds*BROOD.carbohydrate_per_larva_second*multiplier*TraitCatalog.carbohydrate_multiplier(group.inherited_traits),0.00001)
	result.protein=snappedf(ROYAL.space*seconds*BROOD.protein_per_larva_second*multiplier,0.00001)
	result.water=snappedf(ROYAL.space*seconds*BROOD.water_per_larva_second*multiplier,0.00001)
	return result
func blocker(count: int=CONFIG.reinforcement_workers) -> String:
	var ordinary: String=super.blocker(count)
	if not ordinary.is_empty():return ordinary
	var group: ReproductionState=_source().reproduction;var target: PileState=_target()
	if group.phase=="none":return "A paid local reproductive group is required"
	if count<ROYAL.space/2+ROYAL.nurses:return "Need eight settling carriers/nurses plus one messenger"
	if _source().royal_reserved or target.royal_reserved or target.reproduction.phase!="none" or target.queen.replacing():return "Reproductive group slot is occupied or promised"
	if group.active() and (target.nursery_state!="developed" or target.food_exchange_state!="developed"):return "Develop receiving Nursery and Food Exchange for immature reproductives"
	if group.active() and target.free_reproductive_space()<ROYAL.space:return "Need eight receiving reproductive spaces"
	if _transport().manifests.size()>=RoyalTransportState.LIMIT or group.transport_count>=WorkerLedger.MAX_COUNT:return "Reproductive movement history is full"
	if target.queen.previous_mothers.size()>=64:return "Recipient mother history is full"
	var receiving_traits: Array[String]=PileState._merged_traits(target.planned_trait_union(),group.inherited_traits)
	if not target.queued_adaptation.is_empty():receiving_traits.append(target.queued_adaptation)
	if not AdaptationRules.compatible(receiving_traits):return "Reproductive inheritance conflicts with recipient adults or paid brood"
	var costs: Dictionary=_provisions();costs.carbohydrate+=_cost(count)
	for id: String in PileState.RESOURCE_IDS:
		if _source().resources[id]<costs[id]:return "Need %.3f %s at %s for travel and reproductive feeding" % [costs[id],id,_source().display_title()]
	return ""
func start(staff: int=CONFIG.reinforcement_workers) -> bool:
	last_error=blocker(staff)
	if not last_error.is_empty():return false
	var source: PileState=_source();var group: ReproductionState=source.reproduction;var provisions: Dictionary=_provisions()
	if not super.start(staff):return false
	if group.origin_pile.is_empty():group.origin_pile=source.id
	group.transport_count+=1;group.food_shortfalls.clear()
	var transport: RoyalTransportState=_transport();transport.source_id=source.id;transport.body=group.to_dict()
	transport.manifests.append({"source_id":source.id,"departed_tick":_run.clock.tick_count,"arrived_tick":0,"reported_tick":0,"reason":"","body":transport.body.duplicate(true)})
	var paid: bool=source.consume_resources(provisions);assert(paid)
	if group.active():
		var released: bool=source.workers.release("reproduction:"+source.id,ROYAL.nurses);var retired: bool=source.workers.retire_commitment("reproduction:"+source.id);assert(released and retired)
	source.reproduction=ReproductionState.new();_run.refresh_royal_reservations();return true
func _can_land() -> bool:
	var group: ReproductionState=_payload();var target: PileState=_target()
	if target.reproduction.phase!="none" or target.queen.replacing():return false
	if group.active() and (target.nursery_state!="developed" or target.food_exchange_state!="developed"):return false
	return AdaptationRules.compatible(PileState._merged_traits(target.planned_trait_union(),group.inherited_traits))
func tick() -> void:
	var movement: WorkerReinforcementState=_state()
	if not movement.active():return
	movement.elapsed_ticks+=1
	if movement.elapsed_ticks<TRAILS.leg_ticks(_source().position.distance_to(_target().position)):return
	movement.elapsed_ticks=0
	if movement.phase=="outbound":
		if not _can_land():_transport().current().reason="landing"
		elif _settle():
			_transport().current().arrived_tick=_run.clock.tick_count;movement.phase="returning";_run.refresh_royal_reservations();_receive(_target())
		else:_transport().current().reason="escorts"
		movement.phase="returning";_sync(_route())
	else:_return_home()
func _receive(target: PileState) -> void:
	var transport: RoyalTransportState=_transport();var body: Dictionary=transport.body;var ledger: WorkerLedger=target.workers
	if body.phase in ["egg","larva","pupa"]:
		var created: bool=ledger.create_commitment("reproduction:"+target.id,"internal",target.id);var assigned: bool=target.allocate_workers("reproduction:"+target.id,ROYAL.nurses);assert(created and assigned)
	var group:=ReproductionState.new();var parsed: bool=group.restore(body,ledger,target.id,TraitCatalog.IDS,target.brood_matured_total,target.nursery_state,target.food_exchange_state,target.queen_count);assert(parsed)
	if not group.parent_queen_id.is_empty() and group.parent_queen_id!=target.queen.queen_id(target.id) and not target.queen.previous_mothers.any(func(record: Dictionary)->bool:return record.identity==group.parent_queen_id):target.queen.previous_mothers.append(group.mother_record())
	for exposure: String in group.environment_exposure:
		if exposure not in target.environment.seen:target.environment.seen.append(exposure)
	if group.repair_comparison:target.repair_experience=true
	target.reproduction=group;transport.body.clear()
func _return_home() -> void:
	var transport: RoyalTransportState=_transport();transport.current().reported_tick=_run.clock.tick_count
	var returned: bool=not transport.body.is_empty();super._return_home();_run.refresh_royal_reservations()
	if returned:_receive(_source())
func summary(count: int=CONFIG.reinforcement_workers) -> Dictionary:
	var result: Dictionary=super.summary(count)
	if result.is_empty():return result
	var group: ReproductionState=_payload();result.stage=group.phase;result.generation=group.parent_generation+1;result.minimum_staff=ROYAL.space/2+ROYAL.nurses;result.provisions=_provisions();result.blocker=blocker(count) if not result.away else ""
	var report: Dictionary=_transport().last_report();result.deliveries=_state().reported_arrivals();result.last_result=report.get("reason","")
	return result
