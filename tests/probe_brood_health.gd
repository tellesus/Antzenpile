extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failures: int = 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var colony := Root.new()
	get_root().add_child(colony)
	colony.set_mode("inward")
	var view: InwardView = colony._inward_view
	for phase: String in ["symptoms", "severe", "recovering"]:
		var snapshot_path: String = "res://.godot/card099_backyard_slice_482817_neglect_%s.json" % ("symptoms" if phase == "symptoms" else "final")
		if not colony.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))): failures += 1; break
		if phase == "recovering":
			# Visual fixture of isolated refuse with persistent symptoms; physics covered in ordinary trials.
			var pile: PileState = colony.simulation.run.colony.piles.home
			pile.midden.isolated_units = pile.midden.generated_units
			pile.brood_health.severe_ticks = 0
		colony.simulation.toggle_pause()
		view.selected_id = "nursery"
		var frozen: Dictionary = colony.simulation.run.to_dict()
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(900, 600)]:
			DisplayServer.window_set_size(size)
			for frame: int in 8: await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("res://.godot/card099_%s_%d.png" % [phase, size.x])
		if colony.simulation.run.to_dict() != frozen or view._status.brood_health.condition != {"symptoms": "strained", "severe": "severe", "recovering": "recovering"}[phase]: failures += 1
		view.selected_id = "midden"
		view._process(0)
		var mouse := InputEventMouseButton.new()
		mouse.pressed = true
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = view._cleaner_rect(5).get_center()
		view._unhandled_input(mouse)
		if colony.simulation.run.colony.piles.home.midden.cleaners != 5: failures += 1
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = view._cleaner_rect(2).get_center()
		view._unhandled_input(touch)
		if colony.simulation.run.colony.piles.home.midden.cleaners != 2 or not colony.simulation.run.colony.piles.home.workers.invariant_holds(): failures += 1
	print("[BROOD-HEALTH-UI] standard/compact symptoms, severe and recovery; actual mouse/touch cleanup; failures=", failures)
	colony.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
