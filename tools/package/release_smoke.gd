extends SceneTree
## Runs outside the exported pack with a package-specific APPDATA supplied by the builder.

func _initialize() -> void:
	call_deferred("_check_package")

func _check_package() -> void:
	if DisplayServer.get_name() != "headless":
		fail("Expected headless packed-resource probe")
		return
	if ResourceLoader.exists("res://src/debug/debug_world_view.gd") or ResourceLoader.exists("res://tests/run_tests.gd"):
		fail("Development resources leaked into release")
		return
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	if game.debug_is_open() or game._debug_view != null:
		fail("Release created a truth view")
		return
	var controller = game.simulation
	controller.advance(20.0)
	var save = load("res://src/core/save_service.gd").new()
	if not save.save(controller.run):
		fail("Packaged save failed: " + save.last_error)
		return
	var twin = load("res://src/core/simulation_controller.gd").new()
	if not save.load_into(twin):
		fail("Packaged load failed: " + save.last_error)
		return
	controller.advance(20.0)
	twin.advance(20.0)
	if JSON.stringify(controller.run.to_dict(), "", true, true) != JSON.stringify(twin.run.to_dict(), "", true, true):
		fail("Packaged saved continuation differs")
		return
	var preferences = load("res://src/audio/audio_preferences.gd").new()
	preferences.set_level("music", 0.5)
	if not preferences.save_file() or not save.load_into(twin):
		fail("Separate packaged preferences/save failed")
		return
	if not controller.end_run() or controller.advance(1.0) or controller.review_snapshot().is_empty():
		fail("Packaged end/review boundary failed")
		return
	if not save.load_into(twin) or twin.run.history.ended:
		fail("Review changed the pre-review save")
		return
	game.free()
	print("RELEASE PACKAGE CHECKS PASSED: Main, no debug/tests, save/resume twin, preferences, ended review")
	quit(0)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
