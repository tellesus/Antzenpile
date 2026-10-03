extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_adaptation_queue.gd")
const Recognition = preload("res://tests/test_recognition.gd")
var failed: bool = false
var game_root: Node

func _initialize(): _run.call_deferred()

func _run():
	game_root = Root.new(); get_root().add_child(game_root); game_root.set_process(false); game_root.set_mode("inward")
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		game_root.simulation = Fixture.new().funded(false)
		game_root.simulation.toggle_pause(); game_root._refresh_loaded_views()
		var view: InwardView = game_root._inward_view
		view.selected_id = "adaptation"; view.web_selection = "lean"
		await _capture("available_%d" % size.x)
		var before: Dictionary = game_root.simulation.run.to_dict()
		_pointer(view, size.x == 900, view._adaptation_rect("lean").get_center())
		before.colony.piles[0].queued_adaptation = "lean"
		if before != game_root.simulation.run.to_dict(): failed = true
		await _capture("queued_space_%d" % size.x)
		_pointer(view, size.x == 900, AdaptationWeb.positions(view.get_viewport_rect().size).load)
		if before != game_root.simulation.run.to_dict(): failed = true
		await _capture("replace_%d" % size.x)
		_pointer(view, size.x == 900, view._adaptation_rect("load").get_center())
		before.colony.piles[0].queued_adaptation = "load"
		if before != game_root.simulation.run.to_dict(): failed = true
		view.selected_id = "queen"
		await _capture("queen_wait_%d" % size.x)
		game_root.simulation.toggle_pause(); game_root.simulation.advance(360); game_root.simulation.toggle_pause()
		view.selected_id = "adaptation"; view.web_selection = "load"
		await _capture("locked_%d" % size.x)
		if game_root.inward_status("home").adaptation_trial.adaptation_id != "load" or not game_root.inward_status("home").adaptation_queue.trait_id.is_empty(): failed = true
		game_root.simulation = Recognition.new().candidate_game()
		game_root.simulation.start_adaptation("home", "lean"); game_root.simulation.queue_adaptation("home", "tolerance"); game_root.simulation.toggle_pause(); game_root._refresh_loaded_views()
		view.selected_id = "adaptation"; view.web_family = "recognition"; view.web_selection = "tolerance"
		await _capture("followup_%d" % size.x)
		view.web_selection = "foraging"
		await _capture("overview_%d" % size.x)
		before = game_root.simulation.run.to_dict()
		_pointer(view, size.x == 900, view._adaptation_rect("").get_center())
		before.colony.piles[0].queued_adaptation = ""
		if before != game_root.simulation.run.to_dict(): failed = true
		await _capture("cancelled_%d" % size.x)
	print("[ADAPTATION-QUEUE] standard/compact actual mouse/touch queue, inspect, replace, locked laying, follow-up and overview cancellation; snapshot-isolated rendering; failed=",failed)
	game_root.free(); await create_timer(.3).timeout; quit(1 if failed else 0)

func _pointer(view: InwardView, touch: bool, at: Vector2):
	var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	event.position = at; event.pressed = true
	if event is InputEventMouseButton: event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)

func _capture(label: String):
	var before: Dictionary = game_root.simulation.run.to_dict()
	for frame: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	if before != game_root.simulation.run.to_dict(): failed = true
	if get_root().get_texture().get_image().save_png("res://.godot/card094_%s.png" % label) != OK: failed = true
