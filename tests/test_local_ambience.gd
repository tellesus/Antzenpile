extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Audio = preload("res://src/audio/audio_controller.gd")
const State = preload("res://src/audio/music_state.gd")
const Preferences = preload("res://src/audio/audio_preferences.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	test.get_root().add_child(root)
	var initial: MusicState = root.music_state("home")
	test.check(initial.ambience_gain > 0 and initial.ambience_gain <= 1, "Known local workforce supports bounded colony ambience")
	root.simulation.run.world.nodes.carb_exposed.quantity = 999.0
	test.check(root.music_state("home").ambience_gain == initial.ambience_gain, "Hidden exterior stock cannot change local sound")
	root.simulation.toggle_pause()
	test.check(root.music_state("home").ambience_gain == 0, "Paused local activity fades out")
	root.simulation.toggle_pause()
	var snapshot: Dictionary = root.simulation.run.to_dict()
	var audio := Audio.new()
	audio.state_provider = root.music_state.bind("home")
	test.get_root().add_child(audio)
	test.check(not audio.ambience_player.playing and audio.ambience_player.stream.get_length() == 24.0, "Headless stays silent and imported ambience has the exact loop duration")
	audio.preferences.music = 0
	audio.preferences.cues = 0
	audio.preferences.ambience = 1
	audio._process(0)
	test.check(audio.ambience_player.volume_db > -80 and audio.base_player.volume_db == -80, "Ambience is independent of music and information cues")
	audio.state_provider = func() -> MusicState: return State.new()
	audio._process(1.5)
	test.check(audio.ambience_player.volume_db == -80, "A paused or absent intent becomes silent within 1.5 real seconds")
	audio.state_provider = root.music_state.bind("home")
	audio.restart_after_load()
	audio.preferences.ambience = 0
	audio._process(0)
	test.check(audio.ambience_player.volume_db == -80, "Ambience off survives restart and does not mute other categories")
	var prefs := Preferences.new()
	prefs.ambience = 0.25
	var path: String = "res://.godot/ambience195.cfg"
	test.check(prefs.save_file(path), "Independent ambience level saves")
	var restored := Preferences.new()
	test.check(restored.load_file(path) and restored.ambience == 0.25, "Independent ambience level restores")
	var bad := ConfigFile.new()
	bad.set_value("audio", "music", 0)
	bad.set_value("audio", "ambience", "bad")
	bad.save(path)
	test.check(not restored.load_file(path) and restored.music == 1 and restored.ambience == 0.25, "Malformed ambience leaves every preference unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	audio.stop_playback()
	audio.restart_after_load()
	test.check(audio.ambience_player.stream == null and not audio.ambience_player.playing, "Shutdown clears ambient playback and reload cannot restart it")
	test.check(snapshot == root.simulation.run.to_dict(), "Ambience processing leaves simulation and RNG untouched")
	root.simulation.run.history.ended = true
	test.check(root.music_state("home").ambience_gain == 0, "Ended review has no living-colony ambience")
	test.check(State.from_summary({"paused":false,"workers_available":30,"relinquished":true}).ambience_gain == 0, "Relinquished nest cannot sound occupied")
	audio.free()
	root.free()
	return true
