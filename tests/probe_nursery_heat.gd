extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failures: int = 0
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var colony := Root.new()
	get_root().add_child(colony)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/card100_backyard_slice_0_hot.json"))
	if not colony.simulation.restore_snapshot(source): quit(1); return
	colony.simulation.toggle_pause()
	colony.set_mode("inward")
	var view: InwardView = colony._inward_view
	view.selected_id = "nursery"
	var frozen: Dictionary = colony.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 8: await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://.godot/card100_heat_%d.png" % size.x)
	if colony.simulation.run.to_dict() != frozen or view._status.temperature.condition != "hot": failures += 1
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true; mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = view._humidity_rect(4).get_center()
	view._unhandled_input(mouse)
	if colony.simulation.run.colony.piles.home.workers.count("humidity:home") != 4: failures += 1
	var touch := InputEventScreenTouch.new()
	touch.pressed = true; touch.position = view._humidity_rect(1).get_center()
	view._unhandled_input(touch)
	if colony.simulation.run.colony.piles.home.humidity.carers != 1 or not colony.simulation.run.colony.piles.home.workers.invariant_holds(): failures += 1
	colony.set_mode("outward")
	for frame: int in 8: await process_frame
	get_root().get_texture().get_image().save_png("res://.godot/card100_outward_900.png")
	if not "HEAT" in ColonyPressure.attention(colony.inward_status("home")).get("causes",[]): failures += 1
	print("[NURSERY-HEAT-UI] local heat and voluntary attention, standard/compact, mouse/touch climate; failures=",failures)
	colony.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
