extends RefCounted
const Daughter=preload("res://tests/test_daughter_pile.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func fixture() -> SimulationController:
 var game: SimulationController=Daughter.new().fixture();game.establish_daughter(Daughter.SITE);return game
func exact(game: SimulationController, ticks: int=40) -> bool:
 var copy:=Controller.new()
 if not copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict()))): return false
 for tick: int in ticks: game.advance(0.25);copy.advance(0.25)
 return game.run.to_dict()==copy.run.to_dict()
func run(test: Object) -> bool:
 var game:=fixture();var home: PileState=game.run.colony.piles.home;var daughter: PileState=game.run.colony.piles.satellite_1
 var route: TrailRouteState=game.run.trails.routes[game.run.founding.route_id]
 var count: int=game.run.colony.workers_total;var available: int=home.workers_available
 var supplies: Dictionary=daughter.resources.duplicate()
 var original: Dictionary=game.run.to_dict()
 test.check(not game.set_daughter_supply("yes") and original==game.run.to_dict(),"Malformed supply intent rejects atomically")
 test.check(game.set_daughter_supply(true) and home.workers_available==available-8 and route.allocated_workers==8 and route.active_workers==0 and game.run.colony.workers_total==count,"Supply order reserves eight real Home workers, with no migration or instant travel")
 test.check(game.run.supply.phase=="waiting" and daughter.resources==supplies,"Ordering supplies creates no destination resources")
 original=game.run.to_dict()
 test.check(not game.set_daughter_supply(true) and original==game.run.to_dict(),"Duplicate supply assignment is atomic")
 test.check(exact(game,0),"Waiting supply commitment saves exactly")
 var costs: Dictionary=game.supply._plan().costs.duplicate();var stores: Dictionary=home.resources.duplicate()
 game.advance(0.25)
 test.check(game.run.supply.phase=="outbound" and daughter.resources==supplies and home.resources.carbohydrate==snappedf(stores.carbohydrate-costs.carbohydrate,0.00001) and home.resources.protein==stores.protein-costs.protein,"Departure debits cargo and round-trip travel food before delivery")
 var leg: int=game.supply.TRAILS.leg_ticks(home.position.distance_to(daughter.position))
 test.check(exact(game,leg-1) and daughter.resources==supplies,"Outbound cargo stays in transit and continues exactly")
 game.advance(0.25)
 test.check(game.run.supply.phase=="returning" and daughter.resources.carbohydrate==supplies.carbohydrate+4 and route.delivered_total==0 and game.run.supply.trips_reported==0,"Only actual daughter arrival deposits; Home has no report yet")
 test.check(game.supply.summary().status=="away" and not game.supply.summary().has("phase") and not game.supply.summary().has("elapsed_ticks"),"Home summary hides private arrival and return direction")
 test.check(game.set_daughter_supply(false) and home.workers_available==available-8 and route.status=="recalling","Stop After Trip retains workers until actual return")
 test.check(exact(game,leg) and home.workers_available==available and game.run.supply.phase=="none" and route.status=="inactive" and route.delivered_total==8 and game.run.supply.trips_reported==1,"Actual return reports delivery, reinforces shared segment and releases once")
 test.check(game.run.colony.workers_total==count and home.workers.transferred_out==11 and daughter.workers.transferred_in==11,"Supply workers remain Home's; no migration or new population")
 test.check(exact(game,40),"Completed supply history and route receipt continue exactly")
 var saved: Dictionary=game.run.to_dict()
 for gate: String in ["cargo","trips","history","phase","receipt","orphan"]:
  var bad: Dictionary=saved.duplicate(true)
  match gate:
   "cargo": bad.supply.cargo={"carbohydrate":4,"protein":2,"water":2}
   "trips": bad.supply.trips_started=2
   "history": bad.supply.delivered_units.protein+=1
   "phase": bad.supply.phase="waiting"
   "receipt": bad.trails.routes[0].delivered_total=16
   "orphan": bad.erase("supply")
  var copy:=Controller.new();var unchanged: Dictionary=copy.run.to_dict()
  test.check(not copy.restore_snapshot(bad) and copy.run.to_dict()==unchanged,"Forged supply "+gate+" rejects atomically")
 var poor:=fixture();var p: PileState=poor.run.colony.piles.home;p.resources.water=0
 poor.set_daughter_supply(true);poor.advance(20)
 test.check(poor.run.supply.phase=="waiting" and poor.run.supply.trips_started==0 and poor.supply.summary().blocker.contains("water"),"Insufficient Home water pauses departure with a known shortage")
 test.check(exact(poor,40) and poor.set_daughter_supply(false) and poor.run.supply.phase=="none","Stopped unfunded party releases idle workers and saves exactly")
 var unfounded:=Controller.new();original=unfounded.run.to_dict()
 test.check(not unfounded.set_daughter_supply(true) and unfounded.run.to_dict()==original,"Supply requires a physically established daughter")
 var growing:=fixture();growing.start_brood("satellite_1");growing.set_daughter_supply(true)
 test.check(exact(growing,2000),"Repeated supplies, local feeding, emergence and parent simulation continue exactly")
 test.check(growing.run.colony.piles.satellite_1.brood_matured_total==8 and growing.run.supply.trips_reported>1 and growing.run.colony.workers_total==growing.run.colony.piles.home.workers_total+19,"Real transported supplies support first local daughter emergence")
 var expected: Dictionary={}
 for speed: int in [1,4,16,64]:
  var timed:=fixture();timed.set_daughter_supply(true);timed.set_time_scale(speed);timed.advance(200.0/speed)
  var snapshot: Dictionary=timed.run.to_dict();snapshot.clock.scale=1
  if expected.is_empty(): expected=snapshot
  test.check(expected==snapshot,"Supply order gives equal simulated result at %dx" % speed)
  timed.toggle_pause();snapshot=timed.run.to_dict();timed.advance(10)
  test.check(snapshot==timed.run.to_dict(),"Paused supply cannot travel, deliver or release")
 var old:=fixture();saved=old.run.to_dict();saved.erase("supply")
 test.check(old.restore_snapshot(saved) and old.run.supply.phase=="none","Card 105 daughter saves default to no invented supply workers")
 var tainted:=fixture();var source: PileState=tainted.run.colony.piles.home;var target: PileState=tainted.run.colony.piles.satellite_1
 source.food_toxicity.mass=100.0
 var concentration: float=100.0/source.resources.carbohydrate
 var plan: Dictionary=tainted.supply._plan();var energy: float=plan.costs.carbohydrate-plan.cargo.carbohydrate
 tainted.set_daughter_supply(true);tainted.supply.tick()
 var carried: float=tainted.run.supply.contaminant_mass
 test.check(is_equal_approx(carried,4.0*concentration) and is_equal_approx(source.food_toxicity.mass+carried,100.0-energy*concentration),"Cargo captures its contamination; travel food consumes only its separate share")
 for tick: int in leg: tainted.supply.tick()
 var received: float=target.food_toxicity.mass;var cargo_stores: Dictionary=target.resources.duplicate()
 for tick: int in leg: tainted.supply.tick()
 test.check(is_equal_approx(received,carried) and target.food_toxicity.mass==received and target.resources==cargo_stores and tainted.run.supply.cargo.is_empty(),"Contamination and cargo deposit once, never again at Home report")
 var traits:=fixture();var adult: PileState=traits.run.colony.piles.home
 adult.genetics.established=["load","persistent"];adult.genetics.living={"load+persistent":8};adult.adaptation_repertoire="load";adult.adapted_workers_total=8
 plan=traits.supply._plan()
 var fraction: float=8.0/adult.workers_total
 test.check(is_equal_approx(plan.carry,snappedf(1.0+0.3*fraction,0.00001)) and is_equal_approx(plan.energy,snappedf(1.0+0.2*fraction,0.00001)) and plan.chemistry>0 and plan.cargo.carbohydrate>4,"Carry, travel energy and persistent chemistry are captured from actual parent expression")
 traits.set_daughter_supply(true);traits.advance(0.25)
 var private: Dictionary=traits.supply.summary();traits.run.supply.phase="returning"
 test.check(private==traits.supply.summary(),"Identical known facts project identically across private outward/returning phases")
 var labour:=fixture();var h: PileState=labour.run.colony.piles.home
 h.workers.create_commitment("test:busy","internal","home");h.workers.allocate("test:busy",h.workers_available-7)
 original=labour.run.to_dict()
 test.check(not labour.set_daughter_supply(true) and labour.run.to_dict()==original,"Seven available workers cannot fund an eight-worker supply assignment")
 return true
