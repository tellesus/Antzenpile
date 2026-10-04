class_name InterpileSupplySystem
extends RefCounted
const CONFIG=preload("res://data/resources/default_interpile_supply.tres")
const TRAILS=preload("res://data/trails/default_trails.tres")
var _run: RunState
var last_error: String=""
func _init(run_state: RunState) -> void: _run=run_state
func set_enabled(value: Variant) -> bool:
 if not value is bool: return _reject("Supply intent must be on or off")
 if _run.founding.phase!="established" or not _run.colony.piles.has("satellite_1"): return _reject("Establish a reported daughter pile first")
 var state: InterpileSupplyState=_run.supply
 if _run.reinforcement.active(): return _reject("Wait for the worker reinforcement party to return")
 if value==state.enabled: return _reject("Supply intent already set")
 var route: TrailRouteState=_run.trails.routes[_run.founding.route_id]
 var home: PileState=_run.colony.piles.home
 if value and state.phase=="none":
  if home.workers_assignable<CONFIG.workers: return _reject("Need %d available Home supply workers" % CONFIG.workers)
  if not home.workers.create_commitment("trail:"+route.id,"trail",route.id): return _reject("Supply commitment unavailable")
  var allocated: bool=home.allocate_workers("trail:"+route.id,CONFIG.workers); assert(allocated)
  route.allocated_workers=CONFIG.workers;state.phase="waiting"
 state.enabled=value;route.desired_workers=CONFIG.workers if value else 0
 route.status="active" if value else "recalling"
 if not value and state.phase=="waiting": _release(route)
 last_error="";return true
func _reject(reason: String) -> bool: last_error=reason;return false
func _plan() -> Dictionary:
 var home: PileState=_run.colony.piles.home
 var route: TrailRouteState=_run.trails.routes[_run.founding.route_id]
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
 if _run.supply.trips_started>=WorkerLedger.MAX_COUNT: return "Supply trip history is full"
 for id: String in PileState.RESOURCE_IDS:
  if _run.supply.delivered_units[id]>WorkerLedger.MAX_COUNT-roundi(plan.cargo[id]*100000): return "Supply receipt history is full"
  if _run.colony.piles.home.resources[id]<plan.costs[id]: return "Home needs %.2f %s per departure" % [plan.costs[id],id]
 return ""
func tick() -> void:
 var state: InterpileSupplyState=_run.supply
 if state.phase=="none": return
 var route: TrailRouteState=_run.trails.routes[_run.founding.route_id]
 var home: PileState=_run.colony.piles.home
 if state.phase=="waiting":
  var plan: Dictionary=_plan()
  if not _food_blocker(plan).is_empty(): return
  state.cargo.assign(plan.cargo);state.energy_multiplier=plan.energy;state.carry_multiplier=plan.carry;state.chemistry_fraction=plan.chemistry
  state.contaminant_mass=roundf(home.food_toxicity.mass*state.cargo.carbohydrate/home.resources.carbohydrate*100000000.0)/100000000.0
  var paid: bool=home.consume_resources(plan.costs);assert(paid)
  state.phase="outbound";state.departed_tick=_run.clock.tick_count;state.trips_started+=1;route.active_workers=CONFIG.workers
  return
 state.elapsed_ticks+=1
 var daughter: PileState=_run.colony.piles.satellite_1
 var leg: int=TRAILS.leg_ticks(home.position.distance_to(daughter.position))
 if state.elapsed_ticks<leg: return
 state.elapsed_ticks=0
 if state.phase=="outbound":
  for id: String in PileState.RESOURCE_IDS:
   var deposited: bool=daughter.deposit_resource(id,state.cargo[id],state.contaminant_mass if id=="carbohydrate" else 0.0);assert(deposited)
  state.phase="returning";return
 # Delivery report and route reinforcement arrive with the actual returning party.
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
 var ledger: WorkerLedger=_run.colony.piles.home.workers
 var released: bool=ledger.release("trail:"+route.id,CONFIG.workers);assert(released)
 var retired: bool=ledger.retire_commitment("trail:"+route.id);assert(retired)
 route.allocated_workers=0;route.active_workers=0;route.status="inactive"
 _run.supply.phase="none"
func summary() -> Dictionary:
 if _run.founding.phase!="established": return {}
 var state: InterpileSupplyState=_run.supply
 var result: Dictionary={"enabled":state.enabled,"status":"away" if state.travelling() else state.phase,"workers":state.assigned(),"workers_required":CONFIG.workers,"trips_reported":state.trips_reported,"last_payload":state.last_payload.duplicate(),"reported_total":state.delivered_total()}
 if state.travelling():
  result.age=(_run.clock.tick_count-state.departed_tick)*SimulationClock.TICK_INTERVAL
 elif state.phase=="waiting": result.blocker=_food_blocker(_plan())
 else: result.blocker="Need %d available Home workers" % CONFIG.workers if _run.colony.piles.home.workers_assignable<CONFIG.workers else ""
 if state.trips_reported>0: result.report_age=(_run.clock.tick_count-state.last_reported_tick)*SimulationClock.TICK_INTERVAL
 if _run.reinforcement.active():result.blocker="Worker party away; await return"
 return result
