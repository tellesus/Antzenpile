extends RefCounted
const Fixture=preload("res://tests/test_parent_supply.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Gathering=preload("res://src/presentation/inward/daughter_gathering.gd")

func fixture() -> SimulationController:
 var game: SimulationController=Fixture.new().fixture()
 var source: WorldNodeState=Controller.new().run.world.nodes.carb_exposed
 source.position=Vector2(29.25,22.25);game.run.world.nodes[source.id]=source
 game.dispatch_scout("home",0.0)
 var agent: ScoutAgent=game.run.scouts.values()[0]
 agent.path.clear()
 for x: int in range(20,36): agent.path.append(Vector2(x,20))
 agent.mission_target=Vector2(35,20)
 for tick: int in 1600:
  game.advance(0.25)
  if game.run.scouts.is_empty(): break
 return game

func run(test: Object) -> bool:
 var game:=fixture();var colony:=Root.new();colony.simulation=game
 var home: PileState=game.run.colony.piles.home;var daughter: PileState=game.run.colony.piles.satellite_1
 var before: Dictionary=game.run.to_dict()
 test.check(game.run.knowledge.nodes.has("known:carb_exposed") and Fixture.new().exact(game,0),"Returned shared resource memory and real foundation form a valid two-pile run")
 test.check(not colony.daughter_gathering_command("known:carb_exposed","gather").accepted and game.run.to_dict()==before,"Home attention cannot accidentally assign daughter workers")
 colony.inward_pile_id="satellite_1"
 for request: Array in [["unknown","gather"],["known:nest_site_01","gather"],["known:carb_exposed","invalid"],["known:carb_exposed","stop"]]:
  test.check(not colony.daughter_gathering_command(request[0],request[1]).accepted and game.run.to_dict()==before,"Unknown, shelter, malformed and orphan gathering commands reject atomically")
 var h_available: int=home.workers_available;var d_available: int=daughter.workers_available
 test.check(colony.daughter_gathering_command("known:carb_exposed","gather").accepted and daughter.workers_available==d_available-5 and home.workers_available==h_available,"Local assignment reserves only five real daughter workers")
 var route: TrailRouteState=game.run.trails.find_route("satellite_1","known:carb_exposed")
 test.check(colony.daughter_gathering_command("known:carb_exposed","add").accepted and home.workers_available==h_available and route.allocated_workers==10,"Adding gatherers uses only the daughter's remaining labor")
 before=game.run.to_dict()
 test.check(not colony.daughter_gathering_command("known:carb_exposed","add").accepted and game.run.to_dict()==before,"Insufficient daughter labor rejects without using Home's available workers")
 game.run.world.nodes.carb_exposed.properties.contaminant_fraction=0.5
 var segment: TrailSegmentState=game.run.trails.segments[route.segment_id]
 test.check(segment.start==daughter.position and route.origin_pile=="satellite_1" and segment.end==game.run.knowledge.nodes[route.destination_knowledge_id].estimated_position,"Local route uses daughter origin and returned estimate, never hidden coordinates")
 var h_carbs: float=home.resources.carbohydrate;var d_carbs: float=daughter.resources.carbohydrate
 game.advance(0.25)
 test.check(home.resources.carbohydrate==h_carbs and daughter.resources.carbohydrate<d_carbs and route.delivered_total==0,"Departure charges daughter travel food and creates no instant intake")
 test.check(Fixture.new().exact(game,0),"Daughter outbound ownership and captured phenotype restore exactly")
 while route.delivered_total==0 and game.run.simulation_time<4000: game.advance(0.25)
 test.check(route.receipt.last_at==game.run.simulation_time and route.delivered_total>0 and home.resources.carbohydrate==h_carbs,"Physical return deposits and dates intake only at daughter")
 test.check(daughter.food_toxicity.mass>0 and home.food_toxicity.mass==0,"Captured food contamination is delivered only to the collecting daughter")
 var summary: Dictionary=colony.daughter_gathering_summary();var remembered: Dictionary=summary.duplicate(true)
 var source: WorldNodeState=game.run.world.nodes.carb_exposed;source.quantity=0;source.active=false
 test.check(summary==colony.daughter_gathering_summary(),"Private depletion cannot refresh remembered source availability or receipts")
 summary.sources.carbohydrate[0].workers=999
 test.check(colony.daughter_gathering_summary()==remembered,"Browser data is detached from route labor and knowledge")
 while not route.reported_depleted and game.run.simulation_time<4000: game.advance(0.25)
 test.check(route.reported_depleted and colony.daughter_gathering_summary().sources.carbohydrate[0].state=="Reported empty","Only returned empty collection changes the memory's cue")
 while route.active_workers>0 and game.run.simulation_time<4000: game.advance(0.25)
 test.check(colony.daughter_gathering_command("known:carb_exposed","recheck").accepted,"Reported depletion can be rechecked by the same local gatherers")
 game.advance(0.25);var allocated: int=daughter.workers_available
 var idle: int=route.allocated_workers-route.active_workers
 test.check(colony.daughter_gathering_command("known:carb_exposed","stop").accepted and daughter.workers_available==allocated+idle and route.active_workers>0,"Recall releases idle workers but retains actually away daughter workers")
 test.check(Fixture.new().exact(game,120) and route.status=="inactive" and daughter.workers_available==d_available,"Actual daughter return releases once with exact JSON continuation")
 # Different origin means an independent ledger, route, receipt and local depletion status.
 test.check(game.create_trail("home","known:carb_exposed") and game.run.trails.find_route("home","known:carb_exposed").id!=route.id,"Shared source supports distinct Home and daughter routes")
 test.check(game.run.trails.find_route("home","known:carb_exposed").receipt.is_empty() and route.delivered_total>0,"A daughter receipt is never copied into Home's new route")
 var bad: Dictionary=game.run.to_dict();var twin:=Controller.new()
 for record: Dictionary in bad.trails.routes:
  if record.id==route.id: record.origin_pile="home"
 test.check(not twin.restore_snapshot(bad),"Forged local-route ownership cannot restore into another ledger")
 var view:=preload("res://src/presentation/inward/inward_view.gd").new();test.get_root().add_child(view)
 view._status=colony.focused_inward_status();view.selected_id="food_exchange"
 before=game.run.to_dict();view.activate_at(view._gather_link_rect().get_center())
 test.check(view.gathering.opened and before==game.run.to_dict(),"Opening local memories is free attention")
 var gathering: DaughterGathering=view.gathering;var size: Vector2=view.get_viewport_rect().size
 var at: Vector2=gathering.rect(size,"row",0).get_center()
 gathering.activate(view,at,colony.daughter_gathering_summary(),Callable())
 test.check(gathering.selected=="known:carb_exposed" and before==game.run.to_dict(),"Selecting a returned source cannot fund gatherers")
 gathering.activate(view,gathering.rect(size,"page").get_center(),colony.daughter_gathering_summary(),Callable())
 test.check(gathering.selected.is_empty() and before==game.run.to_dict(),"Changing memory page clears actions for the previous unseen source")
 gathering.activate(view,gathering.rect(size,"filter",2).get_center(),colony.daughter_gathering_summary(),Callable())
 test.check(gathering.category=="water" and gathering.selected.is_empty() and before==game.run.to_dict(),"Resource filters clear old selection without gameplay effects")
 gathering.activate(view,gathering.rect(size,"back").get_center(),colony.daughter_gathering_summary(),Callable())
 test.check(not gathering.opened,"Back restores the original local Food Exchange context")
 test.check(not gathering.rect(size,"order").intersects(gathering.rect(size,"stop")) and gathering.rect(size,"order").size.y==44,"Assign/recall have distinct touch-sized controls")
 view.free();colony.free();return true
