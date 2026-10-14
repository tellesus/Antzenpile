extends SceneTree
const Root=preload("res://src/core/game_root.gd")
var failed: bool=false
func _initialize() -> void: call_deferred("run_probe")
func capture(name: String) -> void:
 for frame: int in 8: await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://.godot/card106_"+name+".png")
func click(view: Node2D, at: Vector2, touch: bool) -> void:
 var event: InputEvent=InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
 event.position=at;event.pressed=true
 if event is InputEventMouseButton: event.button_index=MOUSE_BUTTON_LEFT
 view._unhandled_input(event)
func run_probe() -> void:
 var colony:=Root.new();get_root().add_child(colony)
 for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
  DisplayServer.window_set_size(size)
  var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card105_backyard_slice_482817_short.json"))
  if not colony.simulation.restore_snapshot(saved): quit(1);return
  colony.simulation.toggle_pause();colony.inspect_pile("home")
  var inward: InwardView=colony._inward_view
  var positions: Dictionary=InwardView.positions(inward.get_viewport_rect().size)
  click(inward,positions.entrance,size.x==900)
  await capture("assign_%d" % size.x)
  var home: PileState=colony.simulation.run.colony.piles.home;var available: int=home.workers_available
  click(inward,inward._supply_rect().get_center(),size.x==900)
  await capture("ordered_%d" % size.x)
  failed=failed or colony.simulation.run.supply.phase!="waiting" or not colony.simulation.run.supply.enabled or home.workers_available!=available-8
  for phase: String in ["outbound","returning"]:
   saved=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card106_backyard_slice_482817_%s.json" % phase))
   if not colony.simulation.restore_snapshot(saved): quit(1);return
   colony.simulation.toggle_pause();await capture("%s_%d" % [phase,size.x])
   failed=failed or inward._status.supply.status!="away"
  var assigned: int=colony.simulation.run.colony.piles.home.workers_available
  click(inward,inward._supply_rect().get_center(),size.x==900)
  await capture("stopping_%d" % size.x)
  failed=failed or colony.simulation.run.supply.enabled or colony.simulation.run.colony.piles.home.workers_available!=assigned
  click(inward,inward._pile_rect().get_center(),size.x==900)
  var frozen: Dictionary=colony.simulation.run.to_dict()
  click(inward,positions.food_exchange,size.x==900)
  await capture("shortage_%d" % size.x)
  click(inward,inward._supply_link_rect().get_center(),size.x==900)
  await capture("daughter_supply_%d" % size.x)
  failed=failed or inward.selected_id!="entrance" or colony.simulation.run.to_dict()!=frozen
  saved=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card106_backyard_slice_482817_developed.json"))
  if not colony.simulation.restore_snapshot(saved): quit(1);return
  colony.simulation.toggle_pause();colony.inspect_pile("satellite_1")
  click(inward,positions.nursery,size.x==900)
  await capture("developed_%d" % size.x)
  var parent_care: int=colony.simulation.run.colony.piles.home.humidity.carers
  click(inward,inward._humidity_rect(1).get_center(),size.x==900)
  await capture("cared_%d" % size.x)
  failed=failed or colony.simulation.run.colony.piles.satellite_1.humidity.carers!=1 or colony.simulation.run.colony.piles.home.humidity.carers!=parent_care
  failed=failed or inward._status.brood_matured_total!=8 or inward._status.nursery_state!="developed"
 print("[SUPPLY-UI] actual mouse/touch assignment, private away report, deferred stop, shortage link and developed daughter; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
