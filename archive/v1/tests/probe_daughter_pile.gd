extends SceneTree
const Root=preload("res://src/core/game_root.gd")
var failed: bool=false
func _initialize() -> void: call_deferred("run_probe")
func capture(name: String) -> void:
 for frame: int in 8: await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card105_"+name+".png")
func click(view: Node2D, at: Vector2, touch: bool) -> void:
 var event: InputEvent=InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
 event.position=at;event.pressed=true
 if event is InputEventMouseButton: event.button_index=MOUSE_BUTTON_LEFT
 view._unhandled_input(event)
func run_probe() -> void:
 var colony:=Root.new(); get_root().add_child(colony)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card104_backyard_slice_482817_ready.json"))
  if not colony.simulation.restore_snapshot(saved): quit(1); return
  colony.simulation.toggle_pause(); colony.set_mode("outward")
  var outward: OutwardView=colony._outward_view;outward.sources_open=false;outward._feedback=""
  for signal_data: Dictionary in colony.sensory_snapshot("home"):
   if signal_data.category=="nest_site": outward.selected_id=signal_data.id;outward.facing=signal_data.bearing
  await capture("camp_%d" % size.x)
  click(outward,outward._founding_rect().get_center(),size.x==900)
  await capture("network_%d" % size.x)
  failed=failed or colony.mode!="inward" or colony.inward_pile_id!="satellite_1" or colony.simulation.run.founding.phase!="established"
  var inward: InwardView=colony._inward_view
  var positions: Dictionary=InwardView.positions(inward.get_viewport_rect().size)
  click(inward,positions.queen,size.x==900)
  await capture("queen_%d" % size.x)
  failed=failed or inward.selected_id!="queen" or not inward._status.daughter or not inward._status.brood.is_empty()
  click(inward,inward._brood_rect().get_center(),size.x==900)
  await capture("laid_%d" % size.x)
  failed=failed or colony.simulation.run.colony.piles.satellite_1.brood_cohorts.size()!=1
  var frozen: Dictionary=colony.simulation.run.to_dict()
  click(inward,inward._pile_rect().get_center(),size.x==900)
  await capture("home_%d" % size.x)
  failed=failed or colony.inward_pile_id!="home" or inward._status.daughter or colony.simulation.run.to_dict()!=frozen
  click(inward,inward._pile_rect().get_center(),size.x==900)
  await capture("return_%d" % size.x)
  failed=failed or colony.inward_pile_id!="satellite_1" or colony.simulation.run.to_dict()!=frozen
  click(inward,positions.adaptation,size.x==900)
  failed=failed or inward.selected_id=="adaptation"
  click(inward,positions.nursery,size.x==900)
  await capture("nursery_%d" % size.x)
  failed=failed or inward.selected_id!="nursery"
  click(inward,inward._button_rect("outward").get_center(),size.x==900)
  failed=failed or colony.inward_pile_id!="home" or colony.mode!="outward"
 print("[DAUGHTER-UI] actual mouse/touch establishment, local brood, free pile inspection, simplified organs and Home outward; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
