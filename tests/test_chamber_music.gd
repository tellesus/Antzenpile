extends RefCounted
const State = preload("res://src/audio/music_state.gd")
const Audio = preload("res://src/audio/audio_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	test.get_root().add_child(root)
	var status: Dictionary = root.inward_status("home")
	status.nursery_state = "developing"
	status.midden.state = "developing"
	test.check(State.from_summary(status).nursery_gain == 0 and State.from_summary(status).midden_gain == 0, "Construction cannot anticipate new musical rewards")
	status.nursery_state = "developed"
	status.food_exchange_state = "developed"
	status.midden.state = "developed"
	status.brood[0].nutrition = 1.0
	status.brood[0].care = 1.0
	var healthy: MusicState = State.from_summary(status)
	test.check(healthy.nursery_gain == 1 and healthy.midden_gain == 1 and healthy.food_gain == 1, "All developed functions contribute their long-term voices")
	status.humidity.larval_rate = 0.5
	var strained: MusicState = State.from_summary(status)
	test.check(strained.nursery_gain > 0.55 and strained.nursery_gain < healthy.nursery_gain and strained.midden_gain == 1, "Known climate gently thins the Nursery without silencing developed organs")
	var focused: MusicState = State.from_summary(status, "nursery")
	test.check(focused.nursery_gain == strained.nursery_gain and focused.food_gain < strained.food_gain, "Attention foregrounds the selected organ without unlocking layers")
	var summary: Dictionary = root.inward_status("home")
	var intent: MusicState = root.music_state("home")
	root.simulation.run.world.nodes.carb_exposed.quantity = 999.0
	test.check(root.inward_status("home") == summary and root.music_state("home").nursery_gain == intent.nursery_gain, "Hidden exterior changes have no musical effect")
	var snapshot: Dictionary = root.simulation.run.to_dict()
	var current: Array[MusicState] = [healthy]
	var audio := Audio.new()
	audio.state_provider = func() -> MusicState: return current[0]
	test.get_root().add_child(audio)
	test.check(audio.nursery_gain == 1 and audio.midden_gain == 1 and not audio.nursery_player.playing, "Restored intent starts correct gains while headless playback stays silent")
	current[0] = State.new()
	audio._process(1.5)
	test.check(is_equal_approx(audio.nursery_gain, 0.5) and is_equal_approx(audio.midden_gain, 0.5), "Additional stems crossfade over real seconds")
	current[0] = strained
	audio.restart_after_load()
	test.check(audio.nursery_gain == strained.nursery_gain and audio.get_child_count() == 4, "Reload restores current condition and reuses all players")
	for loop: AudioStreamWAV in [Audio.BASE_LOOP, Audio.GROWTH_LOOP, Audio.NURSERY_LOOP, Audio.MIDDEN_LOOP]:
		test.check(loop.mix_rate == 22050 and is_equal_approx(loop.get_length(), 8.0), "Authored stems retain equal sample rate and duration")
	test.check(root.simulation.run.to_dict() == snapshot, "Music condition/attention/fades leave simulation and RNG untouched")
	audio.free()
	root.free()
	return true
