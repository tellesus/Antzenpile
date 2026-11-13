extends SceneTree

const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_ecology_integration.gd")
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _run() -> void:
	var fixture := Fixture.new()
	fixture.run(self)
	if failures > 0:
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var root := Root.new()
	get_root().add_child(root)
	var loaded: bool = root.simulation.restore_snapshot(fixture.final_snapshot)
	if not loaded:
		quit(1)
		return
	root.simulation.toggle_pause()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for selection: String in ["guest", "nursery", "signal:known:carb_exposed", "signal:known:aphid_01"]:
			root.set_mode("outward" if selection.begins_with("signal:") else "inward")
			if selection.begins_with("signal:"):
				root._outward_view.selected_id = selection
			else:
				root._inward_view.selected_id = selection
			for frame: int in 20:
				await process_frame
			get_root().get_viewport().get_texture().get_image().save_png("res://.godot/card051_%s_%d.png" % [selection.replace("signal:known:", ""), size.x])
	print("[ECOLOGY-PROBE] captured eight combined evidence contexts at standard/compact sizes")
	get_root().remove_child(root)
	root.free()
	await create_timer(0.5).timeout
	quit(0)
