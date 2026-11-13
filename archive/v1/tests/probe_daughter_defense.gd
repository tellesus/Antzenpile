extends "res://tests/probe_parent_supply.gd"
func capture(name: String) -> void:
 for frame: int in 8:await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card113_"+name+".png")
func run_probe() -> void:
 var root:=Root.new();get_root().add_child(root)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card113_backyard_slice_482817_ready.json"))):quit(1);return
  root.inspect_outward_pile("satellite_1");root.simulation.run.clock.paused=true
  var view: OutwardView=root._outward_view;view.journey_open=false;view.selected_id="threat:route_9";view._process(0)
  await capture("ready_%d" % size.x)
  click(view,view._journey_rect("journey_defend").get_center(),size.x==900)
  failed=failed or root.simulation.run.journey_response.defense.mode!="defend"
  root.simulation.run.clock.paused=false;root.simulation.advance(5);root.simulation.run.clock.paused=true;view._process(0)
  click(view,view._journey_rect("journey_defend").get_center(),size.x==900)
  failed=failed or root.simulation.run.journey_response.defense.extra_workers!=4
  await capture("reinforced_%d" % size.x)
  click(view,view._journey_rect("journey_investigate").get_center(),size.x==900)
  failed=failed or root.simulation.run.journey_response.phase!="inbound"
  root.simulation.run.clock.paused=false
  while root.simulation.run.journey_response.active():root.simulation.advance(0.25)
  failed=failed or root.simulation.run.journey_response.defense.outcomes.route_9.outcome!="withdrew"
  if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card113_backyard_slice_482817_returned.json"))):quit(1);return
  root.simulation.run.clock.paused=true;view._process(0);await capture("returned_%d" % size.x)
  failed=failed or view._can_mobilize({"id":"route_9"}) or root.simulation.run.journey_response.defense.outcomes.route_9.outcome!="secured"
 print("[DAUGHTER-DEFENSE-UI] actual mouse/touch local mobilization/reinforce/recall/returned outcome 1280/900; passed=",not failed)
 root.queue_free();await create_timer(0.3).timeout;quit(1 if failed else 0)
