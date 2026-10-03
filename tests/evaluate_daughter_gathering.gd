extends "res://tests/evaluate_reproduction.gd"

func _run() -> void:
 var rows: Array[Dictionary]=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var colony:=Root.new();colony.simulation=Controller.new()
   var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card107_%s_%d_supported_final.json" % [scenario,seed_value]))
   if not colony.simulation.restore_snapshot(saved): failed=true;colony.free();continue
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"events":[],"saved_exact":true,"captures":{},"deliveries":{}}
   colony.set_daughter_supply(false)
   var start: float=colony.simulation.run.simulation_time;row.start=start
   while colony.simulation.run.simulation_time<start+1200:
    if colony.simulation.run.clock.tick_count%80==0:
     colony.inward_pile_id="home";paid_policy(colony,row)
     colony.inward_pile_id="satellite_1"
     var summary: Dictionary=colony.daughter_gathering_summary()
     var local: Dictionary=colony.inward_status("satellite_1")
     for category: String in ["carbohydrate","protein","water"]:
      var committed: bool=false
      for entry: Dictionary in summary.sources[category]:
       if entry.workers>0:
        committed=true
        if entry.danger: colony.daughter_gathering_command(entry.knowledge_id,"stop")
        elif entry.route_status=="depleted" and colony.simulation.run.clock.tick_count%480==0: colony.daughter_gathering_command(entry.knowledge_id,"recheck")
      if committed or local.workers_available<9: continue
      var entries: Array=summary.sources[category].duplicate()
      # Prefer returned non-empty evidence; no world quantity/path-safety decisions.
      entries.sort_custom(func(a:Dictionary,b:Dictionary):
       if (a.state=="Reported empty")!=(b.state=="Reported empty"):return a.state!="Reported empty"
       return a.knowledge_id<b.knowledge_id)
      for entry: Dictionary in entries:
       if entry.danger: continue
       var request: Dictionary=colony.daughter_gathering_command(entry.knowledge_id,"gather")
       if request.accepted: row.events.append({"at":local.time,"action":"daughter gather "+entry.knowledge_id});break
     colony.inward_pile_id="home"
    colony.simulation.advance(0.25)
    var daughter: PileState=colony.simulation.run.colony.piles.satellite_1
    if not daughter.workers.invariant_holds() or daughter.resources.values().any(func(value):return value<0): failed=true
    for route: TrailRouteState in colony.simulation.run.trails.routes.values():
     if route.origin_pile!="satellite_1": continue
     if route.delivered_total>0: row.deliveries[route.destination_knowledge_id]=route.delivered_total
     var checkpoint: String="receipt" if route.delivered_total>0 else "outbound" if route.active_workers>0 else ""
     if not checkpoint.is_empty() and not row.captures.has(checkpoint):
      row.captures[checkpoint]=colony.simulation.run.simulation_time
      var record: Dictionary=colony.simulation.run.to_dict();var twin:=Controller.new()
      FileAccess.open("res://.godot/card108_%s_%d_%s.json" % [scenario,seed_value,checkpoint],FileAccess.WRITE).store_string(JSON.stringify(record))
      var exact: bool=twin.restore_snapshot(JSON.parse_string(JSON.stringify(record)))
      if exact:
       for tick: int in 40:
        colony.simulation.advance(0.25);twin.advance(0.25);exact=exact and colony.simulation.run.to_dict()==twin.run.to_dict()
      row.saved_exact=row.saved_exact and exact
   var daughter: PileState=colony.simulation.run.colony.piles.satellite_1
   var snapshot: Dictionary=colony.simulation.run.to_dict();var copy:=Controller.new()
   row.saved_exact=row.saved_exact and copy.restore_snapshot(JSON.parse_string(JSON.stringify(snapshot)))
   row.final={"workers":daughter.workers_total,"emerged":daughter.brood_matured_total,"losses":daughter.workers.lost_total,"stores":daughter.resources.duplicate(),"supply_enabled":colony.simulation.run.supply.enabled,"supply_party":colony.simulation.run.supply.phase,"local_routes":colony.trail_summaries("satellite_1")}
   row.passed=row.saved_exact and not row.deliveries.is_empty() and colony.simulation.run.supply.phase=="none"
   failed=failed or not row.passed;rows.append(row);print("[LOCAL-DAUGHTER-GATHERING] ",{"scenario":scenario,"seed":seed_value,"deliveries":row.deliveries,"workers":daughter.workers_total,"lost":daughter.workers.lost_total,"exact":row.saved_exact,"passed":row.passed})
   FileAccess.open("res://.godot/card108_%s_%d_final.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(snapshot))
   colony.free()
 FileAccess.open("res://.godot/card108_gathering.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
