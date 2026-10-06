extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Impact = preload("res://tests/test_surface_disturbance.gd")
const Parent = preload("res://tests/test_parent_supply.gd")
const Snapshot = preload("res://tests/test_adaptation_queue.gd")
var failures: int = 0

func _initialize(): go.call_deferred()
func press(at: Vector2, touch: bool) -> void:
	for down: bool in [true,false]:
		var event: InputEvent
		if touch:
			event=InputEventScreenTouch.new();event.index=0
		else:
			event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		event.position=at;event.pressed=down;get_root().push_input(event,true)
		await process_frame
func capture(tag: String, width: int):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/card133_%s_%d.png"%[tag,width])
func check(ok: bool, text: String):
	if not ok: failures+=1;printerr("FAIL UI: "+text)
func go():
	var root = Root.new();get_root().add_child(root)
	root.set_process(false)
	root.save_service=SaveService.new("res://.godot/card133-ui-slot.json")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		get_root().content_scale_size=size
		DisplayServer.window_set_size(size)
		await process_frame;await process_frame
		var source := Impact.new().returned(71)
		check(root.simulation.restore_snapshot(Snapshot.new().snapshot(source)),"Real exposed-route colony restores")
		root._refresh_loaded_views();root.simulation.run.clock.paused=true
		var saved: Dictionary = root.simulation.run.to_dict()
		check(root.quick_save().accepted,"Probe saves its isolated slot")
		var disk: String = FileAccess.get_file_as_string(root.save_service.path)
		var menu: ColonyControls = root._colony_controls
		await press(menu.button_rect().get_center(),size.x==900)
		await press(menu.choice_rect("end").get_center(),size.x==900)
		check(menu.confirm_end and not root.simulation.run.history.ended and root.simulation.review_snapshot().is_empty(),"Confirmation exposes no truth")
		await capture("confirm",size.x)
		await press(menu.choice_rect("cancel").get_center(),size.x==900)
		check(root.simulation.run.to_dict()==saved and not menu.confirm_end,"Cancel preserves exact paused run")
		await press(menu.choice_rect("end").get_center(),size.x==900)
		await press(menu.choice_rect("repeat").get_center(),size.x==900)
		var view: RunReview = root._review
		check(view.visible and root.mode=="review" and root.simulation.run.history.ended and not root._outward_view.visible,"Confirm opens exclusive ended-run reveal")
		check(FileAccess.get_file_as_string(root.save_service.path)==disk,"Review never overwrites previous save")
		await capture("final",size.x)
		var frozen: Dictionary = root.simulation.run.to_dict()
		await press(view.button_rect("first").get_center(),size.x==900)
		check(view.cursor==0 and root.simulation.run.to_dict()==frozen,"First is historical, without simulation mutation")
		await capture("first",size.x)
		await press(view.timeline_rect().position+Vector2(view.timeline_rect().size.x*0.7,22),size.x==900)
		check(view.cursor>0,"Timeline seeks retained historical frames")
		await press(view.button_rect("play").get_center(),size.x==900)
		check(view.playing,"Playback starts independently")
		view._process(5)
		await press(view.button_rect("last").get_center(),size.x==900)
		var frame: Dictionary = view.data.history.frames[view.cursor]
		await press(view._at(frame.nodes[0].position),size.x==900)
		check(view.selected_id==frame.nodes[0].id,"Source inspection selects actual past source")
		await capture("selected",size.x)
		var slot_path: String = root.save_service.path
		root.save_service.path="res://.godot/card133-no-such-save.json"
		await press(view.button_rect("load").get_center(),size.x==900)
		check(view.visible and root.simulation.run.history.ended and not view.feedback.is_empty(),"Failed load remains in review with readable feedback")
		root.save_service.path=slot_path
		await press(view.button_rect("load").get_center(),size.x==900)
		check(not root.simulation.run.history.ended and not view.visible and root._outward_view.visible and root.simulation.run.to_dict()==saved,"Explicit saved-slot load returns to unrevealed saved state")
		root.end_run_review()
		await press(view.button_rect("new").get_center(),size.x==900)
		check(not root.simulation.run.history.ended and not view.visible and root.simulation.run.clock.tick_count<10,"New Colony begins a separate private run")
		var daughter := Parent.new().fixture()
		root.simulation.restore_snapshot(Snapshot.new().snapshot(daughter));root._refresh_loaded_views();root.end_run_review()
		check(view.data.history.frames.back().piles.size()==2,"Daughter physical map appears")
		await capture("daughter",size.x)
	print("[REVIEW UI] ten standard/compact actual mouse/touch captures; failures=",failures)
	root.free();await create_timer(0.3).timeout;quit(1 if failures else 0)
