extends RefCounted
const Supply=preload("res://tests/test_parent_supply.gd")
const Founding=preload("res://tests/test_founding.gd")
const Root=preload("res://src/core/game_root.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
func fixture() -> SimulationController:return Supply.new().fixture()
func exact(game: SimulationController, ticks: int) -> bool:
 var copy:=Controller.new()
 if not copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))):return false
 var ok: bool=true
 for tick: int in ticks:
  game.advance(0.25);copy.advance(0.25);ok=ok and game.run.to_dict()==copy.run.to_dict()
 return ok
func run(test: Object) -> bool:
 var game:=fixture();var h: PileState=game.run.colony.piles.home;var d: PileState=game.run.colony.piles.satellite_1
 var route: TrailRouteState=game.run.trails.routes[game.run.founding.route_id]
 var leg: int=game.reinforcement.TRAILS.leg_ticks(h.position.distance_to(d.position))
 var total: int=game.run.colony.workers_total;var available: int=h.workers_available;var home_total: int=h.workers_total;var daughter_total: int=d.workers_total
 var food: float=h.resources.carbohydrate;var cost: float=game.reinforcement.summary().cost
 var frozen: Dictionary=game.run.to_dict()
 test.check(not game.recall_daughter_workers() and game.run.to_dict()==frozen,"Idle worker return request is atomic")
 test.check(game.send_daughter_workers() and h.workers_available==available-9 and h.workers_total==home_total and d.workers_total==daughter_total and game.run.colony.workers_total==total,"Nine real Home workers depart; no dispatch ownership transfer or population creation")
 test.check(is_equal_approx(h.resources.carbohydrate,snappedf(food-cost,0.00001)) and route.allocated_workers==9 and route.active_workers==9,"Travel food paid immediately and the same connection owns nine travelers")
 frozen=game.run.to_dict()
 test.check(not game.send_daughter_workers() and not game.set_daughter_supply(true) and frozen==game.run.to_dict(),"No duplicate or supply overlap while reinforcement is away")
 game.toggle_pause();frozen=game.run.to_dict();game.advance(20)
 test.check(frozen==game.run.to_dict(),"Paused migration does not travel, transfer or report")
 game.toggle_pause()
 test.check(exact(game,leg-1) and d.workers_total==daughter_total and game.run.reinforcement.arrivals==0,"Every outbound tick continues exactly, with no premature workers")
 game.advance(0.25)
 test.check(d.workers_total==daughter_total+8 and h.workers_total==home_total-8 and h.workers_available==available-9 and game.run.colony.workers_total==total,"Eight physically arrived workers transfer via ledgers; the Home messenger remains committed")
 test.check(h.workers.transferred_out==19 and d.workers.transferred_in==19 and route.active_workers==1 and h.workers.lost_total==0 and d.workers.lost_total==0,"Arrival records migration, not death, with exactly one returning messenger")
 var root:=Root.new();root.simulation=game
 var projected_route: Dictionary=root.trail_summaries("home")[0]
 test.check(projected_route.active_workers==9 and projected_route.allocated_workers==9 and projected_route.desired_workers==9 and game.supply.summary().blocker.contains("away"),"OUTWARD representatives retain known dispatched labor; supplies show shared-route waiting")
 root.free()
 var projected: Dictionary=game.reinforcement.summary()
 test.check(projected.away and projected.sent==9 and projected.reported_workers==0 and projected.reports==0 and not projected.has("settled") and not projected.has("phase") and not projected.has("moved_profiles"),"Known expedition status withholds physical arrival, direction and trait history")
 frozen=game.run.to_dict()
 test.check(game.recall_daughter_workers() and game.run.to_dict()==frozen,"Return request after settling cannot repatriate workers or accelerate messenger")
 test.check(exact(game,leg) and h.workers_available==available-8 and route.status=="inactive" and route.allocated_workers==0,"Messenger returns physically, releases once and leaves settlers at Daughter")
 test.check(game.reinforcement.summary().reported_workers==8 and game.run.reinforcement.last_settled==8 and game.run.reinforcement.trips_reported==1 and route.receipt.is_empty() and route.delivered_total==0,"Only messenger return confirms worker arrival, without inventing supply receipts")
 test.check(game.send_daughter_workers() and exact(game,2*leg) and h.workers.transferred_out==27 and d.workers.transferred_in==27 and game.reinforcement.summary().reported_workers==16,"Repeated real migration accumulates exact independent histories")
 test.check(game.set_daughter_supply(true),"Completed reinforcement leaves the physical connection available for supplies")
 game.advance(0.25);game.set_daughter_supply(false)
 test.check(exact(game,2*leg) and game.run.supply.trips_reported==1 and route.delivered_total>0 and game.run.reinforcement.arrivals==2,"Supply can reuse the same route and report resources independently")
 var receipt: Dictionary=route.receipt.duplicate(true);var deliveries: float=route.delivered_total
 test.check(game.send_daughter_workers() and exact(game,2*leg) and route.receipt==receipt and route.delivered_total==deliveries,"Later migration preserves actual supply delivery receipt/history")
 var saved: Dictionary=game.run.to_dict()
 for gate: String in ["orphan","moves","profile","arrival","report","time","route","type"]:
  var bad: Dictionary=saved.duplicate(true)
  match gate:
   "orphan":bad.erase("reinforcement")
   "moves":bad.reinforcement.moved_profiles[""]+=1
   "profile":bad.reinforcement.moved_profiles={"unknown":24}
   "arrival":bad.reinforcement.arrivals+=1
   "report":bad.reinforcement.trips_reported+=1
   "time":bad.reinforcement.last_reported_tick=bad.reinforcement.departed_tick
   "route":bad.trails.routes[0].active_workers=9
   "type":bad.reinforcement.settled="yes"
  var copy:=Controller.new();frozen=copy.run.to_dict()
  test.check(not copy.restore_snapshot(bad) and copy.run.to_dict()==frozen,"Forged reinforcement "+gate+" rejects atomically")
 var recalled:=fixture();h=recalled.run.colony.piles.home;d=recalled.run.colony.piles.satellite_1;available=h.workers_available
 recalled.send_daughter_workers();recalled.advance(0.25*7)
 test.check(recalled.recall_daughter_workers() and h.workers_available==available-9,"Partial outbound recall retains real workers until return")
 test.check(exact(recalled,6) and h.workers_available==available-9,"Recalled trip cannot teleport home")
 test.check(exact(recalled,1) and h.workers_available==available and d.workers_total==11 and recalled.run.reinforcement.arrivals==0 and recalled.run.reinforcement.last_settled==0,"Partial physical return creates no migrants; report says zero settled")
 test.check(recalled.send_daughter_workers() and recalled.recall_daughter_workers() and exact(recalled,0) and h.workers_available==available,"Immediate departure recall at Home releases exactly once and saves")
 for gate: String in ["labor","food","unfounded","supplies"]:
  var blocked:=Controller.new() if gate=="unfounded" else fixture()
  h=blocked.run.colony.piles.home
  match gate:
   "labor":h.workers.create_commitment("test:busy","internal","home");h.workers.allocate("test:busy",h.workers_available-8)
   "food":h.resources.carbohydrate=0
   "supplies":blocked.set_daughter_supply(true)
  frozen=blocked.run.to_dict()
  test.check(not blocked.send_daughter_workers() and blocked.run.to_dict()==frozen,"Unfunded reinforcement "+gate+" rejects atomically")
 var legacy:=fixture();saved=legacy.run.to_dict();saved.erase("reinforcement")
 test.check(legacy.restore_snapshot(saved) and legacy.run.reinforcement.trips_started==0,"Legacy eleven-settler daughter defaults to no invented transfers")
 var genetic:=Founding.new().fixture();h=genetic.run.colony.piles.home;genetic.start_adaptation("home","lean")
 for tick: int in 4000:
  genetic.advance(0.25)
  if h.trial_cohort()==null:break
 genetic.run.rain.phase="raining";h.rain_trace_observed=true;h.chemistry_candidate=true;h.genetics.established.append("persistent");h.genetics.living["lean+persistent"]=h.genetics.living.lean;h.genetics.living.erase("lean")
 genetic.start_founding(Founding.SITE)
 for tick: int in 2000:
  genetic.advance(0.25)
  if genetic.run.founding.phase=="ready":break
 genetic.establish_daughter(Founding.SITE);d=genetic.run.colony.piles.satellite_1
 var expressed: int=h.adapted_workers_total+d.adapted_workers_total
 var imported: Dictionary=d.genetics.imported.duplicate()
 test.check(genetic.send_daughter_workers() and exact(genetic,2*leg) and genetic.send_daughter_workers() and exact(genetic,2*leg),"Mixed-phenotype reinforcement saves and travels exactly")
 test.check(genetic.run.reinforcement.moved_profiles.get("lean+persistent",0)>0 and h.adapted_workers_total+d.adapted_workers_total==expressed and h.genetics.exported==d.genetics.imported and d.genetics.imported!=imported,"Actual overlapping migrant traits conserve across both piles")
 test.check(d.offspring_traits().is_empty() and genetic.start_brood(d.id) and d.brood_cohorts[0].inherited_traits.is_empty(),"Adult reinforcement cannot rewrite the captured baseline daughter queen")
 var newly:=fixture();h=newly.run.colony.piles.home;d=newly.run.colony.piles.satellite_1
 newly.run.rain.phase="raining";h.rain_trace_observed=true;h.chemistry_candidate=true
 test.check(newly.start_adaptation("home","persistent"),"Home can gain a paid trait after Daughter was founded")
 for tick: int in 4000:
  newly.advance(0.25)
  if h.trial_cohort()==null:break
 test.check(not d.chemistry_candidate and newly.send_daughter_workers() and exact(newly,2*leg) and newly.send_daughter_workers() and exact(newly,2*leg),"Newly expressed Home adults migrate without invalidating Daughter saves")
 test.check("persistent" in d.genetics.established and d.chemistry_candidate and d.rain_trace_observed and d.offspring_traits().is_empty(),"Actual arriving traits retain earned prerequisites, but keep baseline daughter offspring")
 for speed: int in [1,4,16,64]:
  var timed:=fixture();timed.send_daughter_workers();timed.set_time_scale(speed);timed.advance(20.0/speed)
  var reference:=fixture();reference.send_daughter_workers();reference.advance(20)
  var snapshot: Dictionary=timed.run.to_dict();snapshot.clock.scale=1
  test.check(snapshot==reference.run.to_dict(),"Reinforcement is fixed-tick equivalent at %dx" % speed)
 return true
