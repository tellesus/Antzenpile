extends RefCounted
const Notice = preload("res://src/presentation/returned_discovery.gd")
const Root = preload("res://src/core/game_root.gd")
const Audio = preload("res://src/audio/audio_controller.gd")

func run(test: Object) -> bool:
	var notice := Notice.new()
	var old: Array[Dictionary] = [{"id":"known:a","category":"water"}]
	notice.baseline(old)
	test.check(notice.poll(old).is_empty(), "Loaded knowledge is baselined without replay")
	var batch: Array[Dictionary] = old.duplicate(true)
	batch.append({"id":"known:b","category":"protein"})
	batch.append({"id":"known:c","category":"carbohydrate"})
	var before: Array[Dictionary] = batch.duplicate(true)
	test.check(notice.poll(batch) == "New food + protein traces returned" and notice.poll(batch).is_empty() and batch == before, "Multiple new returned identities produce one detached notice then remain quiet")
	notice.baseline(batch)
	test.check(notice.poll(batch).is_empty(), "Rebaseline suppresses old batches")
	var root := Root.new()
	test.get_root().add_child(root)
	var game: SimulationController = root.simulation
	game.dispatch_scout("home",0.0)
	var privately_sensed: bool = false
	while game.run.simulation_time < 400 and game.run.knowledge.nodes.is_empty():
		game.advance(0.25)
		for scout: ScoutAgent in game.run.scouts.values():
			if not scout.observations.is_empty() and game.run.knowledge.nodes.is_empty():
				privately_sensed = true
				test.check(root.poll_discovery_notice().is_empty() and root.discovery_report_count() == 0, "A private sensed cue cannot announce discovery before home return")
	var snapshot: Dictionary = game.run.to_dict()
	test.check(privately_sensed and root.poll_discovery_notice().contains("food") and root.discovery_report_count() == 1, "Actual home return supplies one food-trace notice")
	test.check(root.poll_discovery_notice().is_empty() and game.run.to_dict() == snapshot, "Presentation polling cannot advance or mutate the run")
	root._refresh_loaded_views()
	test.check(root.discovery_report_count() == 0 and root.poll_discovery_notice().is_empty(), "Loaded/reset presentation retains known signals without a fresh cue")
	var reports: Array[int] = [0]
	var audio := Audio.new()
	audio.discovery_provider = func(): return reports[0]
	test.get_root().add_child(audio)
	test.check(not audio.poll_returned_discovery() and not audio.discovery_player.playing, "Headless discovery audio remains silent")
	reports[0] = 3
	test.check(audio.poll_returned_discovery() and not audio.poll_returned_discovery(), "One pending batch causes one semantic audio event")
	audio.preferences.cues = 0
	audio._process(0)
	test.check(audio.discovery_player.volume_db == -80 and audio.base_player.volume_db == Audio.MIX_DB, "Discovery obeys information level independently of music")
	audio.restart_after_load()
	test.check(not audio.poll_returned_discovery() and not audio.discovery_player.playing and Audio.DISCOVERY_CUE.loop_mode == AudioStreamWAV.LOOP_DISABLED and Audio.DISCOVERY_CUE.get_length() <= 0.3, "Reload suppresses a bounded non-looping cue")
	audio.free()
	root.free()
	return true
