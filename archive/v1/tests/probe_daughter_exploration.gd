extends "res://tests/probe_parent_supply.gd"
func capture(name: String) -> void:
 for frame: int in 8: await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card111_"+name+".png")
func run_probe() -> void:
 var colony:=Root.new();get_root().add_child(colony)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  if not colony.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card108_backyard_slice_482817_final.json"))):quit(1);return
  colony.inward_pile_id="home";colony.set_exploration(5);colony.simulation.toggle_pause();colony.inspect_outward_pile("satellite_1")
  var view: OutwardView=colony._outward_view
  click(view,view._button_rect("scout").get_center(),size.x==900)
  click(view,view._exploration_rect("explore_2").get_center(),size.x==900);await capture("effort_%d" % size.x)
  failed=failed or colony.simulation.run.daughter_exploration.target!=2 or colony.simulation.run.exploration.target!=5
  var frozen: Dictionary=colony.simulation.run.to_dict()
  click(view,view._exploration_rect("explore_8").get_center(),size.x==900);await capture("limit_%d" % size.x)
  failed=failed or frozen!=colony.simulation.run.to_dict() or not view._feedback.contains("other pile")
  view.facing=1.2;click(view,view._exploration_rect("exploration_bias").get_center(),size.x==900)
  failed=failed or not is_equal_approx(colony.simulation.run.daughter_exploration.bias,1.2) or colony.simulation.run.exploration.bias!=frozen.exploration.bias
  click(view,view._button_rect("scout").get_center(),size.x==900)
  colony.simulation.run.clock.paused=false;colony.simulation.advance(10);colony.simulation.run.clock.paused=true;view._process(0)
  failed=failed or colony.simulation.scouting.standing_count("satellite_1")!=2 or colony.simulation.run.active_scout_count()>8
  click(view,view._button_rect("sources").get_center(),size.x==900);click(view,view._source_filter_rect("water").get_center(),size.x==900);click(view,view._source_row_rect(0).get_center(),size.x==900)
  click(view,view._investigate_button_rect().get_center(),size.x==900);await capture("priority_%d" % size.x)
  failed=failed or "known:water_01" not in colony.simulation.run.daughter_exploration.priorities or colony.simulation.run.exploration.priorities!=frozen.exploration.priorities
  click(view,view._button_rect("scout").get_center(),size.x==900);click(view,view._exploration_rect("explore_0").get_center(),size.x==900);await capture("off_%d" % size.x)
  failed=failed or colony.simulation.run.daughter_exploration.target!=0 or colony.simulation.run.exploration.target!=5
 print("[DAUGHTER-EFFORT-UI] actual mouse/touch own effort, shared cap rejection, bias, priority and physical Off; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
