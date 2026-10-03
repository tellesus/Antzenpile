extends "res://tests/probe_parent_supply.gd"

func capture(name: String) -> void:
 for frame: int in 8: await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card107_"+name+".png")

func run_probe() -> void:
 var colony:=Root.new();get_root().add_child(colony)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card107_garden_edge_591_stopped_pressure.json"))
  if not colony.simulation.restore_snapshot(saved): quit(1);return
  colony.simulation.toggle_pause();colony.set_mode("outward")
  var outward: OutwardView=colony._outward_view;var inward: InwardView=colony._inward_view
  outward._process(0);var before: Dictionary=colony.simulation.run.to_dict()
  await capture("shortage_%d" % size.x)
  click(outward,outward._button_rect("daughter_pressure").get_center(),size.x==900)
  await capture("daughter_%d" % size.x)
  failed=failed or colony.inward_pile_id!="satellite_1" or inward.selected_id!="nursery" or before!=colony.simulation.run.to_dict()
  colony.inspect_pile("home");await capture("home_%d" % size.x)
  click(inward,inward._pile_rect().get_center(),size.x==900)
  failed=failed or inward.selected_id!="nursery" or colony.inward_pile_id!="satellite_1" or before!=colony.simulation.run.to_dict()
  saved=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card107_backyard_slice_482817_stopped_final.json"))
  if not colony.simulation.restore_snapshot(saved): quit(1);return
  colony.simulation.toggle_pause();colony.inspect_pile("home")
  await capture("reserve_home_%d" % size.x)
  before=colony.simulation.run.to_dict();click(inward,inward._pile_rect().get_center(),size.x==900)
  await capture("reserve_queen_%d" % size.x)
  failed=failed or colony.inward_pile_id!="satellite_1" or inward.selected_id!="queen" or before!=colony.simulation.run.to_dict()
 print("[DAUGHTER-ATTENTION-UI] actual mouse/touch, named local shortage and conservative reserve wait; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
