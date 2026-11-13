extends "res://tests/evaluate_reproduction.gd"
func _run() -> void:
 var rows: Array[Dictionary]=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var colony:=Root.new(); colony.simulation=Controller.new(); var row: Dictionary={"scenario":scenario,"seed":seed_value,"saved_exact":true,"passed":false}
   var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card104_%s_%d_ready.json" % [scenario,seed_value]))
   if not colony.simulation.restore_snapshot(baseline): failed=true; colony.free(); continue
   var count: int=colony.simulation.run.colony.workers_total
   var parent: PileState=colony.simulation.run.colony.piles.home
   var available: int=parent.workers_available; var losses: int=parent.workers.lost_total
   var route: TrailRouteState=colony.simulation.run.trails.routes[colony.simulation.run.founding.route_id]
   row.passed=colony.establish_daughter(route.destination_knowledge_id).accepted
   var daughter: PileState=colony.simulation.run.colony.piles.satellite_1
   row.passed=row.passed and parent.workers_available==available and parent.workers.lost_total==losses and colony.simulation.run.colony.workers_total==count
   row.activation={"at":colony.simulation.run.simulation_time,"local_workers":daughter.workers_total,"queens":daughter.queen_count,"stores":daughter.resources.duplicate(),"parent_workers":parent.workers_total,"parent_available":parent.workers_available,"colony_workers":count}
   var initial: Dictionary=colony.simulation.run.to_dict()
   FileAccess.open("res://.godot/card105_%s_%d_established.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(initial))
   colony.start_brood()
   var twin:=Controller.new()
   row.saved_exact=twin.restore_snapshot(JSON.parse_string(JSON.stringify(colony.simulation.run.to_dict())))
   for tick: int in 1200:
    colony.simulation.advance(0.25); twin.advance(0.25)
    row.saved_exact=row.saved_exact and colony.simulation.run.to_dict()==twin.run.to_dict()
   row.local_brood={"cohort":daughter.brood_cohorts[0].to_dict(),"stores":daughter.resources.duplicate(),"emerged":daughter.brood_matured_total}
   row.passed=row.passed and row.saved_exact and daughter.brood_matured_total==0 and daughter.brood_cohorts[0].stage=="larva" and not daughter.brood_cohorts[0].nutrition_shortfalls.is_empty()
   FileAccess.open("res://.godot/card105_%s_%d_short.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(colony.simulation.run.to_dict()))
   rows.append(row); failed=failed or not row.passed
   print("[DAUGHTER] ",row)
   colony.free()
 FileAccess.open("res://.godot/card105_daughter.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
