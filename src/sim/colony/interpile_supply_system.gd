class_name InterpileSupplySystem
extends RefCounted
const CONFIG=preload("res://data/resources/default_interpile_supply.tres")
const TRAILS=preload("res://data/trails/default_trails.tres")
var _source_id: String = "home"
var _route_id: String=""
var _run: RunState
var last_error: String=""
func _init(run_state: RunState, source_id: String = "home", route_id: String="") -> void: _run=run_state; _source_id=source_id;_route_id=route_id
func _connection() -> ConnectionTrafficState: return _run.connection_for(_route_id if not _route_id.is_empty() else _run.founding.route_id)
func _state() -> InterpileSupplyState:
 var connection: ConnectionTrafficState=_connection()
 return connection.supplies[_source_id] if connection!=null else _run.supply if _source_id=="home" else _run.daughter_supply
func _other() -> InterpileSupplyState: return _connection().supplies[_connection().target(_source_id)]
func _source() -> PileState: return _run.colony.piles[_source_id]
func _target() -> PileState: return _run.colony.piles[_connection().target(_source_id)]
func _name() -> String: return _source().display_title()
func _route() -> TrailRouteState: return _run.trails.routes[_connection().route_id]
func _migration_active() -> bool:
 for state: EvacuationTransportState in _connection().evacuations.values():
  if state.active():return true
 for state: RoyalTransportState in _connection().royals.values():
  if state.active():return true
 for state: StoreTransportState in _connection().stores.values():
  if state.active():return true
 for state: BroodTransportState in _connection().broods.values():
  if state.active():return true
 for state: QueenTransportState in _connection().queens.values():
  if state.active():return true
 for state: WorkerReinforcementState in _connection().migrations.values():
  if state.active():return true
 return false
func set_enabled(value: Variant) -> bool:
 if not value is bool: return _reject("Supply intent must be on or off")
 if _connection()==null or not _connection().supplies.has(_source_id): return _reject("Establish a reported daughter pile first")
 if value and (_source().relinquished or _target().relinquished):return _reject("One of these nests has been relinquished")
 if value and _connection().closed:return _reject("Connection closed to new traffic; reopen it first")
 var state: InterpileSupplyState=_state()
 if value and _other().phase != "none": return _reject("Other supply direction assigned; stop it and await return")
 if _migration_active(): return _reject("Wait for the worker reinforcement party to return")
 if value==state.enabled: return _reject("Supply intent already set")
 var route: TrailRouteState=_route()
 var home: PileState=_source()
 if value and state.phase=="none":
  if home.workers_assignable<CONFIG.workers: return _reject("Need %d available %s supply workers" % [CONFIG.workers,_name()])
  if not home.workers.create_commitment("trail:"+route.id,"trail",route.id): return _reject("Supply commitment unavailable")
  var allocated: bool=home.allocate_workers("trail:"+route.id,CONFIG.workers); assert(allocated)
  route.allocated_workers=CONFIG.workers;state.phase="waiting"
 _connection().payer_id=_source_id;_connection().last_cargo_kind="supplies"
 if _connection().legacy:_run.supply_origin = _source_id
 route.delivered_total=state.delivered_total();route.receipt=state.receipt()
 state.enabled=value;route.desired_workers=CONFIG.workers if value else 0
 route.status="active" if value else "recalling"
 if not value and state.phase=="waiting": _release(route)
 last_error="";return true
func _reject(reason: String) -> bool: last_error=reason;return false
func _plan() -> Dictionary:
 var home: PileState=_source()
 var route: TrailRouteState=_route()
 var segment: TrailSegmentState=_run.trails.segments[route.segment_id]
 var fraction: float=home.adaptation_fraction()
 var energy: float=snappedf(AdaptationRules.energy_multiplier(home.adaptation_repertoire,fraction),0.00001)
 var carry: float=snappedf(AdaptationRules.carry_multiplier(home.adaptation_repertoire,fraction),0.00001)
 var chemistry: float=snappedf(home.chemistry_fraction(),0.00001)
 var cost: float=TRAILS.round_trip_energy_cost(CONFIG.workers,segment.start.distance_to(segment.end),TrailSegmentState.terrain_cost_for(_run.world,segment.start,segment.end))*energy*(1.0+AdaptationRules.CHEMISTRY.extra_travel_energy*chemistry)
 var cargo: Dictionary[String,float]=CONFIG.pack(carry)
 var costs: Dictionary=cargo.duplicate();costs.carbohydrate+=cost
 return {"cargo":cargo,"costs":costs,"energy":energy,"carry":carry,"chemistry":chemistry}
func _food_blocker(plan: Dictionary) -> String:
 if _state().trips_started>=WorkerLedger.MAX_COUNT: return "Supply trip history is full"
 for id: String in PileState.RESOURCE_IDS:
  if _state().delivered_units[id]>WorkerLedger.MAX_COUNT-roundi(plan.cargo[id]*100000): return "Supply receipt history is full"
  if _source().resources[id]<plan.costs[id]: return "%s needs %.2f %s per departure" % [_name(),plan.costs[id],id]
 return ""
