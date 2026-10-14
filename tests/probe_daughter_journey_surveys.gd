extends "res://tests/probe_parent_supply.gd"
func capture(name: String) -> void:
 for frame: int in 8:await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card112_"+name+".png")
func run_probe() -> void:
 var root:=Root.new();get_root().add_child(root)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card112_backyard_slice_482817_ready.json"))
  if not root.simulation.restore_snapshot(saved):quit(1);return
  root.inspect_outward_pile("satellite_1");root.simulation.run.clock.paused=true
  var view: OutwardView=root._outward_view;var route_id: String=""
  view.journey_open=false
  for route: TrailRouteState in root.simulation.run.trails.routes.values():
   if route.id=="route_9":route_id=route.id;view.selected_id="signal:"+route.destination_knowledge_id;break
  view._process(0);click(view,view._journey_rect("journey_open").get_center(),size.x==900);await capture("ready_%d" % size.x)
  failed=failed or not view.journey_open
  click(view,view._journey_rect("journey_investigate").get_center(),size.x==900)
  failed=failed or not root.simulation.run.journey_response.active()
  root.simulation.run.clock.paused=false;root.simulation.advance(5);root.simulation.run.clock.paused=true;view._process(0)
  await capture("away_%d" % size.x)
  click(view,view._journey_rect("journey_investigate").get_center(),size.x==900)
  failed=failed or root.simulation.run.journey_response.phase!="inbound"
  root.simulation.run.clock.paused=false
  while root.simulation.run.journey_response.active():root.simulation.advance(0.25)
  failed=failed or root.simulation.run.journey_response.reports[route_id].finding!="inconclusive"
  saved=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card112_backyard_slice_482817_returned.json"))
  failed=failed or not root.simulation.restore_snapshot(saved)
  root.simulation.run.clock.paused=true;view._process(0);view.selected_id="threat:"+route_id;await capture("returned_%d" % size.x)
  failed=failed or not view._journey_attention() or not view._can_mobilize({"id":route_id})
 print("[DAUGHTER-SURVEY-UI] actual mouse/touch paid survey/recall/returned threat at 1280/900; passed=",not failed)
 root.queue_free();await create_timer(0.3).timeout;quit(1 if failed else 0)
