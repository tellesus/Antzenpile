class_name WorkerReinforcementSystem
extends RefCounted
const CONFIG=preload("res://data/resources/default_interpile_supply.tres")
const TRAILS=preload("res://data/trails/default_trails.tres")
var _source_id: String="home"
var _route_id: String=""
var _run: RunState
var last_error: String=""
func _init(run_state: RunState, source_id: String="home", route_id: String="") -> void:_run=run_state;_source_id=source_id;_route_id=route_id
func _connection() -> ConnectionTrafficState:return _run.connection_for(_route_id if not _route_id.is_empty() else _run.founding.route_id)
func _state() -> WorkerReinforcementState:
 var connection: ConnectionTrafficState=_connection()
 return connection.migrations[_source_id] if connection!=null else _run.reinforcement
func _source() -> PileState:return _run.colony.piles[_source_id]
func _target() -> PileState:return _run.colony.piles[_connection().target(_source_id)]
func _route() -> TrailRouteState:return _run.trails.routes[_connection().route_id]
func _reject(reason: String) -> bool:last_error=reason;return false
func _cost(count: int=CONFIG.reinforcement_workers) -> float:
 var h: PileState=_source();var d: PileState=_target()
 var energy: float=AdaptationRules.energy_multiplier(h.adaptation_repertoire,h.adaptation_fraction())*(1.0+AdaptationRules.CHEMISTRY.extra_travel_energy*h.chemistry_fraction())
 # Settlers need one leg; the real messenger needs both.
 var equivalent: float=float(count)/2.0+CONFIG.reinforcement_messengers
 var base_cost: float=roundf(equivalent*h.position.distance_to(d.position)*TrailSegmentState.terrain_cost_for(_run.world,h.position,d.position)*TRAILS.carbohydrate_per_worker_meter*100000.0)/100000.0
 return snappedf(base_cost*energy,0.00001)
func blocker(count: int=CONFIG.reinforcement_workers) -> String:
 if _connection()==null or not _connection().migrations.has(_source_id):return "Establish an adjacent pile first"
 if _connection().closed:return "Connection closed to new traffic; reopen it first"
 if not WorkerLedger.valid_count(count) or count<1 or count>=WorkerLedger.MAX_COUNT:return "Choose a whole positive settler count"
 if _connection().busy():return "Connection assigned; stop its job and await return"
 var h: PileState=_source();var d: PileState=_target()
 var required: int=count+CONFIG.reinforcement_messengers
 if h.workers_assignable<required:return "Need %d available %s workers" % [required,h.display_title()]
 if h.resources.carbohydrate<_cost(count):return "Need %.2f %s travel carbs" % [_cost(count),h.display_title()]
 if _state().trips_started>=WorkerLedger.MAX_COUNT or _state().moved_workers>WorkerLedger.MAX_COUNT-count or h.workers.transferred_out>WorkerLedger.MAX_COUNT-count or d.workers_total>WorkerLedger.MAX_COUNT-count or d.workers.transferred_in>WorkerLedger.MAX_COUNT-count:return "Worker transfer history or capacity is full"
 var traits: Array[String]=d.planned_trait_union()
 for profile: String in h.genetics.migration_plan(count,h.workers_total):
  for trait_id: String in GeneticRepertoire.traits_for(profile):
   if trait_id not in traits:traits.append(trait_id)
 if not AdaptationRules.compatible(traits):return "Settler traits conflict with recipient adults"
 return ""
func start(settlers: int=CONFIG.reinforcement_workers) -> bool:
 last_error=blocker(settlers)
 if not last_error.is_empty():return false
 var connection: ConnectionTrafficState=_connection()
 var h: PileState=_source();var route: TrailRouteState=_route()
 var count: int=settlers+CONFIG.reinforcement_messengers
 if not h.workers.create_commitment("trail:"+route.id,"trail",route.id):return _reject("Connection commitment unavailable")
 var allocated: bool=h.allocate_workers("trail:"+route.id,count);var paid: bool=h.consume_resources({"carbohydrate":_cost(settlers)});assert(allocated and paid)
 var state: WorkerReinforcementState=_state()
 connection.payer_id=_source_id;connection.last_cargo_kind="supplies"
 if connection.legacy:_run.supply_origin=_source_id
 route.delivered_total=connection.supplies[_source_id].delivered_total();route.receipt=connection.supplies[_source_id].receipt()
 state.settlers=settlers;state.profiles_captured=true;state.party_profiles=h.genetics.migration_plan(settlers,h.workers_total)
 state.phase="outbound";state.elapsed_ticks=0;state.departed_tick=_run.clock.tick_count;state.trips_started+=1;state.settled=false
 _sync(route);last_error="";return true
