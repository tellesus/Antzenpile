extends "res://tests/probe_parent_supply.gd"
func capture(name: String) -> void:
 for frame: int in 8:await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card115_"+name+".png")
func run_probe() -> void:
 var colony:=Root.new();get_root().add_child(colony)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  if not colony.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card113_backyard_slice_482817_returned.json"))):quit(1);return
  colony.simulation.toggle_pause();colony.inspect_pile("home")
  var inward: InwardView=colony._inward_view
  var positions: Dictionary=InwardView.positions(inward.get_viewport_rect().size)
  click(inward,positions.entrance,size.x==900);await capture("ready_%d" % size.x)
  var h: PileState=colony.simulation.run.colony.piles.home;var available: int=h.workers_available
  click(inward,inward._reinforcement_rect().get_center(),size.x==900);await capture("away_%d" % size.x)
  failed=failed or not colony.simulation.run.reinforcement.active() or h.workers_available!=available-9 or inward._status.reinforcement.reported_workers!=0
  # Partial travel, real return command, then exact physical release.
  colony.simulation.toggle_pause();colony.simulation.advance(2.5);colony.simulation.toggle_pause()
  click(inward,inward._reinforcement_rect().get_center(),size.x==900);await capture("return_request_%d" % size.x)
  failed=failed or colony.simulation.run.reinforcement.phase!="returning" or h.workers_available!=available-9
  colony.simulation.toggle_pause();colony.simulation.advance(2.5);colony.simulation.toggle_pause();await capture("recalled_%d" % size.x)
  failed=failed or colony.simulation.run.reinforcement.active() or h.workers_available!=available
  if not colony.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card115_backyard_slice_482817_returned.json"))):quit(1);return
  colony.simulation.toggle_pause();colony.inspect_pile("satellite_1");click(inward,positions.entrance,size.x==900);await capture("returned_%d" % size.x)
  failed=failed or inward._status.reinforcement.reported_workers!=16 or inward._status.reinforcement.last_settled!=0
 print("[REINFORCEMENT-UI] paid dispatch, physical return request and separate settlement history; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
