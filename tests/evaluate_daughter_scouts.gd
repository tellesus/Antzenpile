extends "res://tests/evaluate_reproduction.gd"

func _run() -> void:
 var rows: Array[Dictionary]=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var colony:=Root.new();colony.simulation=Controller.new()
   var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card108_%s_%d_final.json" % [scenario,seed_value]))
   if not colony.simulation.restore_snapshot(saved): failed=true;colony.free();continue
   # Temporarily stop existing Home effort through its normal physical recall rule.
   colony.set_exploration(0);colony.inward_pile_id="satellite_1"
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"saved_exact":true,"events":[],"captures":{}}
   var entries: Array=colony.daughter_gathering_summary().sources.water
   var source_id: String=entries[0].knowledge_id
   var accepted: bool=false
   for retry: int in 240:
    accepted=colony.daughter_gathering_command(source_id,"scout").accepted
    if accepted: break
    colony.simulation.advance(0.25)
   if not accepted: failed=true;colony.free();continue
   var mission: Dictionary=colony.daughter_source_scout(source_id);var id: String=mission.id
   row.departed_at=colony.simulation.run.simulation_time;row.source=source_id
   var daughter: PileState=colony.simulation.run.colony.piles.satellite_1;row.entrance=daughter.position
   row.saved_exact=checkpoint(colony,row,scenario,seed_value,"outbound")
   for tick: int in 2000:
    if not colony.daughter_source_scout(source_id).awaiting: break
    colony.simulation.advance(0.25)
   mission=colony.daughter_source_scout(source_id)
   row.returned_at=mission.returned_at;row.saved_exact=row.saved_exact and checkpoint(colony,row,scenario,seed_value,"returned")
   var prior: Dictionary=colony.simulation.run.knowledge.temporal_hint(source_id).duplicate(true)
   var refreshed: float=colony.simulation.run.knowledge.nodes[source_id].last_delivered_at
   accepted=colony.daughter_gathering_command(source_id,"scout").accepted
   colony.simulation.advance(1.25)
   var recalled: bool=colony.daughter_gathering_command(source_id,"recall_scout").accepted
   row.saved_exact=row.saved_exact and checkpoint(colony,row,scenario,seed_value,"recall")
   for tick: int in 160:
    if not colony.daughter_source_scout(source_id).awaiting: break
    colony.simulation.advance(0.25)
   row.early_recall_kept_memory=prior==colony.simulation.run.knowledge.temporal_hint(source_id) and refreshed==colony.simulation.run.knowledge.nodes[source_id].last_delivered_at
   row.final={"local_mission":colony.daughter_source_scout(source_id),"daughter_workers":daughter.workers_total,"daughter_losses":daughter.workers.lost_total,"home_losses":colony.simulation.run.colony.piles.home.workers.lost_total,"local_awaiting":colony.inward_status("satellite_1").active_scouts}
   row.passed=row.saved_exact and row.returned_at>=row.departed_at and row.early_recall_kept_memory and accepted and recalled and not row.final.local_mission.awaiting
   failed=failed or not row.passed;rows.append(row);print("[DAUGHTER-SCOUT] ",row)
   colony.free()
 FileAccess.open("res://.godot/card109_scouts.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)

func checkpoint(colony: Node,row: Dictionary,scenario: String,seed_value: int,phase: String) -> bool:
 var record: Dictionary=colony.simulation.run.to_dict();var twin:=Controller.new()
 FileAccess.open("res://.godot/card109_%s_%d_%s.json" % [scenario,seed_value,phase],FileAccess.WRITE).store_string(JSON.stringify(record))
 row.captures[phase]=colony.simulation.run.simulation_time
 if not twin.restore_snapshot(JSON.parse_string(JSON.stringify(record))): return false
 for tick: int in 4:
  colony.simulation.advance(0.25);twin.advance(0.25)
  if colony.simulation.run.to_dict()!=twin.run.to_dict(): return false
 return true
