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
   for reinforced: bool in [false,true]:
    var root:=Root.new();root.simulation=Controller.new();var game: SimulationController=root.simulation
    if not game.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card105_%s_%d_established.json" % [scenario,seed_value]))):quit(1);return
    var d: PileState=game.run.colony.piles.satellite_1;var h: PileState=game.run.colony.piles.home
    var leg: int=game.reinforcement.TRAILS.leg_ticks(h.position.distance_to(d.position));var invariant: int=population(game)
    var expected_migrants: int=8 if reinforced else 0;var accepted: bool=game.send_daughter_workers() if reinforced else true
    var copy:=Controller.new();var exact: bool=copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true)));var conserved: bool=true
    for tick: int in 2*leg:
     game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict();conserved=conserved and population(game)==invariant
    root.inward_pile_id=d.id
    var commands: Array=[]
    commands.append({"job":"exploration 1","accepted":root.set_exploration(1).accepted})
    commands.append({"job":"climate 1","accepted":game.set_humidity_workers(d.id,1)})
    var assigned: int=0
    for source: String in ["known:carb_sheltered","known:water_01","known:protein_01"]:
     var result: Dictionary=root.daughter_gathering_command(source,"gather")
     commands.append({"job":source,"accepted":result.accepted,"reason":result.reason})
     if result.accepted:assigned+=1
    game.set_brood_intent(d.id,"grow")
    exact=exact and copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true)))
    var peak: int=game.run.active_scout_count()
    for tick: int in 1920:
     # Decisions only from approved local attention and returned source summaries.
     if tick%80==0:
      var local: Dictionary=root.inward_status(d.id)
      if local.midden.revealed and local.workers_available>0:
       game.set_sanitation_workers(d.id,1);copy.set_sanitation_workers(d.id,1)
      if tick%480==0:
       for entries: Array in root.daughter_gathering_summary().sources.values():
        for entry: Dictionary in entries:
         if entry.route_status=="depleted" and entry.workers>0:
          root.daughter_gathering_command(entry.knowledge_id,"recheck");copy.recheck_trail(entry.route_id)
     game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict();conserved=conserved and population(game)==invariant;peak=maxi(peak,game.run.active_scout_count())
    var intake: Dictionary={}
    for route: TrailRouteState in game.run.trails.routes.values():
     if route.origin_pile==d.id:intake[route.destination_knowledge_id]=route.delivered_total
    var manual_laying: bool=game.start_brood(d.id);var twin_laying: bool=copy.start_brood(d.id);exact=exact and manual_laying==twin_laying
    var local_end: Dictionary={"workers":d.workers_total,"emerged":d.brood_matured_total,"lost":d.workers.lost_total,"stores":d.resources.duplicate(),"coverage":game.run.daughter_exploration.coverage.size(),"cleaners":d.midden.cleaners,"climate":d.humidity.carers,"brood_started":d.brood_started_total,"attention":root.pile_internal_attention(d.id)}
    FileAccess.open("res://.godot/card116_%s_%d_%s_local.json" % [scenario,seed_value,"reinforced" if reinforced else "baseline"],FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(),"",true,true))
    # Physical resource support remains independent and reusable after migration.
    var reuse: bool=game.set_daughter_supply(true);reuse=reuse and copy.set_daughter_supply(true)
    var before: Dictionary=game.run.to_dict()
    reuse=reuse and not game.send_daughter_workers() and game.run.to_dict()==before
    game.advance(0.25);copy.advance(0.25);reuse=reuse and game.set_daughter_supply(false) and copy.set_daughter_supply(false)
    for tick: int in 2*leg:
     game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict();conserved=conserved and population(game)==invariant
    reuse=reuse and game.run.supply.phase=="none" and game.run.supply.trips_reported==1 and not game.run.reinforcement.active()
    for tick: int in 1920:
     if tick%80==0 and root.inward_status(d.id).midden.revealed and d.workers_available>0:
      game.set_sanitation_workers(d.id,1);copy.set_sanitation_workers(d.id,1)
     game.advance(0.25);copy.advance(0.25);exact=exact and game.run.to_dict()==copy.run.to_dict();conserved=conserved and population(game)==invariant;peak=maxi(peak,game.run.active_scout_count())
    var post_support: Dictionary={"workers":d.workers_total,"emerged":d.brood_matured_total,"started":d.brood_started_total,"cleaners":d.midden.cleaners,"stores":d.resources.duplicate(),"attention":root.pile_internal_attention(d.id),"brood":root.inward_status(d.id).brood}
    FileAccess.open("res://.godot/card116_%s_%d_%s_final.json" % [scenario,seed_value,"reinforced" if reinforced else "baseline"],FileAccess.WRITE).store_string(JSON.stringify(game.run.to_dict(),"",true,true))
    var row: Dictionary={"scenario":scenario,"seed":seed_value,"reinforced":reinforced,"paid_transfer":accepted,"local_duration":480,"post_support_duration":480,"saved_exact":exact,"population_conserved":conserved,"peak_detail":peak,"commands":commands,"initial_local_routes":assigned,"actual_migrants":d.workers.transferred_in-11,"confirmed_migrants":game.reinforcement.summary().reported_workers,"intake":intake,"local_end":local_end,"support_reuse":reuse,"manual_brood_accepted":manual_laying,"post_support":post_support}
    var brood_progressed: bool=post_support.emerged>0 or not post_support.brood.is_empty() and (post_support.brood[0].progress_seconds>0 or post_support.brood[0].stage!="egg")
    row.passed=accepted and exact and conserved and peak<=8 and row.actual_migrants==expected_migrants and row.confirmed_migrants==expected_migrants and h.genetics.exported==d.genetics.imported and reuse and assigned==(3 if reinforced else 2) and manual_laying and brood_progressed==reinforced
    rows.append(row);failed=failed or not row.passed;print("[REINFORCED-DAUGHTER] ",row);root.free()
 FileAccess.open("res://.godot/card116_review.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
 quit(1 if failed else 0)
