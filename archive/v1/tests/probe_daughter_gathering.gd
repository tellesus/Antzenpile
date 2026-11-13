extends "res://tests/probe_parent_supply.gd"

func capture(name: String) -> void:
 for frame: int in 8: await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card108_"+name+".png")

func run_probe() -> void:
 var colony:=Root.new();get_root().add_child(colony)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card107_backyard_slice_482817_supported_final.json"))
  if not colony.simulation.restore_snapshot(saved): quit(1);return
  colony.simulation.toggle_pause();colony.inspect_pile("satellite_1")
  var view: InwardView=colony._inward_view
  var logical: Vector2=view.get_viewport_rect().size
  click(view,InwardView.positions(logical).food_exchange,size.x==900)
  await capture("exchange_%d" % size.x)
  var before: Dictionary=colony.simulation.run.to_dict()
  click(view,view._gather_link_rect().get_center(),size.x==900)
  await capture("memories_%d" % size.x)
  failed=failed or not view.gathering.opened or before!=colony.simulation.run.to_dict()
  click(view,view.gathering.rect(logical,"row",0).get_center(),size.x==900)
  click(view,view.gathering.rect(logical,"page").get_center(),size.x==900)
  await capture("next_page_%d" % size.x)
  failed=failed or view.gathering.page!=1 or not view.gathering.selected.is_empty() or before!=colony.simulation.run.to_dict()
  click(view,view.gathering.rect(logical,"page").get_center(),size.x==900)
  click(view,view.gathering.rect(logical,"row",0).get_center(),size.x==900)
  await capture("selected_%d" % size.x)
  var home: int=colony.simulation.run.colony.piles.home.workers_available
  var daughter: int=colony.simulation.run.colony.piles.satellite_1.workers_available
  click(view,view.gathering.rect(logical,"order").get_center(),size.x==900)
  await capture("assigned_%d" % size.x)
  failed=failed or colony.simulation.run.colony.piles.home.workers_available!=home or colony.simulation.run.colony.piles.satellite_1.workers_available!=daughter-5
  colony.simulation.run.clock.paused=false;colony.simulation.advance(0.25);colony.simulation.run.clock.paused=true;view._process(0)
  daughter=colony.simulation.run.colony.piles.satellite_1.workers_available
  click(view,view.gathering.rect(logical,"stop").get_center(),size.x==900)
  await capture("recalled_%d" % size.x)
  failed=failed or colony.simulation.run.colony.piles.satellite_1.workers_available!=daughter
  before=colony.simulation.run.to_dict()
  click(view,view.gathering.rect(logical,"filter",2).get_center(),size.x==900)
  await capture("water_%d" % size.x)
  failed=failed or view.gathering.category!="water" or not view.gathering.selected.is_empty() or before!=colony.simulation.run.to_dict()
  click(view,view.gathering.rect(logical,"back").get_center(),size.x==900)
  failed=failed or view.gathering.opened
  colony.inspect_pile("home")
  failed=failed or view.gathering.opened or colony.inward_pile_id!="home"
  saved=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card107_garden_edge_591_stopped_pressure.json"))
  if not colony.simulation.restore_snapshot(saved): quit(1);return
  colony.simulation.toggle_pause();colony.inspect_pile("satellite_1")
  click(view,InwardView.positions(logical).food_exchange,size.x==900)
  await capture("shortage_%d" % size.x)
  failed=failed or view._gather_link_rect().intersects(view._supply_link_rect())
  click(view,view._supply_link_rect().get_center(),size.x==900)
  failed=failed or view.selected_id!="entrance"
 print("[DAUGHTER-GATHERING-UI] actual mouse/touch browse, local assignment/recall, filters and reset; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
