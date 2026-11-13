extends SceneTree
const Root=preload("res://src/core/game_root.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
var failed: bool=false
func _initialize():call_deferred("go")
func go():
 var rows: Array=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var root:=Root.new();root.simulation=Controller.new()
   var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card108_%s_%d_final.json" % [scenario,seed_value]))
   if not root.simulation.restore_snapshot(saved):quit(1);return
   root.inward_pile_id="satellite_1";var game: SimulationController=root.simulation
   var chosen: TrailRouteState
   for route: TrailRouteState in game.run.trails.routes.values():
    if route.origin_pile=="satellite_1" and route.reported_losses>0:chosen=route;break
   if chosen==null:
    if not root.create_trail_for("known:aphid_01").accepted:quit(1);return
    chosen=game.run.trails.find_route("satellite_1","known:aphid_01")
    for tick: int in 2400:
     game.advance(0.25)
     if chosen.reported_losses>0:break
   if chosen.reported_losses==0:quit(1);return
   root.set_trail_target(chosen.id,0)
   for tick: int in 1200:
    game.advance(0.25)
    if chosen.allocated_workers==0:break
   FileAccess.open("res://.godot/card112_%s_%d_ready.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict()))
   var d: PileState=game.run.colony.piles.satellite_1;var h: PileState=game.run.colony.piles.home
   var local: int=d.workers_available;var parent: Dictionary=h.workers.to_dict();var food: float=d.resources.carbohydrate;var start: float=game.run.simulation_time
   if not root.respond_to_journey("investigate",chosen.id).accepted:quit(1);return
   var parent_unchanged: bool=parent==h.workers.to_dict()
   var cost: float=food-d.resources.carbohydrate
   var copy:=Controller.new();var exact: bool=copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict())))
   var private_count: int=0
   for tick: int in 2400:
    game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict()
    if game.run.journey_response.active() and game.run.journey_response.ambush_fraction>=0:
     private_count+=1
     if not game.run.journey_response.reports.has(chosen.id):pass
     else:failed=true
    if not game.run.journey_response.active():break
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"route_id":chosen.id,"losses":chosen.reported_losses,"cost":cost,"duration":game.run.simulation_time-start,"private_ticks":private_count,"report":game.run.journey_response.reports.get(chosen.id,{}),"saved_exact":exact,"local_workers_released":d.workers_available==local,"parent_dispatch_unchanged":parent_unchanged,"no_parent_party":h.workers.count("journey:home")==-1}
   row.passed=exact and not row.report.is_empty() and row.local_workers_released and row.parent_dispatch_unchanged and row.no_parent_party
   failed=failed or not row.passed;rows.append(row);print("[DAUGHTER-SURVEY] ",row)
   FileAccess.open("res://.godot/card112_%s_%d_returned.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict()))
   root.free()
 FileAccess.open("res://.godot/card112_surveys.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
