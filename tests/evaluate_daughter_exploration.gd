extends "res://tests/evaluate_daughter_scouts.gd"
func _run() -> void:
 var rows: Array[Dictionary]=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var colony:=Root.new();colony.simulation=Controller.new()
   if not colony.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card108_%s_%d_final.json" % [scenario,seed_value]))):failed=true;colony.free();continue
   colony.set_exploration(2);colony.inspect_outward_pile("satellite_1");colony.set_exploration(2);colony.toggle_investigation_priority("known:water_01")
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"saved_exact":true,"max_active":0}
   var twin:=Controller.new();row.saved_exact=twin.restore_snapshot(JSON.parse_string(JSON.stringify(colony.simulation.run.to_dict())))
   var delivered: int=colony.simulation.run.next_scout_id
   for tick: int in 4800:
    colony.simulation.advance(0.25);twin.advance(0.25)
    row.saved_exact=row.saved_exact and colony.simulation.run.to_dict()==twin.run.to_dict();row.max_active=maxi(row.max_active,colony.simulation.run.active_scout_count())
   row.new_departures=colony.simulation.run.next_scout_id-delivered
   row.home_coverage=colony.simulation.run.exploration.coverage.size();row.daughter_coverage=colony.simulation.run.daughter_exploration.coverage.size();row.local_away=colony.simulation.scouting.standing_count("satellite_1")
   row.daughter_losses=colony.simulation.run.scout_losses.get("satellite_1",0);row.home_losses=colony.simulation.run.scout_losses.get("home",0)
   row.final_workers=colony.simulation.run.colony.piles.satellite_1.workers_total
   row.passed=row.saved_exact and row.max_active<=8 and row.home_coverage>0 and row.daughter_coverage>0 and row.local_away>0 and row.new_departures>4
   failed=failed or not row.passed;rows.append(row);print("[DAUGHTER-EFFORT] ",row);colony.free()
 FileAccess.open("res://.godot/card111_exploration.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"));quit(1 if failed else 0)