func tick() -> void:
 var state: InterpileSupplyState=_state()
 if state.phase=="none": return
 var route: TrailRouteState=_route()
 var home: PileState=_source()
 if state.phase=="waiting":
  var plan: Dictionary=_plan()
  if not _food_blocker(plan).is_empty(): return
  state.cargo.assign(plan.cargo);state.energy_multiplier=plan.energy;state.carry_multiplier=plan.carry;state.chemistry_fraction=plan.chemistry
  state.contaminant_mass=roundf(home.food_toxicity.mass*state.cargo.carbohydrate/home.resources.carbohydrate*100000000.0)/100000000.0
  var paid: bool=home.consume_resources(plan.costs);assert(paid)
  state.phase="outbound";state.departed_tick=_run.clock.tick_count;state.trips_started+=1;route.active_workers=CONFIG.workers
  return
 _residue_contact()
 state.elapsed_ticks+=1
 var daughter: PileState=_target()
 var leg: int=TRAILS.leg_ticks(home.position.distance_to(daughter.position))
 if state.elapsed_ticks<leg: return
 state.elapsed_ticks=0
 if state.phase=="outbound":
  for id: String in PileState.RESOURCE_IDS:
   var deposited: bool=daughter.deposit_resource(id,state.cargo[id],state.contaminant_mass if id=="carbohydrate" else 0.0);assert(deposited)
  state.phase="returning";return
 # Delivery report and route reinforcement arrive with the actual returning party.
 if state.residue.contact.active():state.last_residue_report=state.residue.contact.report(_run.simulation_time)
 state.residue=CargoResidueState.new()
 state.trips_reported+=1;state.last_reported_tick=_run.clock.tick_count
 if state.first_reported_tick==0: state.first_reported_tick=state.last_reported_tick
 state.last_payload=state.cargo.duplicate()
 for id: String in PileState.RESOURCE_IDS: state.delivered_units[id]+=roundi(state.cargo[id]*100000)
 route.delivered_total=state.delivered_total();route.receipt=state.receipt();route.active_workers=0
 var segment: TrailSegmentState=_run.trails.segments[route.segment_id]
 segment.reinforce_chemistry(CONFIG.workers*TRAILS.pheromone_per_returning_worker,state.chemistry_fraction)
 segment.route_familiarity=minf(1.0,snappedf(segment.route_familiarity+CONFIG.workers*TRAILS.familiarity_per_returning_worker,0.0000000001));segment.traffic+=CONFIG.workers
 state.cargo.clear();state.contaminant_mass=0;state.energy_multiplier=1;state.carry_multiplier=1;state.chemistry_fraction=0
 state.phase="waiting"
 if not state.enabled: _release(route)
func _release(route: TrailRouteState) -> void:
 var ledger: WorkerLedger=_source().workers
 var released: bool=ledger.release("trail:"+route.id,CONFIG.workers);assert(released)
 var retired: bool=ledger.retire_commitment("trail:"+route.id);assert(retired)
 route.allocated_workers=0;route.active_workers=0;route.status="inactive"
 _state().phase="none"
func _residue_contact() -> void:
 var state: InterpileSupplyState=_state()
 if not state.travelling() or state.residue.contact.active():return
 var leg: int=TRAILS.leg_ticks(_source().position.distance_to(_target().position))
 var progress: float=float(state.elapsed_ticks)/leg
 if state.phase=="returning":progress=1.0-progress
 var point: Vector2=_source().position.lerp(_target().position,progress)
 if not _run.connection_residue.contains(point,_run.clock.tick_count):return
 state.residue.contact.capture(point,_run.clock.tick_count)
 var carrying: bool=state.phase=="outbound" or state is StoreTransportState and state.current().arrived==0
 if carrying and state.cargo.get("carbohydrate",0.0)>0:
  state.residue.exposed=true;state.residue.original_mass=state.contaminant_mass
  state.contaminant_mass=ResidueZoneState.contaminated(state.cargo.carbohydrate,state.contaminant_mass,CargoResidueState.CONFIG)
 if state is StoreTransportState:
  state.current().residue=state.residue.to_dict();state.current().contaminant=state.contaminant_mass
func summary() -> Dictionary:
 if _connection()==null or not _connection().supplies.has(_source_id): return {}
 var state: InterpileSupplyState=_state()
 var result: Dictionary={"source_id":_source_id,"source_name":_name(),"destination_id":_target().id,"destination_name":_target().display_title(),"route_id":_connection().route_id, "enabled":state.enabled,"status":"away" if state.travelling() else state.phase,"workers":state.assigned(),"workers_required":CONFIG.workers,"trips_reported":state.trips_reported,"last_payload":state.last_payload.duplicate(),"reported_total":state.delivered_total()}
 result.costs=_plan().costs
 if state.travelling():
  result.age=(_run.clock.tick_count-state.departed_tick)*SimulationClock.TICK_INTERVAL
 elif state.phase=="waiting": result.blocker=_food_blocker(_plan())
 else: result.blocker="Need %d available %s workers" % [CONFIG.workers,_name()] if _source().workers_assignable<CONFIG.workers else ""
 if state.trips_reported>0: result.report_age=(_run.clock.tick_count-state.last_reported_tick)*SimulationClock.TICK_INTERVAL
 if _other().phase != "none": result.blocker="Other direction assigned; stop it and await return"
 if _migration_active():result.blocker="Worker party away; await return"
 if _connection().closed and not state.travelling():result.blocker="Connection closed to new traffic; reopen it first"
 return result
