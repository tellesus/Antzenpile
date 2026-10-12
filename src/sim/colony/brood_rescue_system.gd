class_name BroodRescueSystem
extends WorkerReinforcementSystem
const BROOD=preload("res://data/resources/default_brood.tres")
const FOOD=preload("res://data/resources/default_food_exchange.tres")
var _cohort_uid: String=""
func _init(run_state: RunState, source_id: String="home", route_id: String="", cohort_uid: String="") -> void:
	super._init(run_state,source_id,route_id);_cohort_uid=cohort_uid
func _transport() -> BroodTransportState:return _connection().broods[_source_id]
func _state() -> WorkerReinforcementState:return _transport().movement if _connection()!=null and _connection().broods.has(_source_id) else WorkerReinforcementState.new()
func _cohort() -> BroodCohort:
	for cohort: BroodCohort in _source().brood_cohorts:
		if _cohort_uid.is_empty() or cohort.uid(_source_id)==_cohort_uid:return cohort
	return null
func _payload() -> BroodCohort:
	if _transport().active():
		var cohort:=BroodCohort.new();var restored: bool=cohort.restore(_transport().current().body);assert(restored);return cohort
	return _cohort()
func minimum_staff(cohort: BroodCohort) -> int:return ceili(float(cohort.count)/2.0)+AdaptationRules.NURSES
func _provisions(cohort: BroodCohort) -> Dictionary:
	var result: Dictionary={"carbohydrate":0.0,"protein":0.0,"water":0.0}
	if cohort==null or cohort.stage!="larva":return result
	var seconds: float=TRAILS.leg_ticks(_source().position.distance_to(_target().position))*2*SimulationClock.TICK_INTERVAL
	var multiplier: float=TraitCatalog.food_multiplier(cohort.inherited_traits)*(FOOD.developed_larval_food_multiplier if _source().food_exchange_state=="developed" else 1.0)
	result.carbohydrate=snappedf(cohort.count*seconds*BROOD.carbohydrate_per_larva_second*multiplier*TraitCatalog.carbohydrate_multiplier(cohort.inherited_traits),0.00001)
	result.protein=snappedf(cohort.count*seconds*BROOD.protein_per_larva_second*multiplier,0.00001)
	result.water=snappedf(cohort.count*seconds*BROOD.water_per_larva_second*multiplier,0.00001)
	return result
func blocker(count: int=CONFIG.reinforcement_workers) -> String:
	var ordinary: String=super.blocker(count)
	if not ordinary.is_empty():return ordinary
	var cohort: BroodCohort=_cohort()
	if cohort==null:return "Choose an actual local funded worker cohort"
	if count<minimum_staff(cohort):return "Need %d settling carriers/carers plus one returning messenger" % minimum_staff(cohort)
	if _transport().manifests.size()>=BroodTransportState.LIMIT:return "Brood movement history is full"
	if cohort.transport_count>=WorkerLedger.MAX_COUNT or _source().brood_transferred_out>WorkerLedger.MAX_COUNT-cohort.count or _target().brood_transferred_in>WorkerLedger.MAX_COUNT-cohort.count:return "Brood transfer history is full"
	if _target().brood_cohorts.size()+_target().brood_reserved_groups>=_target().nursery_brood_capacity()/BROOD.starting_count:return "Recipient lacks a receiving cohort slot"
	if _target().free_worker_brood_space()<cohort.count or _source().brood_reserved_space>WorkerLedger.MAX_COUNT-cohort.count:return "Recipient lacks receiving brood space"
	if cohort.adaptation_trial and (_target().trial_cohort()!=null or not _target().brood_reserved_trial.is_empty()):return "Recipient already has a paid or incoming trial"
	if _target().queen.previous_mothers.size()>=64 and not cohort.parent_queen_id.is_empty() and cohort.parent_queen_id!=_target().queen.queen_id(_target().id) and not _target().queen.previous_mothers.any(func(record: Dictionary)->bool:return record.identity==cohort.parent_queen_id):return "Recipient mother history is full"
	if _target().brood_lineages.size()>=512 and not _target().brood_lineages.has(cohort.uid(_source_id)):return "Recipient brood lineage history is full"
	var traits: Array[String]=_target().planned_trait_union()
	for trait_id: String in cohort.inherited_traits:
		if trait_id not in traits:traits.append(trait_id)
	if not AdaptationRules.compatible(traits):return "Recipient inheritance/paid brood conflicts with this cohort"
	var costs: Dictionary=_provisions(cohort);costs.carbohydrate+=_cost(count)
	for id: String in PileState.RESOURCE_IDS:
		if _source().resources[id]<costs[id]:return "Need %.3f %s at %s for travel and brood feeding" % [costs[id],id,_source().display_title()]
	return ""
