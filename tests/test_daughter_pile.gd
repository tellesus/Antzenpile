extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Founding=preload("res://tests/test_founding.gd")
const Root=preload("res://src/core/game_root.gd")
const SITE=Founding.SITE
func fixture() -> SimulationController:
 var game: SimulationController=Founding.new().fixture()
 game.start_founding(SITE)
 for tick: int in 2000:
  game.advance(0.25)
  if game.run.founding.phase=="ready": break
 return game
func exact(game: SimulationController, ticks: int) -> bool:
 var copy:=Controller.new()
 if not copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict()))): return false
 for tick: int in ticks:
  game.advance(0.25); copy.advance(0.25)
 return game.run.to_dict()==copy.run.to_dict()
func run(test: Object) -> bool:
 var game:=fixture(); var parent: PileState=game.run.colony.piles.home
 var before: Dictionary=game.run.to_dict()
 test.check(not game.establish_daughter("missing") and game.run.to_dict()==before,"Unknown camp activation is atomic")
 var count: int=game.run.colony.workers_total; var available: int=parent.workers_available; var lost: int=parent.workers.lost_total
 test.check(game.establish_daughter(SITE),"Returned paid camp can establish daughter")
 var daughter: PileState=game.run.colony.piles.satellite_1
 test.check(game.run.colony.workers_total==count and parent.workers_available==available and daughter.workers_total==11 and daughter.workers_available==11,"Eleven existing settlers transfer ownership without duplication or releasing Home labor")
 test.check(parent.workers.lost_total==lost and daughter.workers.lost_total==0 and parent.workers.transferred_out==11 and daughter.workers.transferred_in==11,"Migration creates no deaths and records both ledgers")
 test.check(daughter.queen_count==1 and parent.queen_count==1 and daughter.brood_cohorts.is_empty() and daughter.brood_started_total==0,"Paid daughter queen begins with no invented brood")
 test.check(daughter.resources=={ "carbohydrate":6.0,"protein":3.0,"water":3.0},"Daughter receives the actual founding pack")
 test.check(game.run.founding.phase=="established" and game.run.trails.routes[game.run.founding.route_id].purpose=="interpile" and parent.workers.count("trail:"+game.run.founding.route_id)==-1,"Camp commitment retires into an inactive interpile connection")
 before=game.run.to_dict()
 test.check(not game.establish_daughter(SITE) and not game.start_founding(SITE) and game.run.to_dict()==before,"Duplicate activation/founding cannot create queens, workers or resources")
 test.check(exact(game,40),"Empty daughter save restores and continues exactly through JSON")
 test.check(game.start_brood("satellite_1") and parent.brood_cohorts.is_empty(),"Daughter lays its own local worker cohort")
 test.check(exact(game,1200),"Daughter eggs and food-limited larvae restore and continue exactly")
 test.check(daughter.brood_cohorts[0].stage=="larva" and not daughter.brood_cohorts[0].nutrition_shortfalls.is_empty() and daughter.brood_matured_total==0,"Carried food is spent locally; unfed brood stalls rather than creates workers")
 test.check(not game.queue_adaptation("satellite_1","lean") and not game.start_reproduction("satellite_1"),"Simplified daughter cannot select an unimplemented lineage or reproductive generation")
 for gate: String in ["incoming","profile","foundation","clock","lineage","route","orphan"]:
  var forged: Dictionary=game.run.to_dict()
  match gate:
   "incoming": forged.colony.piles[1].workers.transferred_in=12
   "profile": forged.colony.piles[1].genetics.imported={"":10}
   "foundation": forged.colony.piles[1].foundation.route_id="route_999"
   "clock": forged.colony.piles[1].foundation.founded_tick=game.run.clock.tick_count+1
   "lineage": forged.colony.piles[1].foundation.queen_traits=["lean"]
   "route": forged.trails.routes[0].purpose="founding"
   "orphan": forged.colony.piles[1].erase("foundation")
  var copy:=Controller.new(); var unchanged: Dictionary=copy.run.to_dict()
  test.check(not copy.restore_snapshot(forged) and copy.run.to_dict()==unchanged,"Malformed daughter "+gate+" rejects atomically")
 var genetic:=Founding.new().fixture(); var home: PileState=genetic.run.colony.piles.home
 test.check(genetic.start_adaptation("home","lean"),"Parent can establish a trait after its reproductive group was laid")
 for tick: int in 4000:
  genetic.advance(0.25)
  if home.trial_cohort()==null: break
 test.check(home.genetics.established==["lean"] and home.reproduction.inherited_traits.is_empty(),"Ready young queen retains earlier baseline lineage")
 genetic.start_founding(SITE)
 for tick: int in 2000:
  genetic.advance(0.25)
  if genetic.run.founding.phase=="ready": break
 var expressed: int=home.adapted_workers_total; var genetic_losses: int=home.adapted_workers_lost
 test.check(genetic.establish_daughter(SITE),"Mixed phenotype settlers can establish a daughter")
 var child: PileState=genetic.run.colony.piles.satellite_1
 test.check(child.adapted_workers_total>0 and child.adapted_workers_total+home.adapted_workers_total==expressed and home.adapted_workers_lost==genetic_losses and child.adapted_workers_lost==0,"Partial phenotype transfer conserves expressed adults without counting death")
 test.check(child.offspring_traits().is_empty() and genetic.start_brood("satellite_1") and child.brood_cohorts[0].inherited_traits.is_empty(),"Arriving adapted workers do not rewrite the founder queen's offspring")
 test.check(exact(genetic,40),"Distinct founder lineage and mixed adult profiles round-trip exactly")
 var root:=Root.new(); root.simulation=game
 var frozen: Dictionary=game.run.to_dict()
 test.check(root.inspect_pile("satellite_1") and root.focused_inward_status().resources==daughter.resources and root.focused_inward_status().workers_total==11 and root.focused_inward_status().daughter,"Daughter inspection exposes detached local counts and stores")
 test.check(root.inspect_pile("home") and game.run.to_dict()==frozen and not root.inspect_pile("missing"),"Pile attention changes no simulation and unknown selection rejects")
 root.free()
 var from:=WorkerLedger.new(); var to:=WorkerLedger.new()
 from.add_living_workers("available",20,"fixture"); from.create_commitment("camp","trail","route_1"); from.allocate("camp",12)
 for args: Array in [[from,"camp","available",1],[to,"camp","missing",1],[to,"camp","available",13],[to,"camp","available",1.5]]:
  var a: Dictionary=from.to_dict(); var b: Dictionary=to.to_dict()
  test.check(not from.move_to(args[0],args[1],args[2],args[3],"migration") and from.to_dict()==a and to.to_dict()==b,"Invalid cross-ledger transfer is atomic")
 test.check(from.move_to(to,"camp","available",11,"migration") and from.total+to.total==20 and from.lost_total+to.lost_total==0 and from.invariant_holds() and to.invariant_holds(),"Ledger transfer conserves real workers across known pools")
 var mixed:=GeneticRepertoire.new(); mixed.established=["lean","persistent"]; mixed.living={"lean":8,"lean+persistent":8}
 var receiver:=GeneticRepertoire.new(); receiver.established=mixed.established.duplicate()
 var plan: Dictionary[String,int]=mixed.migration_plan(11,64)
 mixed.move_profiles_to(receiver,plan)
 test.check(mixed.count_profiles()+receiver.count_profiles()==16 and mixed.count_trait("lean")+receiver.count_trait("lean")==16 and mixed.count_trait("persistent")+receiver.count_trait("persistent")==8,"Overlapping trait bundles transfer disjoint adults and preserve each trait")
 var restored:=GeneticRepertoire.new()
 test.check(restored.restore(JSON.parse_string(JSON.stringify(mixed.to_dict())),53,0,16) and restored.restore(JSON.parse_string(JSON.stringify(receiver.to_dict())),11,0,0),"Imported expressions need no invented local births")
 var upper:=WorkerLedger.new(); upper.add_living_workers("available",WorkerLedger.MAX_COUNT,"fixture")
 before=from.to_dict(); var unchanged: Dictionary=upper.to_dict()
 test.check(not from.move_to(upper,"available","available",1,"migration") and before==from.to_dict() and unchanged==upper.to_dict(),"Overflowing destination transfer rejects both ledgers atomically")
 var old:=Controller.new(); var saved: Dictionary=old.run.to_dict()
 test.check(not saved.colony.piles[0].workers.has("transferred_in") and not saved.colony.piles[0].genetics.has("imported") and old.restore_snapshot(JSON.parse_string(JSON.stringify(saved))),"Old one-pile saves retain zero-default migration fields")
 return true
