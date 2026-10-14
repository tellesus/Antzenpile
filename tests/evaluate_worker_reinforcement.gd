extends SceneTree
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
   var game:=Controller.new()
   if not game.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card113_%s_%d_returned.json" % [scenario,seed_value]))):quit(1);return
   var h: PileState=game.run.colony.piles.home;var d: PileState=game.run.colony.piles.satellite_1
   var leg: int=game.reinforcement.TRAILS.leg_ticks(h.position.distance_to(d.position))
   var migrated: int=d.workers.transferred_in;var departed: int=h.workers.transferred_out;var invariant: int=population(game)
   var total_cost: float=0;var exact: bool=true;var conserved: bool=true;var premature: bool=false;var accepted: bool=true
   for batch: int in 3:
    total_cost+=game.reinforcement.summary().cost;accepted=accepted and game.send_daughter_workers()
    var copy:=Controller.new();exact=exact and copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true)))
    FileAccess.open("res://.godot/card115_%s_%d_outbound.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(),"",true,true))
    for tick: int in (2*leg if batch<2 else 10):
     game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict();conserved=conserved and population(game)==invariant
     if tick<2*leg-1 and game.reinforcement.summary().reports>batch:premature=true
     if tick==leg-1:
      FileAccess.open("res://.godot/card115_%s_%d_arrived.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(),"",true,true))
    if batch==2:
     accepted=accepted and game.recall_daughter_workers();exact=exact and copy.recall_daughter_workers()
     for tick: int in 10:
      game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict();conserved=conserved and population(game)==invariant
   FileAccess.open("res://.godot/card115_%s_%d_returned.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(),"",true,true))
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"accepted":accepted,"saved_exact":exact,"conserved":conserved,"premature_report":premature,"leg_seconds":leg*0.25,"travel_carbs_paid":total_cost,"settlers_received":d.workers.transferred_in-migrated,"home_exported":h.workers.transferred_out-departed,"reports":game.run.reinforcement.trips_reported,"last_settled":game.run.reinforcement.last_settled,"reported_settlers":game.reinforcement.summary().reported_workers,"profiles":game.run.reinforcement.moved_profiles,"daughter_workers":d.workers_total}
   row.passed=accepted and exact and conserved and not premature and row.settlers_received==16 and row.home_exported==16 and row.reports==3 and row.last_settled==0 and row.reported_settlers==16 and not game.run.reinforcement.active() and game.run.supply.phase=="none"
   rows.append(row);failed=failed or not row.passed;print("[WORKER-REINFORCEMENT] ",row)
 FileAccess.open("res://.godot/card115_reinforcement.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
