extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Pressure = preload("res://src/presentation/colony_pressure.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
			var path: String = "res://.godot/card078_%s_nutrition.json" % scenario
			if not FileAccess.file_exists(path) or not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path))): failed = true; continue
			root.simulation.toggle_pause()
			root._refresh_loaded_views()
			DisplayServer.window_set_size(size)
			root.set_mode("outward")
			var snapshot: Dictionary = root.simulation.run.to_dict()
			await _capture("%s_%d_pressure" % [scenario,size.x])
			var shortages: Array[String] = Pressure.food_shortages(root.inward_status("home"))
			if shortages != ["carbohydrate" if scenario == "backyard_slice" else "protein"]: failed = true
			root.inspect_internal_pressure()
			await _capture("%s_%d_nursery" % [scenario,size.x])
			var view: InwardView = root._inward_view
			view.selected_id = "food_exchange"
			await _capture("%s_%d_food" % [scenario,size.x])
			var input: InputEvent = InputEventScreenTouch.new() if size.x == 900 else InputEventMouseButton.new()
			input.pressed = true
			input.position = view._food_source_rect(shortages[0]).get_center()
			if input is InputEventMouseButton: input.button_index = MOUSE_BUTTON_LEFT
			var facing: float = root._outward_view.facing
			var selection: String = root._outward_view.selected_id
			view._unhandled_input(input)
			if root.mode != "outward" or not root._outward_view.sources_open or root._outward_view.source_category != shortages[0]: failed = true
			await _capture("%s_%d_sources" % [scenario,size.x])
			if snapshot != root.simulation.run.to_dict() or facing != root._outward_view.facing or selection != root._outward_view.selected_id: failed = true
			if view._food_source_rect(shortages[0]).intersects(view._develop_rect()) or view._food_source_rect(shortages[0]).end.y >= view._button_rect("pause").position.y: failed = true
	# Detached layout fixture: widest diagnosis without manufacturing simulation knowledge.
	root.set_mode("inward")
	var view: InwardView = root._inward_view
	var status: Dictionary = root.inward_status("home")
	var cohort: Dictionary = status.brood[0].duplicate(true)
	cohort.stage = "larva"
	cohort.care = 1.0
	cohort.nutrition = 0.0
	cohort.nutrition_shortfalls = ["carbohydrate","protein","water"]
	status.brood = [cohort]
	view.status_provider = func() -> Dictionary: return status.duplicate(true)
	view.selected_id = "food_exchange"
	await _capture("mixed_900_food")
	view.selected_id = "nursery"
	await _capture("mixed_900_nursery")
	status.brood[0].care = 0.5
	status.brood[0].nutrition_shortfalls = []
	await _capture("care_900_nursery")
	print("[NUTRITION-PROBE] ordinary carbohydrate/protein failure, both settings/sizes, last feeding labels, mouse/touch free returned-source browsing, separate targets and unchanged snapshots; mixed/care-only detached layout; failed=",failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card078_%s.png" % label) != OK: failed = true
