extends "res://tests/probe_sensorium_revision.gd"
## Native local material, independent preference, pause and actual mixer checks.
func _run() -> void:
	output_dir = "res://.godot/card195/native"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root = Root.new(); get_root().add_child(game_root); game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	_fixture(); _mature(true)
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size); game_root.set_mode("outward")
		await _capture("outward_%d" % size.x)
		var settings: AudioSettings = game_root._audio_settings
		settings.opened = true
		settings.changed = Callable()
		settings.activate_at(settings.level_rect("ambience", 3).get_center())
		if game_root.audio_preferences.ambience != 0.75 or not Rect2(Vector2.ZERO,Vector2(size)).encloses(settings.panel_rect()): failed = true
		await _capture("sound_%d" % size.x)
		settings.opened = false
	var audio: AudioController = game_root._audio_controller
	game_root.audio_preferences.music = 0; game_root.audio_preferences.cues = 0; game_root.audio_preferences.ambience = 1
	var state := MusicState.new(); state.ambience_gain = 1
	audio.state_provider = func() -> MusicState: return state
	var bus: int = AudioServer.bus_count
	AudioServer.add_bus(); AudioServer.set_bus_name(bus, "AmbienceProbe195")
	var capture := AudioEffectCapture.new(); capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture); audio.ambience_player.bus = "AmbienceProbe195"
	await create_timer(1.7).timeout
	capture.clear_buffer(); audio.ambience_player.seek(23.8)
	await create_timer(0.6).timeout
	var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var peak: float = 0; var energy: float = 0
	for frame: Vector2 in frames:
		peak = maxf(peak,maxf(absf(frame.x),absf(frame.y))); energy += frame.length_squared()
	if frames.is_empty() or peak < 0.0001 or peak >= 0.25 or not audio.ambience_player.playing: failed = true
	state.ambience_gain = 0
	await create_timer(1.7).timeout
	if audio.ambience_player.volume_db != -80: failed = true
	if frozen != game_root.simulation.run.to_dict(): failed = true
	print("[TACTILE195] mixer_frames=%d peak=%f rms=%f pause_silent=%s snapshot_equal=%s passed=%s" % [frames.size(),peak,sqrt(energy/maxi(1,frames.size()*2)),audio.ambience_player.volume_db==-80,frozen==game_root.simulation.run.to_dict(),not failed])
	audio.stop_playback(); AudioServer.remove_bus(bus)
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
