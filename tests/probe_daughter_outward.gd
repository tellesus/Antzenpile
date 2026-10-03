extends "res://tests/probe_parent_supply.gd"
func capture(name: String) -> void:
 for frame: int in 8: await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card110_"+name+".png")
func run_probe() -> void:
 var colony:=Root.new();get_root().add_child(colony)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  if not colony.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card108_backyard_slice_482817_final.json"))): quit(1);return
  colony.inward_pile_id="home";colony.set_exploration(0);colony.simulation.advance(60);colony.simulation.toggle_pause();colony.inspect_outward_pile("home")
  var view: OutwardView=colony._outward_view
  var frozen: Dictionary=colony.simulation.run.to_dict()
  click(view,view._button_rect("pile").get_center(),size.x==900);await capture("daughter_%d" % size.x)
  failed=failed or colony.inward_pile_id!="satellite_1" or view._status.pile_name!="Daughter" or frozen!=colony.simulation.run.to_dict()
  var parent: int=colony.simulation.run.colony.piles.home.workers_available;var local: int=colony.simulation.run.colony.piles.satellite_1.workers_available
  click(view,view._button_rect("scout").get_center(),size.x==900);await capture("search_%d" % size.x)
  var id: String="scout_%d" % (colony.simulation.run.next_scout_id-1)
  failed=failed or view.exploration_open or colony.simulation.run.scouts[id].origin_pile!="satellite_1" or colony.simulation.run.colony.piles.home.workers_available!=parent or colony.simulation.run.colony.piles.satellite_1.workers_available!=local-1
  view.selected_id="mission:"+id;view._process(0)
  click(view,view._scout_recall_rect().get_center(),size.x==900);await capture("recall_%d" % size.x)
  click(view,view._button_rect("sources").get_center(),size.x==900)
  click(view,view._source_filter_rect("water").get_center(),size.x==900);await capture("memories_%d" % size.x)
  click(view,view._source_row_rect(0).get_center(),size.x==900);await capture("water_%d" % size.x)
  failed=failed or view._selected_signal().category!="water" or not view._investigation_title(view._selected_signal()).begins_with("SEND SCOUT")
  var route: Dictionary=view._selected_route(view._selected_signal());var target: int=route.get("desired_workers",0)
  click(view,view._trail_button_rect("trail_recheck" if route.status=="depleted" else "trail_more").get_center(),size.x==900);await capture("gathering_%d" % size.x)
  failed=failed or view._selected_route(view._selected_signal()).status!="active" or (route.status!="depleted" and view._selected_route(view._selected_signal()).desired_workers<=target) or colony.simulation.run.colony.piles.home.workers_available!=parent
  frozen=colony.simulation.run.to_dict()
  click(view,view._button_rect("inward").get_center(),size.x==900);failed=failed or colony.inward_pile_id!="satellite_1" or colony.mode!="inward"
  colony.set_mode("outward");click(view,view._button_rect("pile").get_center(),size.x==900);await capture("home_%d" % size.x)
  failed=failed or colony.inward_pile_id!="home" or frozen!=colony.simulation.run.to_dict() or not view.selected_id.is_empty()
 print("[DAUGHTER-OUTWARD-UI] actual mouse/touch pile switch, local new-source dispatch, recall, remembered water and local gathering; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
