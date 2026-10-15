extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
const Inward = preload("res://src/presentation/inward/inward_view.gd")
const Menu = preload("res://src/presentation/colony_controls.gd")
const Sound = preload("res://src/presentation/audio_settings.gd")
const Save = preload("res://src/core/save_service.gd")

func run(test: Object) -> bool:
	var game_root := Root.new()
	test.get_root().add_child(game_root)
	var view := Outward.new()
	game_root.add_child(view)
	game_root._outward_view = view
	var inward := Inward.new()
	game_root.add_child(inward)
	game_root._inward_view = inward
	var menu := Menu.new()
	game_root.add_child(menu)
	game_root._colony_controls = menu
	menu.escape_context = game_root.close_attention
	menu.utility_command = game_root.menu_utility
	var sound := Sound.new()
	sound.preferences = game_root.audio_preferences
	sound.show_launcher = false
	game_root.add_child(sound)
	game_root._audio_settings = sound
	game_root.save_service = Save.new("res://.godot/card180_menu_save.json")
	var before: Dictionary = game_root.simulation.run.to_dict()
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	view.selected_id = "some_memory"
	menu._input(escape)
	test.check(view.selected_id.is_empty() and not menu.opened, "First Escape closes the current inspection without opening another modal")
	menu._input(escape)
	test.check(menu.opened and game_root.simulation.run.to_dict() == before, "Next Escape opens the menu without pausing, dispatching or advancing the run")
	menu._input(escape)
	test.check(not menu.opened, "Escape closes its menu")
	test.check(not menu.activate_at(menu.help_button_rect().get_center()) and not sound.activate_at(sound.button_rect().get_center()), "Retired Help/Sound launch locations cannot create invisible hotspots")
	for at: Vector2 in [Vector2(1070, 110), Vector2(1190, 110)]:
		test.check(view._button_at(at).is_empty() and not inward.activate_at(at), "Removed Save/Load controls cannot intercept field input")
	menu.open_menu()
	menu.activate_at(menu.utility_rect("save").get_center())
	test.check(FileAccess.file_exists(game_root.save_service.path) and menu.feedback == "Colony saved" and game_root.simulation.run.to_dict() == before, "The menu invokes the existing atomic save command and acknowledges it")
	menu.activate_at(menu.utility_rect("pause").get_center())
	test.check(game_root.simulation.run.clock.paused, "Pause remains an explicit action inside the menu")
	menu.activate_at(menu.utility_rect("pause").get_center())
	test.check(game_root.simulation.run.to_dict() == before, "Pausing/resuming twice cannot alter simulation or RNG history")
	game_root.simulation.advance(0.25)
	menu.activate_at(menu.utility_rect("load").get_center())
	test.check(game_root.simulation.run.to_dict() == before and not menu.opened, "Load restores the saved colony and returns modal ownership to the field")
	menu.open_menu()
	menu.activate_at(menu.utility_rect("sound").get_center())
	test.check(sound.opened and not menu.opened and game_root.interaction_blocked(), "Sound transfers modal ownership without leaking input")
	sound.opened = false
	game_root.mode = "inward"
	inward.chamber_controls.opened = true
	menu._input(escape)
	test.check(not inward.chamber_controls.opened and not menu.opened, "Escape closes an INWARD project draft without ordering it")
	var bounds := Rect2(Vector2.ZERO, menu.get_viewport_rect().size)
	test.check(bounds.encloses(menu.panel_rect()), "The menu fits inside the standard viewport")
	var overlap: bool = false
	for choice: String in ["repeat", "fresh", "cancel", "end", "guide"]:
		for action: String in ["save", "load", "sound", "help", "pause"]:
			overlap = overlap or menu.choice_rect(choice).intersects(menu.utility_rect(action))
	test.check(not overlap, "Restart/end actions are separated from routine menu commands")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game_root.save_service.path))
	game_root.free()
	return true