func recall() -> bool:
 var state: WorkerReinforcementState=_state()
 if not state.active():return _reject("No worker reinforcement party is away")
 if state.phase=="outbound":
  var h: PileState=_source();var d: PileState=_target()
  state.elapsed_ticks=TRAILS.leg_ticks(h.position.distance_to(d.position))-state.elapsed_ticks
  state.phase="returning"
  if state.elapsed_ticks==TRAILS.leg_ticks(h.position.distance_to(d.position)):_return_home()
 last_error="";return true
func _sync(route: TrailRouteState) -> void:
 route.allocated_workers=_state().assigned();route.active_workers=route.allocated_workers;route.desired_workers=route.allocated_workers;route.status="active" if route.allocated_workers>0 else "inactive"
func tick() -> void:
 var state: WorkerReinforcementState=_state()
 if not state.active():return
 var h: PileState=_source();var d: PileState=_target()
 state.elapsed_ticks+=1
 if state.elapsed_ticks<TRAILS.leg_ticks(h.position.distance_to(d.position)):return
 state.elapsed_ticks=0
 if state.phase=="outbound":
  _settle()
  state.phase="returning";_sync(_route())
 else:_return_home()
func _return_home() -> void:
 var state: WorkerReinforcementState=_state();var route: TrailRouteState=_route()
 var count: int=state.assigned();var ledger: WorkerLedger=_source().workers
 var released: bool=ledger.release("trail:"+route.id,count);var retired: bool=ledger.retire_commitment("trail:"+route.id);assert(released and retired)
 state.trips_reported+=1;state.last_reported_tick=_run.clock.tick_count;state.last_settled=state.settlers if state.settled else 0
 var segment: TrailSegmentState=_run.trails.segments[route.segment_id]
 segment.reinforce_chemistry(count*TRAILS.pheromone_per_returning_worker,0)
 segment.route_familiarity=minf(1.0,snappedf(segment.route_familiarity+count*TRAILS.familiarity_per_returning_worker,0.0000000001));segment.traffic+=count
 state.phase="none";state.elapsed_ticks=0;state.settled=false;state.party_profiles.clear();state.profiles_captured=false;_sync(route)
func summary(count: int=CONFIG.reinforcement_workers) -> Dictionary:
 if _connection()==null or not _connection().migrations.has(_source_id):return {}
 var state: WorkerReinforcementState=_state()
 return {"away":state.active(),"source_id":_source_id,"source_name":_source().display_title(),"destination_id":_target().id,"destination_name":_target().display_title(),"route_id":_connection().route_id,"sent":state.settlers+CONFIG.reinforcement_messengers if state.active() else 0,"settlers":state.settlers if state.active() else count,"messengers":CONFIG.reinforcement_messengers,"age":(_run.clock.tick_count-state.departed_tick)*SimulationClock.TICK_INTERVAL if state.active() else 0.0,"reports":state.trips_reported,"reported_workers":state.reported_workers(),"last_settled":state.last_settled,"report_age":(_run.clock.tick_count-state.last_reported_tick)*SimulationClock.TICK_INTERVAL if state.trips_reported>0 else 0.0,"blocker":blocker(count) if not state.active() else "","cost":_cost(count)}

func _settle() -> bool:
 var state: WorkerReinforcementState=_state();var h: PileState=_source();var d: PileState=_target()
 var previous: Dictionary=h.genetics.exported.duplicate()
 if not h.move_workers_to(d,"trail:"+_connection().route_id,state.settlers,state.party_profiles if state.profiles_captured else {}):return false
 state.settled=true;state.arrivals+=1;state.moved_workers+=state.settlers
 for profile: String in h.genetics.exported:
  var amount: int=h.genetics.exported[profile]-previous.get(profile,0)
  if amount>0:state.moved_profiles[profile]=state.moved_profiles.get(profile,0)+amount
 return true
