extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_daughter_return_supplies.gd")
const Snapshot = preload("res://tests/test_adaptation_queue.gd")
var failures: int = 0
func _initialize(): go.call_deferred()
func press(view: InwardView, point: Vector2, touch: bool):
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position=point;event.pressed=true
	if event is InputEventMouseButton: event.button_index=MOUSE_BUTTON_LEFT
	view._unhandled_input(event);view._process(0)
func capture(label: String, width: int):
	for frame: int in 10: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card131_%s_%d.png" % [label,width]) != OK: failures+=1
func go():
	var root:=Root.new();get_root().add_child(root);root.set_process(false)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		if not root.simulation.restore_snapshot(Snapshot.new().snapshot(Fixture.new().fixture())): failures+=1
		root._refresh_loaded_views();root.inspect_pile("satellite_1")
		var view: InwardView=root._inward_view;view.selected_id="entrance";view._process(0)
		await capture("daughter_ready",size.x)
		press(view,view._supply_rect().get_center(),size.x==900)
		if root.simulation.run.daughter_supply.phase!="waiting" or root.simulation.run.supply.phase!="none":failures+=1
		root.simulation.advance(1);view._process(0)
		await capture("daughter_away",size.x)
		press(view,view._supply_rect().get_center(),size.x==900)
		if root.simulation.run.daughter_supply.enabled:failures+=1
		root.simulation.advance(120);view._process(0)
		if root.simulation.run.daughter_supply.trips_reported!=1:failures+=1
		await capture("daughter_return",size.x)
		root.simulation.start_brood("satellite_1");root.simulation.advance(210)
		view.selected_id="food_exchange";view._process(0)
		press(view,view._supply_link_rect().get_center(),size.x==900)
		if root.inward_pile_id != "home" or view.selected_id != "entrance": failures+=1
		await capture("home_ready",size.x)
		press(view,view._supply_rect().get_center(),size.x==900)
		if not root.simulation.run.supply.enabled or root.simulation.run.daughter_supply.enabled:failures+=1
	print("[REVERSE SUPPLY UI] eight named-direction actual-input ready/away/return/Home captures; failures=",failures)
	root.free();await create_timer(0.3).timeout;quit(1 if failures else 0)
