extends RefCounted
const Fixture=preload("res://tests/test_daughter_scouts.gd")
const Exact=preload("res://tests/test_parent_supply.gd")
const View=preload("res://src/presentation/outward/outward_view.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const SOURCE="known:carb_exposed"
func run(test: Object) -> bool:
 var colony:=Fixture.new().root_fixture();var game: SimulationController=colony.simulation
 var view:=View.new();test.get_root().add_child(view);colony._outward_view=view
 view.signal_provider=colony.focused_outward_signals;view.status_provider=colony.focused_outward_status
 view.dispatch_command=colony.dispatch_facing;view.exploration_command=colony.set_exploration;view.pile_command=colony.inspect_outward_pile
 view.investigate_command=colony.focused_source_investigation;view.trail_create_command=colony.create_trail_for
 var before: Dictionary=game.run.to_dict()
 test.check(colony.set_mode("outward") and colony.inward_pile_id=="satellite_1","Daughter INWARD to OUTWARD preserves selected pile")
 view._process(0)
 test.check(view._status.pile_name=="Daughter" and not view._status.has("exploration") and view._status.honeydew.is_empty() and view._status.journey_response.is_empty(),"Daughter projection omits Home standing policy/tending/defense")
 var signal_data: Dictionary=colony.focused_outward_signals().filter(func(a:Dictionary)->bool:return a.source_knowledge_id==SOURCE)[0]
 var home_signal: Dictionary=colony.sensory_snapshot("home").filter(func(a:Dictionary)->bool:return a.source_knowledge_id==SOURCE)[0]
 test.check(signal_data.bearing!=home_signal.bearing and signal_data.estimated_distance!=home_signal.estimated_distance,"Shared memory bearing/distance is relative to actual selected entrance")
 test.check(not colony.inspect_outward_pile("unknown") and game.run.to_dict()==before,"Unknown pile attention rejects without sim mutation")
 var results: Array=[colony.set_exploration(5),colony.set_exploration_bias(PI),colony.toggle_investigation_priority(SOURCE),colony.start_honeydew_tending(SOURCE),colony.stop_honeydew_tending(SOURCE),colony.start_founding("known:nest_site_01"),colony.establish_daughter("known:nest_site_01"),colony.respond_to_journey("recall","route_1")]
 test.check(results.all(func(result:Dictionary)->bool:return not result.accepted) and before==game.run.to_dict(),"Home-owned orders reject atomically from Daughter attention")
 var home: PileState=game.run.colony.piles.home;var daughter: PileState=game.run.colony.piles.satellite_1
 var parent: int=home.workers_available;var local: int=daughter.workers_available
 view._run_command("scout")
 var id: String="scout_%d" % (game.run.next_scout_id-1)
 test.check(not view.exploration_open and game.run.scouts.has(id) and game.run.scouts[id].origin_pile==daughter.id and daughter.workers_available==local-1 and home.workers_available==parent,"Daughter Send Scout starts a local new-source mission instead of Home policy")
 test.check(Exact.new().exact(game,20),"Fractional-origin manual search restores exactly through travel")
 view.selected_id="mission:"+id;view.facing=PI;view.sources_open=true;view.exploration_open=true;view.journey_open=true;view._pointer_kind="mouse"
 before=game.run.to_dict()
 test.check(colony.inspect_outward_pile("home") and before==game.run.to_dict() and view.selected_id.is_empty() and view.facing==0 and not view.sources_open and not view.exploration_open and not view.journey_open and view._pointer_kind.is_empty(),"Free pile switch resets obsolete context/gesture/facing without recalling workers")
 before=game.run.to_dict()
 test.check(not colony.recall_scout(id).accepted and before==game.run.to_dict(),"Stale Daughter scout recall rejects from Home")
 test.check(colony.create_trail_for(SOURCE).accepted,"Home can separately order same shared source")
 var parent_route: TrailRouteState=game.run.trails.find_route("home",SOURCE)
 colony.inspect_outward_pile("satellite_1");before=game.run.to_dict()
 test.check(not colony.set_trail_target(parent_route.id,0).accepted and not colony.recheck_trail(parent_route.id).accepted and before==game.run.to_dict(),"Daughter cannot recall or recheck Home route IDs")
 test.check(colony.create_trail_for(SOURCE).accepted,"Daughter orders its own shared-source trail")
 var route: TrailRouteState=game.run.trails.find_route(daughter.id,SOURCE)
 test.check(route.id!=parent_route.id and daughter.workers.count("trail:"+route.id)==5 and parent_route.allocated_workers==5,"Same source preserves distinct origin commitments")
 before=game.run.to_dict()
 test.check(not colony.set_trail_target(game.run.founding.route_id,0).accepted and before==game.run.to_dict(),"Gathering controls cannot alter parent supply connection")
 test.check(colony.recall_scout(id).accepted and Exact.new().exact(game,160),"Local manual scout physically recalls with exact saved transit")
 test.check(not game.run.scouts.has(id) and game.run.scout_missions[id].returned_at>=0,"Manual local worker returns before report")
 test.check(colony.focused_source_investigation(SOURCE).accepted and not colony.focused_source_investigation(SOURCE).accepted,"Daughter context rechecks once rather than modifying Home priorities")
 var recheck: String="scout_%d" % (game.run.next_scout_id-1)
 test.check(colony.recall_scout(recheck).accepted and Exact.new().exact(game,120),"Known local recheck retains physical return/saved continuation")
 view._process(0);view.selected_id=signal_data.id
 test.check(view._investigation_title(signal_data)=="SEND SCOUT TO RECHECK" and view._button_at(view._journey_rect("journey_open").get_center())!="journey_open","Daughter offers deliberate recheck with no Home paid journey control")
 colony.set_mode("inward");test.check(colony.inward_pile_id==daughter.id,"OUTWARD to INWARD retains daughter context")
 colony._refresh_loaded_views();test.check(colony.inward_pile_id=="home" and view._status.pile_name=="Home","Load/new-run reset baselines Home before rebinding projection")
 colony._outward_view=null;view.queue_free();colony.free();return true
