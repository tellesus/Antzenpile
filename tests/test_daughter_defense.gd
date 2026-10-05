extends RefCounted
const Survey=preload("res://tests/test_daughter_journey_surveys.gd")
const Parent=preload("res://tests/test_parent_supply.gd")
const Founding=preload("res://tests/test_founding.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const View=preload("res://src/presentation/outward/outward_view.gd")
func fixture(genetic: bool=false) -> SimulationController:
 var game: SimulationController
 if genetic:
  game=Founding.new().fixture();game.start_adaptation("home","load");game.advance(360)
  game.start_founding(Founding.SITE)
  for tick: int in 2000:
   game.advance(0.25)
   if game.run.founding.phase=="ready":break
  game.establish_daughter(Founding.SITE)
  game=Survey.new().fixture(game)
 else:game=Survey.new().fixture()
 game.set_daughter_supply(true);game.start_brood("satellite_1")
 for tick: int in 3000:
  game.advance(0.25)
  if game.run.colony.piles.satellite_1.brood_matured_total==8:break
 game.set_daughter_supply(false)
 while game.run.supply.phase!="none":game.advance(0.25)
 var route: TrailRouteState=game.run.trails.find_route("satellite_1","known:carb_exposed")
 game.journey_response.investigate(route.id)
 while game.run.journey_response.active():game.advance(0.25)
 return game
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict()))
func run(test: Object) -> bool:
 var game:=fixture();var root:=Root.new();root.simulation=game;root.inward_pile_id="satellite_1"
 var d: PileState=game.run.colony.piles.satellite_1;var h: PileState=game.run.colony.piles.home
 var route: TrailRouteState=game.run.trails.find_route(d.id,"known:carb_exposed")
 test.check(d.brood_matured_total==8 and Parent.new().exact(game,0),"Paid local emergence supplies real daughter defensive capacity")
 var saved_food: float=d.resources.carbohydrate;d.resources.carbohydrate=0
 var rejected: Dictionary=game.run.to_dict()
 test.check(not root.respond_to_journey("defend",route.id).accepted and rejected==game.run.to_dict(),"Local defensive food shortage cannot borrow Home stores")
 d.resources.carbohydrate=saved_food
 var initial: Dictionary=snapshot(game);var local: int=d.workers_available;var stores: Dictionary=d.resources.duplicate();var parent: Dictionary=h.workers.to_dict()
 test.check(root.respond_to_journey("defend",route.id).accepted and d.workers_available==local-12 and d.resources.carbohydrate<stores.carbohydrate and h.workers.to_dict()==parent,"Daughter mobilization funds twelve local workers/food without borrowing Home")
 game.advance(5);var party: JourneyResponseState=game.run.journey_response;var fighters: int=party.workers
 test.check(root.respond_to_journey("reinforce",route.id).accepted and party.workers==fighters and party.defense.extra_workers==4 and d.workers.count("journey:satellite_1")==16,"Local paid reinforcement stays separate until actual travel meeting")
 var before: Dictionary=game.run.to_dict();root.inward_pile_id="home"
 test.check(not root.respond_to_journey("reinforce",route.id).accepted and not root.respond_to_journey("recall",route.id).accepted and game.run.to_dict()==before,"Other-origin defensive controls cannot alter daughter commitment")
 root.inward_pile_id=d.id
 test.check(not root.respond_to_journey("reinforce",route.id).accepted and before==game.run.to_dict(),"Duplicate reinforcement batch rejects atomically")
 var copy:=Controller.new();test.check(copy.restore_snapshot(snapshot(game)),"Local outbound party and reinforcement restore")
 var expected: int=root.inward_status(d.id).workers_total;var checkpoints: Array[Dictionary]=[snapshot(game)];var private_loss: bool=false
 while party.active():
  game.advance(0.25);copy.advance(0.25)
  if party.active():
   test.check(root.inward_status(d.id).workers_total==expected and root.outward_status(d.id).journey_response.workers==16 and root.outward_status(d.id).journey_response.outcomes.is_empty(),"Private daughter deaths and outcome preserve expected local adults/sent count")
   if party.defense.lost>0 and not private_loss:private_loss=true;checkpoints.append(snapshot(game))
 test.check(game.run.to_dict()==copy.run.to_dict() and Parent.new().exact(game,0),"Exact local combat, return and complete casualty history reconcile")
 test.check(party.defense.outcomes[route.id].outcome=="secured" and d.workers_available==local-party.defense.reported_for_pile(d.id) and h.workers.to_dict()==parent,"Returned daughter survivors deliver success and release real local labor")
 test.check(party.defense.reported_for_pile("home")==0 and party.defense.reported_for_pile(d.id)==game.run.predator.defense_losses and root.inward_status(d.id).workers_total==d.workers_total,"Lifetime daughter defensive deaths belong only to local population/history")
 before=game.run.to_dict()
 test.check(not root.respond_to_journey("defend",route.id).accepted and before==game.run.to_dict(),"Delivered victory prevents another pointless local swarm")
 checkpoints.append(snapshot(game))
 for saved: Dictionary in checkpoints:
  test.check(copy.restore_snapshot(saved) and Parent.new().exact(copy,400),"Private casualty and completed local defense save exactly")
 var receipt: float=route.delivered_total;var killed: int=game.run.predator.kills_total
 game.set_trail_workers(route.id,5);game.advance(180)
 test.check(route.delivered_total>receipt and game.run.predator.kills_total==killed,"Daughter harvest resumes physically after delivered intervention without ambush kills")
 for gate: String in ["history","legacy","owner","zero","total"]:
  var bad: Dictionary=checkpoints[-1].duplicate(true)
  match gate:
   "history":bad.journey_response.defense.reported_by_pile={"home":bad.journey_response.defense.reported_losses}
   "legacy":bad.journey_response.defense.erase("reported_by_pile")
   "owner":bad.journey_response.defense.reported_by_pile={"missing":1}
   "zero":bad.journey_response.defense.reported_by_pile.home=0
   "total":bad.journey_response.defense.reported_losses+=1
  before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and before==copy.run.to_dict(),"Forged per-pile defense "+gate+" rejects atomically")
 game=Controller.new();game.restore_snapshot(initial);root.simulation=game
 game.journey_response.defend(route.id);game.advance(8);game.journey_response.reinforce(route.id);game.advance(1)
 test.check(root.respond_to_journey("recall",route.id).accepted and game.run.journey_response.active(),"Local recall retains paid traveling defenders and reinforcement")
 test.check(Parent.new().exact(game,200) and not game.run.journey_response.active() and game.run.colony.piles.satellite_1.workers_available==local and game.run.predator.defeated_at==0,"Physical recalled local party meets its batch and returns all workers")
 var view:=View.new();test.get_root().add_child(view);view.journey_command=root.respond_to_journey
 view._signals=root.sensory_snapshot("satellite_1");view._status=root.outward_status("satellite_1");view.selected_id="threat:"+route.id
 view._pointer_press(view._force_rect(12).get_center(),"mouse")
 test.check(game.run.journey_response.defense.mode=="defend","Mouse local mobilization uses the returned ambusher control")
 game.advance(4);view._status=root.outward_status("satellite_1");view._pointer_press(view._journey_rect("journey_defend").get_center(),"touch")
 test.check(game.run.journey_response.defense.extra_workers==4,"Touch reinforcement funds the same local semantic command")
 view.queue_free();root.free()
 _test_genetics_and_history(test)
 return true
