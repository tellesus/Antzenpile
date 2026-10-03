extends RefCounted
const Parent=preload("res://tests/test_parent_supply.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const View=preload("res://src/presentation/outward/outward_view.gd")
func fixture(game: SimulationController = null) -> SimulationController:
 if game == null: game=Parent.new().fixture()
 var source: WorldNodeState=Controller.new().run.world.nodes.carb_exposed
 source.position=Vector2(34,33);game.run.world.nodes[source.id]=source
 game.dispatch_scout("home",0)
 var scout: ScoutAgent=game.run.scouts.values()[0];scout.path.clear()
 for x: int in range(20,35):scout.path.append(Vector2(x,20))
 for y: int in range(21,34):scout.path.append(Vector2(34,y))
 scout.mission_target=Vector2(34,33)
 for tick: int in 4000:
  game.advance(0.25)
  if game.run.scouts.is_empty():break
 game.create_trail("satellite_1","known:carb_exposed")
 var route: TrailRouteState=game.run.trails.find_route("satellite_1","known:carb_exposed")
 for tick: int in 2000:
  game.advance(0.25)
  if route.reported_losses>0:break
 game.set_trail_workers(route.id,0)
 for tick: int in 1000:
  game.advance(0.25)
  if route.allocated_workers==0:break
 return game
func run(test: Object) -> bool:
 var game:=fixture();var root:=Root.new();root.simulation=game;root.inward_pile_id="satellite_1"
 var daughter: PileState=game.run.colony.piles.satellite_1;var home: PileState=game.run.colony.piles.home
 var route: TrailRouteState=game.run.trails.find_route(daughter.id,"known:carb_exposed")
 test.check(route.reported_losses>0 and Parent.new().exact(game,0),"Actual daughter harvest loss forms a valid survey fixture")
 var local: int=daughter.workers_available;var stores: Dictionary=daughter.resources.duplicate();var parent: Dictionary=home.workers.to_dict();var parent_stores: Dictionary=home.resources.duplicate()
 test.check(root.respond_to_journey("investigate",route.id).accepted and daughter.workers_available==local-3 and daughter.resources.carbohydrate<stores.carbohydrate,"Daughter survey pays local three-worker labor and travel food")
 test.check(home.workers.to_dict()==parent and home.resources==parent_stores and daughter.workers.count("journey:satellite_1")==3,"Local survey cannot borrow Home labor or food")
 var before: Dictionary=game.run.to_dict()
 root.inward_pile_id="home"
 test.check(not root.respond_to_journey("recall",route.id).accepted and not root.respond_to_journey("investigate",route.id).accepted and before==game.run.to_dict(),"Other-pile controls reject daughter response IDs atomically")
 test.check(not root.outward_status("home").journey_response.away and root.outward_status("home").journey_response.other_party=="Daughter","Home names occupied shared party slot without exposing daughter's private party")
 root.inward_pile_id=daughter.id
 test.check(not root.respond_to_journey("investigate",route.id).accepted and before==game.run.to_dict(),"Single shared response slot rejects a duplicate")
 var copy:=Controller.new();var saved: Dictionary=JSON.parse_string(JSON.stringify(before))
 test.check(copy.restore_snapshot(saved),"Daughter route commitment restores active survey ownership")
 var private_seen: bool=false
 while game.run.journey_response.active():
  game.advance(0.25);copy.advance(0.25)
  if game.run.journey_response.active():
   private_seen=private_seen or game.run.journey_response.ambush_fraction>=0
   if game.run.journey_response.ambush_fraction>=0:
    test.check(not root.outward_status(daughter.id).journey_response.reports.has(route.id) and not str(root.sensory_snapshot(daughter.id)).contains("threat:"),"Physical danger sample stays private throughout return")
 test.check(private_seen and game.run.to_dict()==copy.run.to_dict(),"Sampled fractional-origin survey continues identically through JSON")
 test.check(game.run.journey_response.reports[route.id].finding=="ambush" and daughter.workers_available==local and daughter.workers.count("journey:satellite_1")==-1,"Daughter return delivers evidence and releases own actual workers")
 test.check(root.outward_status("home").journey_response.reports.is_empty() and str(root.sensory_snapshot(daughter.id)).contains("threat:"),"Returned route evidence is projected only from its owner entrance")
 before=game.run.to_dict()
 test.check(not root.respond_to_journey("defend",route.id).accepted and before==game.run.to_dict(),"Insufficient daughter defense workers cannot borrow Home labor")
 test.check(root.respond_to_journey("investigate",route.id).accepted,"Returned local survey can be repeated")
 game.advance(2);var committed: int=daughter.workers_available
 test.check(root.respond_to_journey("recall",route.id).accepted and daughter.workers_available==committed,"Recall keeps workers committed until physical local arrival")
 test.check(Parent.new().exact(game,30) and not game.run.journey_response.active() and game.run.journey_response.reports[route.id].finding=="inconclusive","Early recalled survey returns without fabricated threat evidence")
 for gate: String in ["orphan","owner","job","duplicate","defense"]:
  var broken: Dictionary=saved.duplicate(true)
  match gate:
   "orphan":broken.erase("journey_response")
   "owner":broken.journey_response.route_id=game.run.founding.route_id
   "job":broken.colony.piles[1].workers.commitments["journey:satellite_1"].owner_id="missing"
   "duplicate":broken.colony.piles[0].workers.commitments["journey:home"]={"kind":"other","owner_id":route.id,"count":0}
   "defense":broken.journey_response.defense.mode="defend"
  before=copy.run.to_dict()
  test.check(not copy.restore_snapshot(broken) and before==copy.run.to_dict(),"Malformed local survey "+gate+" rejects restore atomically")
 var view:=View.new();test.get_root().add_child(view);view.journey_command=root.respond_to_journey
 view._signals=root.sensory_snapshot(daughter.id);view._status=root.outward_status(daughter.id);view.selected_id="signal:known:carb_exposed"
 view._pointer_press(view._journey_rect("journey_open").get_center(),"mouse")
 test.check(view.journey_open and not game.run.journey_response.active(),"Daughter Journey Reports opens as free attention")
 view._pointer_press(view._journey_rect("journey_investigate").get_center(),"touch")
 test.check(game.run.journey_response.active(),"Touch pays local survey through the same semantic control")
 view._status=root.outward_status(daughter.id);game.advance(2);view._pointer_press(view._journey_rect("journey_investigate").get_center(),"mouse")
 test.check(game.run.journey_response.phase=="inbound","Mouse recalls local paid party through real travel")
 view.queue_free();root.free();return true
