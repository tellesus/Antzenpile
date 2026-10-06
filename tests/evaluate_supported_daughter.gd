extends "res://tests/evaluate_reproduction.gd"
const Pressure=preload("res://src/presentation/colony_pressure.gd")

func _run() -> void:
 var rows: Array[Dictionary]=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   for supported: bool in [true,false]:
    var colony:=Root.new();colony.simulation=Controller.new()
    var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card106_%s_%d_developed.json" % [scenario,seed_value]))
    if not colony.simulation.restore_snapshot(saved): failed=true;colony.free();continue
    var row: Dictionary={"scenario":scenario,"seed":seed_value,"supported":supported,"events":[],"saved_exact":true,"pressures":{},"first_growth_at":-1.0}
    var daughter: PileState=colony.simulation.run.colony.piles.satellite_1
    var initial_births: int=daughter.brood_matured_total
    var start: float=colony.simulation.run.simulation_time
    row.start=start
    colony.inward_pile_id="satellite_1";colony.set_brood_intent("grow")
    if not supported:
     colony.set_daughter_supply(false)
     # Deliberate paid manual laying demonstrates the consequence of withdrawing supply.
     colony.start_brood()
    while colony.simulation.run.simulation_time<start+1800:
     if colony.simulation.run.clock.tick_count%20==0:
      colony.inward_pile_id="home";paid_policy(colony,row)
      var summary: Dictionary=colony.inward_status("satellite_1")
      var attention: Dictionary=Pressure.attention(summary)
      if not attention.is_empty():
       var cause: String=" / ".join(attention.causes)
       if not row.pressures.has(cause):
        var home_status: Dictionary=colony.outward_status("home")
        row.pressures[cause]={"at":summary.time,"home_attention":home_status.internal_attention.duplicate(true),"daughter_attention":home_status.daughter_attention.duplicate(true)}
        failed=failed or home_status.daughter_attention.is_empty() or colony.inward_pile_id!="home"
        FileAccess.open("res://.godot/card107_%s_%d_%s_pressure.json" % [scenario,seed_value,"supported" if supported else "stopped"],FileAccess.WRITE).store_string(JSON.stringify(colony.simulation.run.to_dict()))
      colony.inward_pile_id="satellite_1"
      if daughter.midden.revealed:
       colony.set_sanitation_workers(1)
       if daughter.midden.state=="primitive": colony.start_midden()
      if daughter.nursery_state=="developed": colony.set_humidity_workers(1)
      colony.inward_pile_id="home"
     colony.simulation.advance(0.25)
     if daughter.brood_matured_total>initial_births and row.first_growth_at<0: row.first_growth_at=colony.simulation.run.simulation_time
     for pile: PileState in colony.simulation.run.colony.piles.values():
      if not pile.workers.invariant_holds() or pile.resources.values().any(func(value):return value<0): failed=true
     if colony.simulation.run.clock.tick_count%2400==0:
      var record: Dictionary=colony.simulation.run.to_dict();var twin:=Controller.new()
      var exact: bool=twin.restore_snapshot(JSON.parse_string(JSON.stringify(record)))
      if exact:
       for tick: int in 40:
        colony.simulation.advance(0.25);twin.advance(0.25);exact=exact and colony.simulation.run.to_dict()==twin.run.to_dict()
      row.saved_exact=row.saved_exact and exact
    var final: Dictionary=colony.inward_status("satellite_1")
    row.final={"time":final.time,"workers":daughter.workers_total,"emerged":daughter.brood_matured_total,"losses":daughter.workers.lost_total,"brood_losses":daughter.brood_lost_total,"stores":daughter.resources.duplicate(),"production":final.brood_production,"health":final.brood_health,"midden":final.midden,"climate":final.humidity,"parent_workers":colony.simulation.run.colony.piles.home.workers_total,"supply_reports":colony.simulation.run.supply.trips_reported}
    row.passed=row.saved_exact and (not supported or row.first_growth_at>0) and daughter.workers.transferred_in==11 and daughter.workers_total==11+daughter.brood_matured_total-daughter.workers.lost_total
    failed=failed or not row.passed;rows.append(row);print("[SUSTAINED-DAUGHTER] ",row)
    FileAccess.open("res://.godot/card107_%s_%d_%s_final.json" % [scenario,seed_value,"supported" if supported else "stopped"],FileAccess.WRITE).store_string(JSON.stringify(colony.simulation.run.to_dict()))
    colony.free()
 FileAccess.open("res://.godot/card107_review.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