func _test_genetics_and_history(test: Object) -> void:
 var base:=fixture(true);var snapshot_before: Dictionary=snapshot(base);var found: bool=false
 for seed_value: int in 96:
  var game:=Controller.new();game.restore_snapshot(snapshot_before);game.run.rng.seed=seed_value
  var root:=Root.new();root.simulation=game;root.inward_pile_id="satellite_1"
  var route: TrailRouteState=game.run.trails.find_route("satellite_1","known:carb_exposed")
  var known: int=root.inward_status("satellite_1").adapted_workers
  game.journey_response.defend(route.id)
  for tick: int in 1200:
   game.advance(0.25)
   if game.run.journey_response.defense.adapted_lost>0 and game.run.predator.resistance>0:break
   if not game.run.journey_response.active():break
  if game.run.journey_response.defense.adapted_lost>0 and game.run.predator.resistance>0:
   found=true
   test.check(root.inward_status("satellite_1").adapted_workers==known and Parent.new().exact(game,0),"Private real immigrant phenotype death preserves daughter's expected expression/save")
   game.journey_response.recall()
   while game.run.journey_response.active():game.advance(0.25)
   var child_losses: int=game.run.journey_response.defense.reported_for_pile("satellite_1")
   test.check(child_losses>0 and root.inward_status("satellite_1").adapted_workers==game.run.colony.piles.satellite_1.adapted_workers_total,"Returning daughter resolves immigrant phenotype and own lifetime losses")
   game.create_trail("home","known:carb_exposed");var parent_route: TrailRouteState=game.run.trails.find_route("home","known:carb_exposed")
   for tick: int in 2000:
    game.advance(0.25)
    if parent_route.reported_losses>0:break
   game.set_trail_workers(parent_route.id,0)
   while parent_route.allocated_workers>0:game.advance(0.25)
   game.journey_response.investigate(parent_route.id)
   while game.run.journey_response.active():game.advance(0.25)
   var parent_ready: Dictionary=snapshot(game);var both_losses: bool=false
   for combat_seed: int in 64:
    var trial:=Controller.new();trial.restore_snapshot(parent_ready);trial.run.rng.seed=combat_seed
    trial.journey_response.defend(parent_route.id)
    for tick: int in 1600:
     trial.advance(0.25)
     if trial.run.journey_response.defense.lost>0 or not trial.run.journey_response.active():break
    if trial.run.journey_response.defense.lost>0:
     if trial.run.journey_response.active():trial.journey_response.recall()
     while trial.run.journey_response.active():trial.advance(0.25)
     test.check(trial.run.journey_response.defense.reported_for_pile("home")>0 and trial.run.journey_response.defense.reported_for_pile("satellite_1")==child_losses and Parent.new().exact(trial,100),"Subsequent real Home casualties preserve daughter lifetime history through origin changes")
     both_losses=true;break
   test.check(both_losses,"Seed coverage exercises actual defense casualties at both origins")
   var empty:=Controller.new();var old: Dictionary=snapshot(empty);old.journey_response.defense.erase("reported_by_pile")
   test.check(empty.restore_snapshot(old),"Legacy empty/Home-only defense map defaults without inventing daughter deaths")
   root.free();break
  root.free()
 test.check(found,"Seed coverage exercises a real adapted daughter defensive loss")
