extends SceneTree
const Root=preload("res://src/core/game_root.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
var failed: bool=false
func _initialize():call_deferred("go")
func save(game: SimulationController, stem: String, phase: String):
 FileAccess.open("res://.godot/"+stem+"_"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(),"",true,true))
func go():
 var rows: Array=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var stem: String="card113_%s_%d" % [scenario,seed_value]
   var root:=Root.new();root.simulation=Controller.new()
   if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card112_%s_%d_returned.json" % [scenario,seed_value]))):quit(1);return
   root.inward_pile_id="satellite_1";var game: SimulationController=root.simulation;var d: PileState=game.run.colony.piles.satellite_1
   var route: TrailRouteState=game.run.trails.routes.route_9
   var local: int=d.workers_available;var food: float=d.resources.carbohydrate;var h: PileState=game.run.colony.piles.home
   var parent: Dictionary=h.workers.to_dict();var start: float=game.run.simulation_time
   save(game,stem,"ready")
   if not root.respond_to_journey("defend",route.id).accepted:print(game.journey_response.last_error);quit(1);return
   var parent_unchanged: bool=parent==h.workers.to_dict();var initial_cost: float=food-d.resources.carbohydrate
   game.advance(5)
   var reinforce_food: float=d.resources.carbohydrate
   if not root.respond_to_journey("reinforce",route.id).accepted:print(game.journey_response.last_error);quit(1);return
   var cost: float=initial_cost+reinforce_food-d.resources.carbohydrate
   save(game,stem,"outbound")
   var copy:=Controller.new();var exact: bool=copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true)))
   var private_count: int=0;var combat: bool=false;var expected: int=root.inward_status(d.id).workers_total;var emerged: int=d.brood_matured_total
   for tick: int in 2400:
    game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict()
    if game.run.journey_response.phase=="fighting" and not combat:save(game,stem,"combat");combat=true
    if game.run.journey_response.active():
     if root.inward_status(d.id).workers_total!=expected+d.brood_matured_total-emerged:failed=true
     if game.run.journey_response.defense.lost>0:private_count+=1
    else:break
   var outcome: Dictionary=game.run.journey_response.defense.outcomes.get(route.id,{})
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"cost":cost,"duration":game.run.simulation_time-start,"private_loss_ticks":private_count,"outcome":outcome,"available_before":local,"available_after":d.workers_available,"local_workers_released":d.workers.count("journey:satellite_1")==-1 and not game.run.journey_response.active(),"parent_dispatch_unchanged":parent_unchanged,"saved_exact":exact,"no_parent_defense_deaths":game.run.journey_response.defense.reported_for_pile("home")==0}
   save(game,stem,"returned")
   var prior: float=route.delivered_total;var kills: int=game.run.predator.kills_total
   root.set_trail_target(route.id,5);game.advance(240)
   row.harvest=route.delivered_total-prior;row.new_ambush_kills=game.run.predator.kills_total-kills
   row.passed=exact and row.local_workers_released and row.parent_dispatch_unchanged and row.no_parent_defense_deaths and row.outcome.get("outcome")=="secured" and row.harvest>0 and row.new_ambush_kills==0
   failed=failed or not row.passed;rows.append(row);print("[DAUGHTER-DEFENSE] ",row);root.free()
 FileAccess.open("res://.godot/card113_defense.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
