extends RefCounted
const Preferences = preload("res://src/audio/audio_preferences.gd")
const Settings = preload("res://src/presentation/audio_settings.gd")
const Audio = preload("res://src/audio/audio_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func run(test: Object) -> bool:
	var prefs := Preferences.new()
	test.check(prefs.music == 1 and prefs.cues == 1, "Missing preferences retain the established sound mix")
	test.check(prefs.set_level("music", 0.25) and prefs.set_level("cues", 0), "Music and information levels can differ")
	for value: Variant in [-1, 2, NAN, INF, "quiet", true]:
		test.check(not prefs.set_level("music", value) and prefs.music == 0.25, "Invalid audio levels leave preferences unchanged")
	test.check(not prefs.set_level("ambient", 0.5), "No unused audio category is invented")
	var path: String = "res://.godot/test_audio_preferences.cfg"
	test.check(prefs.save_file(path), "Sound levels persist outside colony saves")
	var copy := Preferences.new()
	test.check(copy.load_file(path) and copy.music == 0.25 and copy.cues == 0, "Player preferences round trip")
	var bad := ConfigFile.new()
	bad.set_value("audio", "music", 0.75)
	bad.set_value("audio", "cues", "loud")
	bad.save(path)
	test.check(not copy.load_file(path) and copy.music == 0.25 and copy.cues == 0, "Malformed second level rejects the whole update atomically")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var root := Root.new()
	test.get_root().add_child(root)
	var snapshot: Dictionary = root.simulation.run.to_dict()
	var audio := Audio.new()
	audio.preferences = prefs
	audio.alarm_provider = func(): return 0
	test.get_root().add_child(audio)
	test.check(is_equal_approx(audio.base_player.volume_db, Audio.MIX_DB + linear_to_db(0.25)) and audio.alarm_player.volume_db == -80, "Quiet music and muted cues have independent gain")
	prefs.set_level("music", 0)
	prefs.set_level("cues", 1)
	audio._process(0)
	test.check(audio.base_player.volume_db == -80 and audio.alarm_player.volume_db == -15, "Music off retains the authored information-cue volume")
	audio.restart_after_load()
	test.check(prefs.music == 0 and prefs.cues == 1 and audio.base_player.volume_db == -80, "Run reload keeps player audio preferences")
	var settings := Settings.new()
	settings.preferences = prefs
	var calls: Array[int] = [0]
	settings.changed = func(): calls[0] += 1; return true
	test.get_root().add_child(settings)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = settings.button_rect().get_center()
	settings._input(touch)
	test.check(settings.opened and settings.activate_at(Vector2(2,2)), "Sound panel opens with touch and absorbs background input")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = settings.level_rect("music", 2).get_center()
	settings._input(mouse)
	test.check(prefs.music == 0.5 and prefs.cues == 1 and calls[0] == 1, "Mouse preset adjusts only music through one preference action")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	settings._input(escape)
	test.check(not settings.opened and not settings.activate_at(Vector2(2,2)), "Escape restores colony input without interpreting a modal click")
	test.check(root.simulation.run.to_dict() == snapshot, "Sound controls, file persistence and mix changes leave run/RNG untouched")
	settings.free()
	audio.free()
	root.free()
	return true
