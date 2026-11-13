extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Controls = preload("res://src/presentation/colony_controls.gd")
const Save = preload("res://src/core/save_service.gd")

func run(test: Object) -> bool:
	var game := Controller.new(70)
	var founding: Dictionary = game.run.to_dict()
	game.set_exploration(5)
	game.advance(500)
	var old_clock: SimulationClock = game.run.clock
	var old_system: RefCounted = game.scouting
	test.check(game.start_new_run(70) and game.run.to_dict() == founding, "Repeat seed restores the exact founding colony with no residual jobs or evidence")
	test.check(not old_clock.tick.is_connected(game._tick) and old_system != game.scouting, "Old clock disconnects while fresh systems attach to the same controller")
	var before: Dictionary = game.run.to_dict()
	old_clock.advance(5)
	test.check(game.run.to_dict() == before, "An externally retained old clock cannot advance the fresh run")
	for value: Variant in ["70", 70.0, true, null]:
		test.check(not game.start_new_run(value) and game.run.to_dict() == before, "Invalid seed preserves the active colony atomically")
	test.check(game.start_new_run(-70) and game.run.run_seed == -70, "Repeat supports the existing signed integer seed contract")
	game.set_exploration(5)
	game.advance(100)
	var repeat := Controller.new(-70)
	repeat.set_exploration(5)
	repeat.advance(100)
	test.check(game.run.to_dict() == repeat.run.to_dict(), "Fresh systems replay fixed ticks deterministically")
	var root := Root.new()
	test.get_root().add_child(root)
	root.save_service = Save.new("res://.godot/card070_test_save.json")
	root.simulation.set_exploration(2)
	root.simulation.advance(300)
	var saved: Dictionary = root.simulation.run.to_dict()
	root.audio_preferences.set_level("music",0.25)
	test.check(root.quick_save().accepted, "Existing colony is saved before the independent restart test")
	var saved_bytes: String = FileAccess.get_file_as_string(root.save_service.path)
	var controller: SimulationController = root.simulation
	test.check(root.start_new_colony(71).accepted and root.simulation == controller and root.current_seed() == 71 and root.mode == "outward", "Root restarts through its existing command owner and OUTWARD entry")
	test.check(root.audio_preferences.music == 0.25 and FileAccess.get_file_as_string(root.save_service.path) == saved_bytes, "Fresh colony leaves player levels and saved slot intact")
	test.check(root.quick_load().accepted and root.simulation.run.to_dict() == saved, "Saved previous colony remains loadable after starting fresh")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.save_service.path))
	var controls := Controls.new()
	controls.seed_provider = root.current_seed
	controls.start_command = root.start_new_colony
	test.get_root().add_child(controls)
	var before_cancel: Dictionary = root.simulation.run.to_dict()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = controls.button_rect().get_center()
	controls._input(touch)
	test.check(controls.opened and controls.activate_at(Vector2(2,2)), "Colony modal uses touch and absorbs background input")
	controls.activate_at(controls.choice_rect("cancel").get_center())
	test.check(not controls.opened and root.simulation.run.to_dict() == before_cancel, "Cancel has no colony effect")
	controls.opened = true
	var old_seed: int = root.current_seed()
	controls.activate_at(controls.choice_rect("fresh").get_center())
	test.check(not controls.opened and root.current_seed() != old_seed and root.simulation.run.simulation_time == 0, "Explicit fresh choice starts a different seeded colony")
	controls.free()
	root.free()
	return true
