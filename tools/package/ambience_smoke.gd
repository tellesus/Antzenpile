extends "interface_smoke.gd"
## Native unchanged-PCK material, preference and mixer check; never shipped.
func _run() -> void:
	game_root = Root.new(); game_root.simulation = Controller.new(195)
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	get_root().content_scale_size = Vector2i(900,600); get_root().size = Vector2i(900,600)
	var outward := Outward.new()
	outward.signal_provider = game_root.sensory_snapshot.bind("home")
	outward.status_provider = game_root.outward_status.bind("home")
	get_root().add_child(outward)
	var output: String = OS.get_cmdline_user_args()[0]
	await picture(output)
	var audio = load("res://src/audio/audio_controller.gd").new()
	audio.preferences = game_root.audio_preferences
	audio.state_provider = game_root.music_state.bind("home")
	get_root().add_child(audio)
	var settings = load("res://src/presentation/audio_settings.gd").new()
	settings.preferences = game_root.audio_preferences
	settings.changed = game_root.audio_preferences.save_file
	settings.opened = true; settings.show_launcher = false
	get_root().add_child(settings)
	await press(settings.level_rect("ambience",3).get_center())
	var restored = load("res://src/audio/audio_preferences.gd").new()
	if not restored.load_file() or restored.ambience != 0.75: failed = true
	await picture(output.get_basename()+"_sound.png")
	await press(settings.level_rect("music",0).get_center())
	await press(settings.level_rect("cues",0).get_center())
	await press(settings.level_rect("ambience",4).get_center())
	var bus: int = AudioServer.bus_count
	AudioServer.add_bus(); AudioServer.set_bus_name(bus,"PackedAmbience195")
	var capture := AudioEffectCapture.new(); capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus,capture); audio.ambience_player.bus = "PackedAmbience195"
	audio.ambience_player.seek(23.8)
	await create_timer(0.6).timeout
	var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var peak: float = 0
	for frame: Vector2 in frames: peak = maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	if frames.is_empty() or peak < 0.0001 or peak >= 0.25 or audio.base_player.volume_db != -80: failed = true
	if game_root.simulation.run.to_dict() != frozen: failed = true
	game_root.simulation.toggle_pause()
	await create_timer(1.7).timeout
	if audio.ambience_player.volume_db != -80: failed = true
	audio.stop_playback(); audio.restart_after_load()
	if audio.ambience_player.stream != null or audio.ambience_player.playing: failed = true
	print("[PACKED-AMBIENCE] native_controls_persistence_mixer_wrap_pause_shutdown=%s frames=%d peak=%f driver=%s build=%s" % [not failed,frames.size(),peak,AudioServer.get_driver_name(),SaveBuild.current()])
	AudioServer.remove_bus(bus); settings.free(); audio.free(); outward.free(); game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