func start(staff: int=CONFIG.reinforcement_workers) -> bool:
	last_error=blocker(staff)
	if not last_error.is_empty():return false
	var source: PileState=_source();var cohort: BroodCohort=_cohort();var provisions: Dictionary=_provisions(cohort)
	if not super.start(staff):return false
	if cohort.origin_pile.is_empty():cohort.origin_pile=source.id
	cohort.transport_count+=1;cohort.care=1;cohort.nutrition=1;cohort.nutrition_shortfalls.clear()
	var state: BroodTransportState=_transport();state.source_id=source.id;state.body=cohort.to_dict()
	state.manifests.append({"source_id":source.id,"departed_tick":_run.clock.tick_count,"arrived_tick":0,"reported_tick":0,"reason":"","body":state.body.duplicate(true)})
	var paid: bool=source.consume_resources(provisions);assert(paid)
	source.brood_cohorts.erase(cohort);source.brood_transferred_out+=cohort.count
	if cohort.adaptation_trial:
		var released: bool=source.workers.release("adaptation:"+source.id,AdaptationRules.NURSES);var retired: bool=source.workers.retire_commitment("adaptation:"+source.id);assert(released and retired)
	_run.refresh_brood_reservations();return true
func tick() -> void:
	var movement: WorkerReinforcementState=_state()
	if not movement.active():return
	movement.elapsed_ticks+=1
	if movement.elapsed_ticks<TRAILS.leg_ticks(_source().position.distance_to(_target().position)):return
	movement.elapsed_ticks=0
	if movement.phase=="outbound":
		if not _can_land():_transport().current().reason="landing"
		elif _settle():
			_transport().current().arrived_tick=_run.clock.tick_count
			movement.phase="returning";_run.refresh_brood_reservations();_receive(_target())
		else:_transport().current().reason="escorts"
		movement.phase="returning";_sync(_route())
	else:_return_home()
func _can_land() -> bool:
	var cohort: BroodCohort=_payload();var target: PileState=_target()
	if target.brood_cohorts.size()+target.brood_reserved_groups>target.nursery_brood_capacity()/BROOD.starting_count:return false
	if target.free_worker_brood_space()+cohort.count<cohort.count:return false
	if cohort.adaptation_trial and target.trial_cohort()!=null:return false
	var traits: Array[String]=target.planned_trait_union()
	for trait_id: String in cohort.inherited_traits:
		if trait_id not in traits:traits.append(trait_id)
	return AdaptationRules.compatible(traits)
func _receive(target: PileState) -> void:
	var transport: BroodTransportState=_transport();var cohort:=BroodCohort.new();var parsed: bool=cohort.restore(transport.body);assert(parsed)
	cohort.inherited_lost=cohort.lost_count;target.brood_transferred_in+=cohort.count
	var uid: String=cohort.uid(target.id);target.brood_lineages[uid]=cohort.inherited_traits.duplicate()
	if not cohort.parent_queen_id.is_empty() and cohort.parent_queen_id!=target.queen.queen_id(target.id) and not target.queen.previous_mothers.any(func(record: Dictionary)->bool:return record.identity==cohort.parent_queen_id):target.queen.previous_mothers.append(cohort.mother_record())
	for exposure: String in cohort.environment_exposure:
		if exposure not in target.environment.seen:target.environment.seen.append(exposure)
	if cohort.rain_comparison:target.rain_trace_observed=true
	if cohort.recognition_comparison:target.recognition_experience=true
	if cohort.repair_comparison:target.repair_experience=true
	target.brood_cohorts.append(cohort)
	if cohort.adaptation_trial:
		var created: bool=target.workers.create_commitment("adaptation:"+target.id,"internal",target.id);var assigned: bool=target.allocate_workers("adaptation:"+target.id,AdaptationRules.NURSES);assert(created and assigned)
	transport.body.clear()
func _return_home() -> void:
	var state: BroodTransportState=_transport();state.current().reported_tick=_run.clock.tick_count
	# Returned carriers become actual local labor before receiving the dependent body.
	var returned: bool=not state.body.is_empty();super._return_home();_run.refresh_brood_reservations()
	if returned:_receive(_source())
func summary(count: int=CONFIG.reinforcement_workers) -> Dictionary:
	var result: Dictionary=super.summary(count)
	if result.is_empty():return result
	var cohort: BroodCohort=_payload()
	result.cohort_uid=cohort.uid(_source_id) if cohort!=null else "";result.stage=cohort.stage if cohort!=null else "none";result.count=cohort.count if cohort!=null else 0;result.trial=cohort.adaptation_trial if cohort!=null else false
	result.minimum_staff=minimum_staff(cohort) if cohort!=null else 0;result.carers=AdaptationRules.NURSES;result.provisions=_provisions(cohort)
	result.blocker=blocker(count) if not result.away else ""
	var report: Dictionary=_transport().last_report();result.deliveries=_state().reported_arrivals();result.last_count=report.body.count if not report.is_empty() and report.arrived_tick>0 else 0;result.last_result=report.get("reason","")
	return result
