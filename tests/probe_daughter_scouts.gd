extends "res://tests/probe_parent_supply.gd"

func capture(name: String) -> void:
 for frame: int in 8: await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card109_"+name+".png")

func run_probe() -> void:
 var colony:=Root.new();get_root().add_child(colony)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card108_backyard_slice_482817_final.json"))
  if not colony.simulation.restore_snapshot(saved): quit(1);return
  colony.set_exploration(0);colony.simulation.advance(60);colony.simulation.toggle_pause();colony.inspect_pile("satellite_1")
  var view: InwardView=colony._inward_view;var logical: Vector2=view.get_viewport_rect().size
  click(view,InwardView.positions(logical).food_exchange,size.x==900)
  click(view,view._gather_link_rect().get_center(),size.x==900)
  click(view,view.gathering.rect(logical,"filter",2).get_center(),size.x==900)
  click(view,view.gathering.rect(logical,"row",0).get_center(),size.x==900)
  await capture("dispatch_%d" % size.x)
  var parent: int=colony.simulation.run.colony.piles.home.workers_available
  var daughter: int=colony.simulation.run.colony.piles.satellite_1.workers_available
  click(view,view.gathering.rect(logical,"scout").get_center(),size.x==900)
  await capture("awaiting_%d" % size.x)
  failed=failed or colony.simulation.run.colony.piles.home.workers_available!=parent or colony.simulation.run.colony.piles.satellite_1.workers_available!=daughter-1
  colony.simulation.run.clock.paused=false;colony.simulation.advance(1.25);colony.simulation.run.clock.paused=true;view._process(0)
  daughter=colony.simulation.run.colony.piles.satellite_1.workers_available
  click(view,view.gathering.rect(logical,"scout").get_center(),size.x==900)
  await capture("recall_%d" % size.x)
  failed=failed or colony.simulation.run.colony.piles.satellite_1.workers_available!=daughter
  colony.simulation.run.clock.paused=false;colony.simulation.advance(20);colony.simulation.run.clock.paused=true;view._process(0)
  await capture("returned_%d" % size.x)
  failed=failed or colony.daughter_source_scout(view.gathering.selected).awaiting
 print("[DAUGHTER-SCOUT-UI] actual mouse/touch dispatch, elapsed awaiting, physical recall and returned memory; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
