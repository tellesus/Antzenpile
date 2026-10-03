extends RefCounted
const Fixture=preload("res://tests/test_daughter_scouts.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Exact=preload("res://tests/test_parent_supply.gd")
const Finder=preload("res://src/sim/scouting/scout_pathfinder.gd")
const SOURCE="known:carb_exposed"
func run(test: Object) -> bool:
 var colony:=Fixture.new().root_fixture();var game: SimulationController=colony.simulation
 var home: PileState=game.run.colony.piles.home;var daughter: PileState=game.run.colony.piles.satellite_1
 var before: Dictionary=game.run.to_dict()
 test.check(not game.set_exploration(2,"unknown") and before==game.run.to_dict(),"Unknown exploration origin rejects atomically")
 test.check(colony.set_exploration(2).accepted and game.run.daughter_exploration.target==2 and game.run.exploration.target==0,"Daughter effort changes only its own standing intent")
 test.check(colony.set_exploration_bias(PI).accepted and is_equal_approx(game.run.daughter_exploration.bias,PI) and game.run.exploration.bias==null,"Directional bias belongs to selected pile")
 test.check(colony.toggle_investigation_priority(SOURCE).accepted and game.run.daughter_exploration.priorities==[SOURCE] and game.run.exploration.priorities.is_empty(),"Returned source priority belongs to selected pile")
 game.toggle_pause();var workers: int=daughter.workers_available
 game.advance(2);test.check(daughter.workers_available==workers and game.run.scouts.is_empty(),"Paused standing orders do not launch workers")
 game.toggle_pause();var parent: int=home.workers_available
 game.advance(1)
 var early_returns: Array=colony.scout_mission_summaries("satellite_1").filter(func(memory:Dictionary)->bool:return memory.returned_at>=0)
 test.check(game.run.daughter_exploration.coverage.is_empty() or not early_returns.is_empty(),"Local coverage requires an actual returned mission, including an entrance-side confirmation")
 game.advance(11)
 test.check(game.scouting.standing_count("satellite_1")==2 and daughter.workers_available==workers-2 and home.workers_available==parent,"Local staggered effort commits two own workers")
 var launched: Array=game.run.scouts.values().filter(func(agent:ScoutAgent)->bool:return agent.origin_pile==daughter.id);var local_id: String=launched[0].id
 test.check(launched.all(func(agent:ScoutAgent)->bool:return agent.standing and agent.origin_pile=="satellite_1" and daughter.position in agent.return_path),"All local standing agents preserve fractional origin")
 test.check(game.run.exploration.coverage.is_empty(),"Daughter scout course does not change Home returned coverage")
 test.check(Exact.new().exact(game,24),"Both fractional general and priority scouts continue exactly after JSON restore")
 colony.inspect_outward_pile("home");test.check(colony.set_exploration(5).accepted,"Home may share remaining effort with Daughter")
 before=game.run.to_dict();test.check(not colony.set_exploration(8).accepted and before==game.run.to_dict(),"Overcommitted combined target rejects rather than stealing other pile effort")
 test.check(colony.exploration_summary("home").other_target==2 and colony.exploration_summary("satellite_1").other_target==5,"Each panel knows the other standing target")
 game.advance(40);test.check(game.scouting.standing_count("home")>0 and game.scouting.standing_count("satellite_1")>0 and game.run.active_scout_count()<=8,"Both origins receive real workers under shared agent cap")
 var home_paths: Dictionary={}
 for agent: ScoutAgent in game.run.scouts.values():
  if agent.origin_pile=="home": home_paths[agent.id]=agent.to_dict()
 colony.inspect_outward_pile("satellite_1");before=game.run.to_dict();test.check(colony.set_exploration(0).accepted,"Daughter effort can be turned off while agents away")
 var unaltered: bool=true
 for id: String in home_paths: unaltered=unaltered and game.run.scouts[id].to_dict()==home_paths[id]
 test.check(unaltered and game.run.exploration.target==5 and daughter.workers_available<=workers-1,"Local Off recalls only daughter surplus without immediate release")
 test.check(Exact.new().exact(game,4000),"Dual standing/search/physical recall saves continue exactly")
 test.check(game.scouting.standing_count("satellite_1")==0 and not game.run.daughter_exploration.coverage.is_empty(),"Returned daughter trips deliver only local coverage and release standing workers")
 var legacy: Dictionary=game.run.to_dict();legacy.erase("daughter_exploration")
 var copy:=Controller.new();test.check(copy.restore_snapshot(legacy) and copy.run.daughter_exploration.to_dict()==ExplorationState.new().to_dict(),"Older supported daughter saves default standing effort/coverage/priorities to off/unknown")
 for change: String in ["unknown_priority","target","missing_policy"]:
  var bad: Dictionary=game.run.to_dict()
  if change=="unknown_priority":bad.daughter_exploration.priorities=["known:missing"]
  elif change=="target":bad.daughter_exploration.target=8
  else:
   game.set_exploration(2,"satellite_1");game.advance(4);bad=game.run.to_dict();bad.erase("daughter_exploration")
  var snapshot: Dictionary=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and snapshot==copy.run.to_dict(),"Unknown, excessive or orphan daughter policy rejects atomically")
 var plain:=Controller.new();var forged: Dictionary=plain.run.to_dict();forged.daughter_exploration.target=1
 test.check(not plain.restore_snapshot(forged),"Policy cannot create an unestablished daughter")
 var all: int=game.run.active_scout_count();game.set_exploration(0,"home");game.set_exploration(0,"satellite_1");game.advance(300)
 test.check(game.scouting.standing_count("home")==0 and game.scouting.standing_count("satellite_1")==0 and all>0,"Both local Off orders drain real transit")
 test.check(game.run.colony.piles.home.workers.invariant_holds() and game.run.colony.piles.satellite_1.workers.invariant_holds(),"Both ledgers conserve standing exploration")
 colony.free();_trunk(test);return true

func _trunk(test: Object) -> void:
 var colony:=Fixture.new().root_fixture();var game: SimulationController=colony.simulation
 game.create_trail("satellite_1",SOURCE);game.advance(80)
 var route: TrailRouteState=game.run.trails.find_route("satellite_1",SOURCE)
 test.check(route.delivered_total>0,"Trunk fixture uses actual daughter-delivered cargo")
 game.set_exploration(1,"satellite_1")
 var pile: PileState=game.run.colony.piles.satellite_1
 var path: Array[Vector2]=Finder.new(game.run.world).path_from_origin(pile.position,route.estimated_destination.round(),game.run.world)
 test.check(game.scouting._dispatch_route(pile,path,true,0.0,"",route.id),"One real local worker can follow its established gathering trunk")
 test.check(Exact.new().exact(game,40),"Fractional-origin trunk path and captured adult profile restore exactly")
 var id: String="scout_%d" % (game.run.next_scout_id-1)
 var invalid: Dictionary=game.run.to_dict()
 for scout: Dictionary in invalid.scouts:
  if scout.id==id and not scout.trunk_path.is_empty():scout.trunk_path[1]=[23.5,22.5]
 var twin:=Controller.new();test.check(not twin.restore_snapshot(invalid),"Trunk permits only the precise rounded entrance anchor, not arbitrary fractional steps")
 colony.free()
