extends "res://tests/evaluate_daughter_scouts.gd"
func _run() -> void:
 var rows: Array[Dictionary]=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var colony:=Root.new();colony.simulation=Controller.new()
   if not colony.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card108_%s_%d_final.json" % [scenario,seed_value]))): failed=true;colony.free();continue
   colony.set_exploration(0);colony.simulation.advance(60);colony.inspect_outward_pile("satellite_1")
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"saved_exact":true,"passed":true}
   var dispatched: bool=colony.dispatch_facing(0.0)
   var id: String="scout_%d" % (colony.simulation.run.next_scout_id-1)
   row.departed_at=colony.simulation.run.simulation_time
   var twin:=Controller.new();row.saved_exact=twin.restore_snapshot(JSON.parse_string(JSON.stringify(colony.simulation.run.to_dict())))
   for tick: int in 4800:
    if not colony.simulation.run.scouts.has(id): break
    colony.simulation.advance(0.25);twin.advance(0.25)
    row.saved_exact=row.saved_exact and colony.simulation.run.to_dict()==twin.run.to_dict()
    # Manual search can continue until new evidence/exhaustion. Recall deliberately at ten minutes.
    if tick==2399:
     var request: Dictionary=colony.recall_scout(id);twin.recall_scout(id);row.recalled=request.accepted
   var memory: ScoutMissionMemory=colony.simulation.run.scout_missions.get(id)
   row.returned_at=memory.returned_at;row.missing_at=memory.missing_at;row.dispatched=dispatched;row.local_missions=colony.focused_outward_status().scout_missions.size()
   var entries: Array=colony.daughter_gathering_summary().sources.water
   var source_id: String=entries[0].knowledge_id;var route: TrailRouteState=colony.simulation.run.trails.find_route("satellite_1",source_id)
   row.gathering_order=colony.set_trail_target(route.id,route.desired_workers+1).accepted if route!=null else colony.create_trail_for(source_id).accepted
   twin=Controller.new();row.saved_exact=row.saved_exact and twin.restore_snapshot(JSON.parse_string(JSON.stringify(colony.simulation.run.to_dict())))
   for tick: int in 480:
    colony.simulation.advance(0.25);twin.advance(0.25);row.saved_exact=row.saved_exact and colony.simulation.run.to_dict()==twin.run.to_dict()
   row.passed=dispatched and row.gathering_order and row.saved_exact and memory.completed_at()>=0
   row.final_workers=colony.simulation.run.colony.piles.satellite_1.workers_total
   failed=failed or not row.passed;rows.append(row);print("[DAUGHTER-OUTWARD] ",row);colony.free()
 FileAccess.open("res://.godot/card110_outward.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
