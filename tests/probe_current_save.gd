extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Mixed = preload("res://tests/test_save_load.gd")
const Parent = preload("res://tests/test_parent_supply.gd")
const Search = preload("res://tests/test_journey_investigation.gd")
var failures: int = 0

func _initialize() -> void:
	create_timer(35).timeout.connect(func() -> void:printerr("FAIL: current-save watchdog");quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: "+label)

func press(at: Vector2, touch: bool) -> void:
	for down: bool in [true,false]:
		var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
		if event is InputEventMouseButton:event.button_index=MOUSE_BUTTON_LEFT
		event.position=at;event.pressed=down;get_root().push_input(event,true)
		await process_frame

func run() -> void:
	var root := Root.new();get_root().add_child(root);root.set_process(false)
	root.save_service.path="res://.godot/card178-native-slot.json"
	var daughter: SimulationController = Parent.new().fixture()
	assert(daughter.set_daughter_supply(true));daughter.advance(0.25)
	var search: SimulationController = Search.new().investigated_game()
	assert(search.journey_response.set_force("route_1",12))
	while search.run.journey_response.phase!="fighting":search.advance(0.25)
	var fixtures: Array[SimulationController] = [Mixed.new()._fixture(),daughter,search]
	var pictures: String="res://.godot/card178/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pictures))
	for width: int in [1280,900]:
		var size:=Vector2i(width,720 if width==1280 else 600)
		get_root().content_scale_size=size;DisplayServer.window_set_size(size)
		for index: int in fixtures.size():
			assert(root.simulation.restore_snapshot(JSON.parse_string(JSON.stringify(fixtures[index].run.to_dict(),"",true,true))))
			root._refresh_loaded_views()
			var expected: Dictionary=root.simulation.run.to_dict().duplicate(true)
			check(root.quick_save().accepted,"Current native save")
			var bytes: String=FileAccess.get_file_as_string(root.save_service.path)
			check(root.end_run_review(),"End and open native review")
			var frozen: Dictionary=root.simulation.run.to_dict().duplicate(true)
			for action: String in ["first","play","last","previous","next"]:
				await press(root._review.button_rect(action).get_center(),width==900)
				root._review._process(0.75)
			check(root.simulation.run.to_dict()==frozen,"Native playback and scrubbing never alter authoritative state")
			check(not root.quick_save().accepted and FileAccess.get_file_as_string(root.save_service.path)==bytes,"Native review keeps saved colony")
			if index==2:
				await process_frame;await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png(pictures+"review_%d.png"%width)
			await press(root._review.button_rect("load").get_center(),width==900)
			check(root.mode=="outward" and not root._review.visible and root.simulation.run.to_dict()==expected,"Native LOAD SAVED resumes exact saved state")
			var twin:=SimulationController.new();assert(twin.restore_snapshot(expected))
			root.simulation.advance(40);twin.advance(40)
			check(root.simulation.run.to_dict()==twin.run.to_dict(),"Native resumed continuation is exact")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.save_service.path))
	root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.3).timeout
	print("[CURRENT SAVE UI] six native mouse/touch save/review/playback/load/continuation flows; failures=",failures)
	quit(1 if failures else 0)
