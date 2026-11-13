extends "res://tests/evaluate_reproduction.gd"
func _run() -> void:
 var rows: Array[Dictionary]=[]
 for scenario: String in ["backyard_slice","garden_edge"]:
  for seed_value: int in [482817,591]:
   var colony:=Root.new();colony.simulation=Controller.new()
   var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card105_%s_%d_short.json" % [scenario,seed_value]))
   var row: Dictionary={"scenario":scenario,"seed":seed_value,"events":[],"captures":{},"saved_exact":true,"first_emerged_at":-1.0}
   if not colony.simulation.restore_snapshot(saved): failed=true;colony.free();continue
   colony.set_daughter_supply(true)
   var start: float=colony.simulation.run.simulation_time
   row.support_at=start
   var daughter: PileState=colony.simulation.run.colony.piles.satellite_1
   while colony.simulation.run.simulation_time<start+1400:
    if colony.simulation.run.clock.tick_count%20==0:
     colony.inward_pile_id="home";paid_policy(colony,row)
     colony.inward_pile_id="satellite_1"
     if daughter.brood_matured_total>=8 and row.first_emerged_at<0: row.first_emerged_at=colony.simulation.run.simulation_time
     if row.first_emerged_at>0:
      if daughter.food_exchange_state=="primitive": colony.start_food_exchange()
      if daughter.nursery_state=="primitive" and daughter.food_exchange_state=="developed": colony.start_nursery_development()
      if daughter.midden.revealed: colony.set_sanitation_workers(1)
      if daughter.nursery_state=="developed": colony.set_humidity_workers(1)
    colony.simulation.advance(0.25)
    var state: InterpileSupplyState=colony.simulation.run.supply
    var checkpoint: String=state.phase
    if daughter.food_exchange_state=="developed" and daughter.nursery_state=="developed": checkpoint="developed"
    if not row.captures.has(checkpoint):
     row.captures[checkpoint]=colony.simulation.run.simulation_time
     var record: Dictionary=colony.simulation.run.to_dict();var twin:=Controller.new()
     FileAccess.open("res://.godot/card106_%s_%d_%s.json" % [scenario,seed_value,checkpoint],FileAccess.WRITE).store_string(JSON.stringify(record))
     var exact: bool=twin.restore_snapshot(JSON.parse_string(JSON.stringify(record)))
     for tick: int in 40:
      colony.simulation.advance(0.25);twin.advance(0.25);exact=exact and colony.simulation.run.to_dict()==twin.run.to_dict()
     row.saved_exact=row.saved_exact and exact
    if checkpoint=="developed": break
   row.final={"daughter_workers":daughter.workers_total,"daughter_emerged":daughter.brood_matured_total,"daughter_losses":daughter.workers.lost_total,"daughter_stores":daughter.resources.duplicate(),"nursery":daughter.nursery_state,"exchange":daughter.food_exchange_state,"returned_trips":colony.simulation.run.supply.trips_reported,"reported_supplies":colony.simulation.run.supply.delivered_units.duplicate(),"parent_workers":colony.simulation.run.colony.piles.home.workers_total,"parent_available":colony.simulation.run.colony.piles.home.workers_available}
   row.passed=row.saved_exact and row.first_emerged_at>0 and daughter.food_exchange_state=="developed" and daughter.nursery_state=="developed" and daughter.workers.invariant_holds()
   failed=failed or not row.passed;rows.append(row);print("[SUPPLIED-DAUGHTER] ",row)
   colony.free()
 FileAccess.open("res://.godot/card106_supply.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
