extends SceneTree
const Root=preload("res://src/core/game_root.gd")
var failed: bool=false
func _initialize():call_deferred("go")
func press(controls: ColonyControls, at: Vector2, touch: bool) -> void:
 var event: InputEvent=InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
 event.position=at;event.pressed=true
 if event is InputEventMouseButton:event.button_index=MOUSE_BUTTON_LEFT
 controls._input(event)
func go():
 var colony:=Root.new();get_root().add_child(colony);colony.set_process(false);colony.simulation.toggle_pause()
 var controls: ColonyControls=colony._colony_controls;var frozen: Dictionary=colony.simulation.run.to_dict()
 for mode: String in ["inward","outward"]:
  colony.set_mode(mode)
  for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
   DisplayServer.window_set_size(size)
   for frame: int in 3:await process_frame
   press(controls,controls.help_button_rect().get_center(),size.x==900)
   for page: int in ColonyControls.GUIDE.size():
    if page in [3,4]:
     for frame: int in 4:await process_frame
     await RenderingServer.frame_post_draw
     failed=failed or get_root().get_texture().get_image().save_png("res://.godot/card117_%s_%d_%d.png" % [mode,size.x,page])!=OK
    press(controls,controls.guide_rect("next").get_center(),size.x==900)
   failed=failed or controls.guide_page!=0 or colony.simulation.run.to_dict()!=frozen
   press(controls,controls.guide_rect("back").get_center(),size.x==900)
   failed=failed or controls.opened or colony.interaction_blocked()
 print("[NETWORK-HELP] six pages, both views/sizes, actual mouse/touch wrap and close; unchanged simulation; passed=",not failed)
 colony.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
