class_name WorkerReinforcementSystem
extends RefCounted
const CONFIG=preload("res://data/resources/default_interpile_supply.tres")
const TRAILS=preload("res://data/trails/default_trails.tres")
var _run: RunState
var last_error: String=""
func _init(run_state: RunState) -> void:_run=run_state
func _reject(reason: String) -> bool:last_error=reason;return false
func _cost() -> float:
 var h: PileState=_run.colony.piles.home;var d: PileState=_run.colony.piles.satellite_1
 var energy: float=AdaptationRules.energy_multiplier(h.adaptation_repertoire,h.adaptation_fraction())*(1.0+AdaptationRules.CHEMISTRY.extra_travel_energy*h.chemistry_fraction())
 # Settlers need one leg; the real messenger needs both.
 var equivalent: int=CONFIG.reinforcement_workers/2+CONFIG.reinforcement_messengers
 return snappedf(TRAILS.round_trip_energy_cost(equivalent,h.position.distance_to(d.position),TrailSegmentState.terrain_cost_for(_run.world,h.position,d.position))*energy,0.00001)
func blocker() -> String:
 if _run.founding.phase!="established" or not _run.colony.piles.has("satellite_1"):return "Establish Daughter first"
 if _run.reinforcement.active():return "A worker reinforcement party is already away"
 if _run.supply.phase!="none" or _run.daughter_supply.phase!="none":return "Stop supplies; await their return"
 var h: PileState=_run.colony.piles.home;var d: PileState=_run.colony.piles.satellite_1
 var required: int=CONFIG.reinforcement_workers+CONFIG.reinforcement_messengers
 if h.workers_assignable<required:return "Need %d available Home workers" % required
 if h.resources.carbohydrate<_cost():return "Need %.2f Home travel carbs" % _cost()
 if _run.reinforcement.trips_started>=WorkerLedger.MAX_COUNT or h.workers.transferred_out>WorkerLedger.MAX_COUNT-CONFIG.reinforcement_workers or d.workers_total>WorkerLedger.MAX_COUNT-CONFIG.reinforcement_workers or d.workers.transferred_in>WorkerLedger.MAX_COUNT-CONFIG.reinforcement_workers:return "Worker transfer history or capacity is full"
 var traits: Array[String]=d.genetics.established.duplicate()
 for profile: String in h.genetics.migration_plan(CONFIG.reinforcement_workers,h.workers_total):
  for trait_id: String in GeneticRepertoire.traits_for(profile):
   if trait_id not in traits:traits.append(trait_id)
 if not AdaptationRules.compatible(traits):return "Settler traits conflict with Daughter adults"
 return ""
func start() -> bool:
 last_error=blocker()
 if not last_error.is_empty():return false
 _run.supply_origin="home"
 var connection: TrailRouteState=_run.trails.routes[_run.founding.route_id]
 connection.delivered_total=_run.supply.delivered_total();connection.receipt=_run.supply.receipt()
 var h: PileState=_run.colony.piles.home;var route: TrailRouteState=_run.trails.routes[_run.founding.route_id]
 var count: int=CONFIG.reinforcement_workers+CONFIG.reinforcement_messengers
 if not h.workers.create_commitment("trail:"+route.id,"trail",route.id):return _reject("Connection commitment unavailable")
 var allocated: bool=h.allocate_workers("trail:"+route.id,count);var paid: bool=h.consume_resources({"carbohydrate":_cost()});assert(allocated and paid)
 var state: WorkerReinforcementState=_run.reinforcement
 state.phase="outbound";state.elapsed_ticks=0;state.departed_tick=_run.clock.tick_count;state.trips_started+=1;state.settled=false
 _sync(route);last_error="";return true
func recall() -> bool:
 var state: WorkerReinforcementState=_run.reinforcement
 if not state.active():return _reject("No worker reinforcement party is away")
 if state.phase=="outbound":
  var h: PileState=_run.colony.piles.home;var d: PileState=_run.colony.piles.satellite_1
  state.elapsed_ticks=TRAILS.leg_ticks(h.position.distance_to(d.position))-state.elapsed_ticks
  state.phase="returning"
  if state.elapsed_ticks==TRAILS.leg_ticks(h.position.distance_to(d.position)):_return_home()
 last_error="";return true
func _sync(route: TrailRouteState) -> void:
 route.allocated_workers=_run.reinforcement.assigned();route.active_workers=route.allocated_workers;route.desired_workers=route.allocated_workers;route.status="active" if route.allocated_workers>0 else "inactive"
func tick() -> void:
 var state: WorkerReinforcementState=_run.reinforcement
 if not state.active():return
 var h: PileState=_run.colony.piles.home;var d: PileState=_run.colony.piles.satellite_1
 state.elapsed_ticks+=1
 if state.elapsed_ticks<TRAILS.leg_ticks(h.position.distance_to(d.position)):return
 state.elapsed_ticks=0
 if state.phase=="outbound":
  var previous: Dictionary=h.genetics.exported.duplicate()
  if h.move_workers_to(d,"trail:"+_run.founding.route_id,CONFIG.reinforcement_workers):
   state.settled=true;state.arrivals+=1
   for profile: String in h.genetics.exported:
    var amount: int=h.genetics.exported[profile]-previous.get(profile,0)
    if amount>0:state.moved_profiles[profile]=state.moved_profiles.get(profile,0)+amount
  state.phase="returning";_sync(_run.trails.routes[_run.founding.route_id])
 else:_return_home()
func _return_home() -> void:
 var state: WorkerReinforcementState=_run.reinforcement;var route: TrailRouteState=_run.trails.routes[_run.founding.route_id]
 var count: int=state.assigned();var ledger: WorkerLedger=_run.colony.piles.home.workers
 var released: bool=ledger.release("trail:"+route.id,count);var retired: bool=ledger.retire_commitment("trail:"+route.id);assert(released and retired)
 state.trips_reported+=1;state.last_reported_tick=_run.clock.tick_count;state.last_settled=CONFIG.reinforcement_workers if state.settled else 0
 var segment: TrailSegmentState=_run.trails.segments[route.segment_id]
 segment.reinforce_chemistry(count*TRAILS.pheromone_per_returning_worker,0)
 segment.route_familiarity=minf(1.0,snappedf(segment.route_familiarity+count*TRAILS.familiarity_per_returning_worker,0.0000000001));segment.traffic+=count
 state.phase="none";state.elapsed_ticks=0;state.settled=false;_sync(route)
func summary() -> Dictionary:
 if _run.founding.phase!="established":return {}
 var state: WorkerReinforcementState=_run.reinforcement
 return {"away":state.active(),"sent":CONFIG.reinforcement_workers+CONFIG.reinforcement_messengers if state.active() else 0,"settlers":CONFIG.reinforcement_workers,"messengers":CONFIG.reinforcement_messengers,"age":(_run.clock.tick_count-state.departed_tick)*SimulationClock.TICK_INTERVAL if state.active() else 0.0,"reports":state.trips_reported,"reported_workers":state.reported_arrivals()*CONFIG.reinforcement_workers,"last_settled":state.last_settled,"report_age":(_run.clock.tick_count-state.last_reported_tick)*SimulationClock.TICK_INTERVAL if state.trips_reported>0 else 0.0,"blocker":blocker() if not state.active() else "","cost":_cost()}
