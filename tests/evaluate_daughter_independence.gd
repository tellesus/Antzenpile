extends SceneTree
const Root=preload("res://src/core/game_root.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
var failed: bool=false
func _initialize():call_deferred("go")
func population(game: SimulationController) -> int:
 var total: int=game.run.colony.workers_total
 for pile: PileState in game.run.colony.piles.values():total+=pile.workers.lost_total-pile.brood_matured_total
 return total
func go():
 var rows: Array=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var root:=Root.new();root.simulation=Controller.new()
   if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card113_%s_%d_returned.json" % [scenario,seed_value]))):quit(1);return
   var game: SimulationController=root.simulation;var d: PileState=game.run.colony.piles.satellite_1
   root.inward_pile_id="home";root.set_exploration(2);root.inward_pile_id=d.id;root.set_exploration(2)
   root.toggle_investigation_priority("known:water_01");root.toggle_investigation_priority("known:protein_01")
   var commanded: Array=[]
   for source: String in ["known:aphid_01","known:water_01","known:protein_01"]:
    var route: TrailRouteState=game.run.trails.find_route(d.id,source)
    var accepted: bool=game.set_trail_workers(route.id,5) if route!=null else game.create_trail(d.id,source)
    commanded.append({"source":source,"accepted":accepted,"reason":game.trails.last_error})
   game.set_humidity_workers(d.id,1);game.set_sanitation_workers(d.id,1);game.set_brood_intent(d.id,"grow")
   var started: int=d.brood_started_total;var emerged: int=d.brood_matured_total;var invariant: int=population(game)
   var copy:=Controller.new();var exact: bool=copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true)))
   var deliveries: float=0
   for route: TrailRouteState in game.run.trails.routes.values():
    if route.origin_pile==d.id:deliveries+=route.delivered_total
   var peak: int=game.run.active_scout_count();var conserved: bool=true
   for tick: int in 4800:
    game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict()
    conserved=conserved and population(game)==invariant
    peak=maxi(peak,game.run.active_scout_count())
   var final_deliveries: float=0
   for route: TrailRouteState in game.run.trails.routes.values():
    if route.origin_pile==d.id:final_deliveries+=route.delivered_total
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"commands":commanded,"duration":1200,"saved_exact":exact,"population_conserved":conserved,"peak_detail":peak,"home_effort":game.run.exploration.target,"daughter_effort":game.run.daughter_exploration.target,"local_intake":final_deliveries-deliveries,"local_coverage":game.run.daughter_exploration.coverage.size(),"brood_started":d.brood_started_total-started,"brood_emerged":d.brood_matured_total-emerged,"workers":d.workers_total,"stores":d.resources.duplicate(),"known_attention":root.pile_internal_attention(d.id),"defense":game.journey_response.summary(d.id).outcomes}
   row.passed=exact and conserved and peak<=8 and game.run.supply.phase=="none" and not game.run.supply.enabled and game.run.colony.piles.home.workers.count("journey:home")==-1 and row.local_intake>0 and row.local_coverage>0 and row.home_effort==2 and row.daughter_effort==2
   failed=failed or not row.passed;rows.append(row);print("[DAUGHTER-INDEPENDENCE] ",row);root.free()
 FileAccess.open("res://.godot/card114_independence.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
