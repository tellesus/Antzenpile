extends RefCounted

const Root = preload("res://src/core/game_root.gd")
const Audio = preload("res://src/audio/audio_controller.gd")


func run(test: Object) -> bool:
	var root := Root.new()
	test.get_root().add_child(root)
	test.check(root._audio_controller == null, "Headless run composes no audio controller")
	test.check(root.music_state("home").development_level == 0 and root.music_state("absent").development_level == 0, "Primitive and missing pile map to silent growth intent")
	var pile: PileState = root.simulation.run.colony.piles.home
	pile.food_exchange_state = "developing"
	test.check(root.music_state("home").development_level == 0, "Developing does not pre-empt the musical reward")
	pile.food_exchange_state = "developed"
	test.check(root.music_state("home").development_level == 1, "Developed maps to one semantic growth layer")
	var base: AudioStreamWAV = Audio.BASE_LOOP
	var growth: AudioStreamWAV = Audio.GROWTH_LOOP
	test.check(is_equal_approx(base.get_length(), 8.0) and is_equal_approx(growth.get_length(), 8.0), "Original stems share an eight-second loop duration")
	var controller: AudioController = Audio.new()
	controller.state_provider = root.music_state.bind("home")
	test.get_root().add_child(controller)
	test.check(controller.get_child_count() == 4 and not controller.base_player.playing and not controller.growth_player.playing, "Headless audio controller creates no playback while preserving four-player topology")
	test.check(controller.stem_gain == 1.0 and controller.growth_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and controller.base_player.stream.loop_end == controller.growth_player.stream.loop_end, "Reloaded Developed run starts at matching loop phase and full mix")
	pile.food_exchange_state = "primitive"
	controller._process(1.5)
	test.check(is_equal_approx(controller.stem_gain, 0.5), "Gain follows three real seconds when returning to primitive intent")
	root.simulation.set_time_scale(64)
	root.simulation.toggle_pause()
	controller._process(1.5)
	test.check(is_zero_approx(controller.stem_gain) and controller.get_child_count() == 4, "Audio mix intent advances while simulation is paused at 64x")
	pile.food_exchange_state = "developed"
	controller._process(1.5)
	test.check(is_equal_approx(controller.stem_gain, 0.5), "Development crossfade reaches halfway in real time")
	controller._process(1.5)
	controller._process(5.0)
	test.check(is_equal_approx(controller.stem_gain, 1.0) and controller.get_child_count() == 4, "Repeated Developed updates clamp gain without duplicate players")
	pile.food_exchange_state = "primitive"
	controller.restart_after_load()
	test.check(is_zero_approx(controller.stem_gain) and controller.get_child_count() == 4, "Reloaded primitive run resets all loops to the base-only mix")
	pile.food_exchange_state = "developed"
	controller.restart_after_load()
	test.check(is_equal_approx(controller.stem_gain, 1.0) and controller.get_child_count() == 4, "Reloaded developed run resets phase and semantic mix without new players")
	controller.free()
	root.free()
	return true
