class_name StoreRescueSystem
extends InterpileSupplySystem
## Finite cargo uses returning supply labor, not permanent settlers.
func _state() -> InterpileSupplyState:return _connection().stores[_source_id]
func _transport() -> StoreTransportState:return _connection().stores[_source_id]
func _draft(resource: String, amount: int) -> Dictionary:
	var plan: Dictionary=super._plan();var travel: float=plan.costs.carbohydrate-plan.cargo.carbohydrate
	plan.cargo=StoreTransportState.packet(resource,amount);plan.costs=plan.cargo.duplicate();plan.costs.carbohydrate+=travel
	return plan
func blocker(resource: String, amount: int) -> String:
	if _connection()==null or _connection().target(_source_id).is_empty():return "Choose an adjacent nest"
	if resource not in PileState.RESOURCE_IDS or not WorkerLedger.valid_count(amount) or amount<1:return "Choose a nutrient and a whole positive amount"
	if _connection().busy():return "Connection assigned; await return"
	if _transport().manifests.size()>=StoreTransportState.LIMIT:return "Store movement history is full"
	var plan: Dictionary=_draft(resource,amount)
	if amount>floori((CONFIG.carbohydrate+CONFIG.protein+CONFIG.water)*plan.carry):return "Pack exceeds current carrying capacity"
	if _source().workers_assignable<CONFIG.workers:return "Need eight available carriers; brood care held"
	return _food_blocker(plan)
func start(resource: String, amount: int) -> bool:
	last_error=blocker(resource,amount)
	if not last_error.is_empty():return false
	var state: StoreTransportState=_transport();var plan: Dictionary=_draft(resource,amount);var home: PileState=_source();var route: TrailRouteState=_route()
	if not home.workers.create_commitment("trail:"+route.id,"trail",route.id):return _reject("Connection commitment unavailable")
	var allocated: bool=home.allocate_workers("trail:"+route.id,CONFIG.workers);assert(allocated)
	state.cargo.assign(plan.cargo);state.energy_multiplier=plan.energy;state.carry_multiplier=plan.carry;state.chemistry_fraction=plan.chemistry
	state.contaminant_mass=roundf((home.food_toxicity.mass*float(amount)/home.resources.carbohydrate if resource=="carbohydrate" else 0.0)*100000000.0)/100000000.0
	var paid: bool=home.consume_resources(plan.costs);assert(paid)
	state.phase="outbound";state.elapsed_ticks=0;state.departed_tick=_run.clock.tick_count;state.trips_started+=1
	state.manifests.append({"resource":resource,"amount":amount,"departed":state.departed_tick,"arrived":0,"recalled":0,"reported":0,"energy":state.energy_multiplier,"carry":state.carry_multiplier,"chemistry":state.chemistry_fraction,"contaminant":state.contaminant_mass})
	_connection().payer_id=_source_id;_connection().last_cargo_kind="stores"
	if _connection().legacy:_run.supply_origin=_source_id
	route.allocated_workers=CONFIG.workers;route.active_workers=CONFIG.workers;route.desired_workers=0;route.status="recalling";route.delivered_total=state.delivered_total();route.receipt=state.receipt()
	return true
func recall() -> bool:
	var state: StoreTransportState=_transport()
	if not state.active():return _reject("No store carriers are away")
	if state.phase=="outbound":
		state.current().recalled=_run.clock.tick_count;state.phase="returning"
		state.elapsed_ticks=TRAILS.leg_ticks(_source().position.distance_to(_target().position))-state.elapsed_ticks
		if state.elapsed_ticks==TRAILS.leg_ticks(_source().position.distance_to(_target().position)):tick()
	last_error="";return true
func tick() -> void:
	var state: StoreTransportState=_transport()
	if not state.active():return
	var leg: int=TRAILS.leg_ticks(_source().position.distance_to(_target().position))
	if state.elapsed_ticks+1<leg:state.elapsed_ticks+=1;return
	if state.phase=="outbound":state.current().arrived=_run.clock.tick_count;super.tick();return
	state.current().reported=_run.clock.tick_count
	if state.current().arrived==0:
		for id: String in PileState.RESOURCE_IDS:
			var deposited: bool=_source().deposit_resource(id,state.cargo[id],state.contaminant_mass if id=="carbohydrate" else 0.0);assert(deposited)
		state.cargo=StoreTransportState.packet(state.current().resource,0)
	super.tick()
func summary_for(resource: String="water", amount: int=8) -> Dictionary:
	var state: StoreTransportState=_transport();var plan: Dictionary=_draft(resource if resource in PileState.RESOURCE_IDS else "water",amount)
	return {"away":state.active(),"resource":resource,"amount":amount,"capacity":floori((CONFIG.carbohydrate+CONFIG.protein+CONFIG.water)*plan.carry),"costs":plan.costs,"workers":CONFIG.workers if state.active() else 0,"age":(_run.clock.tick_count-state.departed_tick)*SimulationClock.TICK_INTERVAL if state.active() else 0.0,"blocker":blocker(resource,amount) if not state.active() else "","reports":state.trips_reported,"last_resource":state.manifests[state.trips_reported-1].resource if state.trips_reported>0 else "","last_amount":state.manifests[state.trips_reported-1].amount if state.trips_reported>0 else 0,"last_delivered":state.manifests[state.trips_reported-1].arrived>0 if state.trips_reported>0 else false}
