extends RefCounted
const Fixture=preload("res://tests/test_daughter_gathering.gd")
const SaveFixture=preload("res://tests/test_parent_supply.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Finder=preload("res://src/sim/scouting/scout_pathfinder.gd")
const Predator=preload("res://data/ecology/backyard_predator.tres")
const SOURCE="known:carb_exposed"

func root_fixture() -> Node:
 var colony:=Root.new();colony.simulation=Fixture.new().fixture();colony.inward_pile_id="satellite_1";return colony

func run(test: Object) -> bool:
 var colony:=root_fixture();var game: SimulationController=colony.simulation
 var home: PileState=game.run.colony.piles.home;var daughter: PileState=game.run.colony.piles.satellite_1
 var available: int=daughter.workers_available;var parent: int=home.workers_available
 test.check(daughter.position!=daughter.position.round(),"Scout fixture retains a real fractional daughter entrance")
 test.check(colony.daughter_gathering_command(SOURCE,"scout").accepted and daughter.workers_available==available-1 and home.workers_available==parent,"One local recheck reserves only a daughter worker")
 var id: String=colony.daughter_source_scout(SOURCE).id;var agent: ScoutAgent=game.run.scouts[id]
 test.check(agent.path[0]==daughter.position and agent.path[1]==daughter.position.round() and agent.return_path[0]==daughter.position,"Scout physically joins the cardinal grid from its actual entrance")
 var before: Dictionary=game.run.to_dict()
 test.check(not colony.daughter_gathering_command(SOURCE,"scout").accepted and before==game.run.to_dict(),"Duplicate awaiting source recheck rejects atomically")
 test.check(SaveFixture.new().exact(game,0),"Fractional-origin departure and commanded target restore exactly")
 var legacy: Dictionary=game.run.to_dict()
 for record: Dictionary in legacy.scout_missions: record.erase("target_knowledge_id")
 var copy:=Controller.new()
 test.check(copy.restore_snapshot(legacy) and copy.run.scout_missions[id].target_knowledge_id.is_empty(),"Legacy departure memory gains no invented named target")
 for value: Variant in [null,"known:unknown","known:nest_site_01"]:
  var forged: Dictionary=game.run.to_dict()
  for record: Dictionary in forged.scout_missions:
   if record.id==id: record.target_knowledge_id=value
  var prior: Dictionary=copy.run.to_dict()
  test.check(not copy.restore_snapshot(forged) and prior==copy.run.to_dict(),"Malformed, unknown or mismatched active scout target rejects atomically")
 var old_delivered: float=game.run.knowledge.nodes[SOURCE].last_delivered_at
 var saw_private: bool=false;var exact: bool=true
 var twin:=Controller.new();exact=twin.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict())))
 for tick: int in 800:
  if not game.run.scouts.has(id): break
  game.advance(0.25);twin.advance(0.25);exact=exact and game.run.to_dict()==twin.run.to_dict()
  if game.run.scouts.has(id) and not agent.observations.is_empty():
   saw_private=true
   test.check(colony.daughter_source_scout(SOURCE).awaiting and game.run.knowledge.nodes[SOURCE].last_delivered_at==old_delivered,"Private local sensing remains awaiting without refreshing shared memory")
 test.check(saw_private and exact and game.run.scout_missions[id].returned_at>0 and daughter.workers_available==available and home.workers_available==parent,"Actual local return delivers once and releases its own worker, with exact continuation")
 test.check(game.run.knowledge.nodes[SOURCE].last_delivered_at>old_delivered and not colony.daughter_source_scout(SOURCE).awaiting,"Source memory and returned status refresh only after return")
 game.run.world.nodes.carb_exposed.active=false;game.run.world.nodes.carb_exposed.quantity=0
 var hint: Dictionary=game.run.knowledge.temporal_hint(SOURCE).duplicate(true)
 test.check(colony.daughter_gathering_command(SOURCE,"scout").accepted,"Inactive hidden source does not reject an ordinary remembered recheck")
 game.advance(1.25);available=daughter.workers_available
 test.check(colony.daughter_gathering_command(SOURCE,"recall_scout").accepted and daughter.workers_available==available,"Early recall requests actual travel without an instant worker refund")
 test.check(SaveFixture.new().exact(game,100) and game.run.knowledge.temporal_hint(SOURCE)==hint,"Early recall before reaching estimate invents no empty-source report")
 test.check(not colony.daughter_gathering_command(SOURCE,"recall_scout").accepted,"Completed local scout cannot be recalled again")
 colony.daughter_gathering_command(SOURCE,"scout")
 test.check(SaveFixture.new().exact(game,160) and game.run.knowledge.temporal_hint(SOURCE).last_return_empty,"Actual target visitation and return can report a source not found")
 colony.free()
 var capped:=root_fixture()
 for scout: int in capped.simulation.scouting.config.active_cap: capped.simulation.dispatch_scout("home",0.0)
 before=capped.simulation.run.to_dict()
 test.check(not capped.daughter_gathering_command(SOURCE,"scout").accepted and capped.simulation.run.to_dict()==before,"Home missions and local rechecks share the same global scout cap")
 capped.free()
 _missing(test)
 return true

func _missing(test: Object) -> void:
 var colony:=root_fixture();var game: SimulationController=colony.simulation
 var daughter: PileState=game.run.colony.piles.satellite_1
 var source: WorldNodeState=game.run.world.nodes.carb_exposed;source.active=false;source.quantity=0
 # Isolate real local casualty/privacy using a deliberately exposed physical route.
 var path: Array[Vector2]=Finder.new(game.run.world).path_from_origin(daughter.position,Predator.position.round(),game.run.world)
 var count: int=daughter.workers_total;var parent_loss: int=game.run.colony.piles.home.workers.lost_total
 test.check(game.scouting._dispatch_route(daughter,path,false,0.0,"carb_exposed"),"Local loss fixture dispatches a real daughter worker")
 var id: String=colony.daughter_source_scout(SOURCE).id
 for tick: int in 800:
  game.advance(0.25)
  if game.run.scouts[id].lost: break
 var agent: ScoutAgent=game.run.scouts[id]
 test.check(agent.lost and daughter.workers_total==count-1 and colony.inward_status("satellite_1").workers_total==count and colony.inward_status("satellite_1").active_scouts==1,"Physical daughter casualty preserves expected local counts until absence settles")
 var known: Dictionary=colony.daughter_source_scout(SOURCE)
 test.check(known.awaiting and known.missing_at==-1 and not known.has("lost") and colony.daughter_gathering_command(SOURCE,"recall_scout").accepted,"Private local casualty retains ordinary awaiting and recall feedback")
 test.check(SaveFixture.new().exact(game,0),"Private daughter loss, imported profile accounting and fractional path restore exactly")
 game.advance(agent.expected_tick*0.25-game.run.simulation_time)
 known=colony.daughter_source_scout(SOURCE)
 test.check(not known.awaiting and known.missing_at>=0 and known.returned_at==-1 and game.run.missing_scouts("satellite_1")==1,"Expected absence settles as did not return, with no cause or discovery")
 test.check(game.run.colony.piles.home.workers.lost_total==parent_loss and SaveFixture.new().exact(game,40),"Local scout death never charges Home; settled conservation continues exactly")
 colony.free()
