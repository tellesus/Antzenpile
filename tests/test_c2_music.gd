extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Audio = preload("res://src/audio/audio_controller.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	test.get_root().add_child(root)
	test.check(root._audio_controller == null, "Headless game composes no audio playback")
	var losses: Array[int] = [4]
	var discoveries: Array[int] = [3]
	var audio := Audio.new()
	audio.alarm_provider = func() -> int: return losses[0]
	audio.discovery_provider = func() -> int: return discoveries[0]
	test.get_root().add_child(audio)
	test.check(audio.get_child_count() == 3 and not audio.music_player.playing, "One music player and two returned cue players stay silent headlessly")
	test.check(Audio.MUSIC_LOOP.loop and absf(Audio.MUSIC_LOOP.get_length() - 800.0 / 3.0) < 0.001, "Native compressed cycle loops the complete accepted five-section arrangement")
	test.check(not audio.poll_returned_alarm() and not audio.poll_returned_discovery(), "Existing delivered reports are baselined on startup")
	audio.set_process(false)
	var frozen: Dictionary = root.simulation.run.to_dict()
	audio._process(Audio.START_FADE_SECONDS / 2)
	test.check(is_equal_approx(db_to_linear(audio.music_player.volume_db), 0.5), "Startup fades the authored mix softly over real time")
	audio._process(Audio.START_FADE_SECONDS)
	test.check(audio.music_player.volume_db == 0, "Full music preference preserves the approved production level")
	test.check(root.simulation.run.to_dict() == frozen, "Sound processing cannot mutate simulation or RNG")
	root.simulation.set_time_scale(64)
	root.simulation.toggle_pause()
	frozen = root.simulation.run.to_dict()
	audio._process(20)
	test.check(audio.music_player.volume_db == 0 and root.simulation.run.to_dict() == frozen, "Pause and 64x cannot reschedule or accumulate musical layers")
	losses[0] += 2
	discoveries[0] += 1
	test.check(audio.poll_returned_alarm() and audio.poll_returned_discovery(), "New delivered batches remain eligible once")
	test.check(not audio.poll_returned_alarm() and not audio.poll_returned_discovery(), "Polling does not replay the same information")
	audio.preferences.music = 0
	audio.restart_after_load()
	test.check(audio.get_child_count() == 3 and audio.music_player.volume_db == -80, "Reload reuses bounded players and retains mute")
	test.check(not audio.poll_returned_alarm() and not audio.poll_returned_discovery(), "Reload suppresses old report sounds")
	audio.stop_playback()
	audio.restart_after_load()
	audio._process(20)
	for player: AudioStreamPlayer in audio._players():
		test.check(not player.playing and player.stream == null, "Shutdown drains each stream and reload cannot revive it")
	test.check(not audio.is_processing(), "Shutdown disables further sound polling")
	audio.free()
	root.free()
	return true
