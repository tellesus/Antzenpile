extends SceneTree
## Native source/unchanged-PCK mixer gate. Full mode waits for a natural wrap.
const Audio = preload("res://src/audio/audio_controller.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
var failed: bool = false

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var simulation := Controller.new(3043)
	simulation.set_time_scale(64)
	simulation.toggle_pause()
	var frozen: Dictionary = simulation.run.to_dict()
	var losses: Array[int] = [0]
	var discoveries: Array[int] = [0]
	var audio := Audio.new()
	audio.alarm_provider = func() -> int: return losses[0]
	audio.discovery_provider = func() -> int: return discoveries[0]
	get_root().add_child(audio)
	var bus: int = AudioServer.bus_count
	AudioServer.add_bus(); AudioServer.set_bus_name(bus,"C2Probe200")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus,capture)
	audio.music_player.bus = "C2Probe200"
	var full: bool = OS.get_cmdline_user_args().has("full")
	var previous: float = 0
	var wrapped: bool = false
	var rest_peak: float = 0
	var total_peak: float = 0
	var frames_count: int = 0
	for second: int in (270 if full else 3):
		await create_timer(1).timeout
		var at: float = audio.music_player.get_playback_position()
		if at < previous: wrapped = true
		if not audio.music_player.playing: failed = true
		var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		frames_count += frames.size()
		for frame: Vector2 in frames:
			var peak: float = maxf(absf(frame.x),absf(frame.y))
			total_peak = maxf(total_peak,peak)
			if at > 202 and at < 212: rest_peak = maxf(rest_peak,peak)
		if second % 30 == 0 or at < previous: print("[C2] uninterrupted second=%d position=%.3f playing=%s" % [second,at,audio.music_player.playing])
		previous = at
	if full and (not wrapped or rest_peak > 0.00001): failed = true
	if frames_count == 0 or total_peak < .001 or total_peak > .4: failed = true
	# Seek across the loop in the short packaged probe as well.
	audio.music_player.seek(Audio.MUSIC_LOOP.get_length() - .25)
	await create_timer(.6).timeout
	if audio.music_player.get_playback_position() > 2: failed = true
	audio.preferences.music = 0
	audio._process(0)
	var muted_at: float = audio.music_player.get_playback_position()
	await create_timer(.3).timeout
	if audio.music_player.volume_db != -80 or audio.music_player.get_playback_position() <= muted_at: failed = true
	losses[0] += 1; discoveries[0] += 1
	audio._process(0)
	if not audio.alarm_player.playing or not audio.discovery_player.playing or audio.alarm_player.volume_db != -15: failed = true
	await create_timer(.6).timeout
	if audio.alarm_player.playing or audio.discovery_player.playing: failed = true
	audio.restart_after_load()
	await create_timer(.3).timeout
	if audio.poll_returned_alarm() or audio.poll_returned_discovery() or audio.music_player.volume_db != -80 or audio.music_player.get_playback_position() > 1: failed = true
	if simulation.run.to_dict() != frozen: failed = true
	audio.stop_playback()
	audio.restart_after_load()
	for player: AudioStreamPlayer in audio._players():
		if player.playing or player.stream != null: failed = true
	print("[C2] passed=%s full_uninterrupted_wrap=%s frames=%d peak=%.6f rest_peak=%.9f driver=%s build=%s" % [not failed,full and wrapped,frames_count,total_peak,rest_peak,AudioServer.get_driver_name(),SaveBuild.current()])
	audio.free()
	AudioServer.remove_bus(bus)
	for frame: int in 4: await process_frame
	await create_timer(.25).timeout
	quit(1 if failed else 0)
