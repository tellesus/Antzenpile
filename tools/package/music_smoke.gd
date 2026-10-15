extends SceneTree
## External source/PCK audio verification; excluded from the player package.
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Audio = preload("res://src/audio/audio_controller.gd")
const State = preload("res://src/audio/music_state.gd")
var failed: bool = false
var wrapped: bool = false

func _initialize() -> void: _run.call_deferred()

func phase(audio: AudioController, stage: String) -> float:
	var positions: Array[float] = []
	for player: AudioStreamPlayer in audio._music_players():
		positions.append(player.get_playback_position())
		if not player.playing or not player.stream.stereo or player.stream.loop_end != 3763200: failed = true
	var spread: float = positions.max() - positions.min()
	if spread > 0.02: failed = true
	print("[MUSIC] %s phase=%.6f spread=%.6f" % [stage, positions[0], spread])
	return positions[0]

func _run() -> void:
	var root := Root.new()
	root.simulation = Controller.new(3043)
	root.simulation.toggle_pause()
	var status: Dictionary = root.inward_status("home")
	status.food_exchange_state = "developed"
	status.nursery_state = "developed"
	status.midden.state = "developed"
	for cohort: Dictionary in status.brood:
		cohort.care = 1.0; cohort.nutrition = 1.0
	var focus: Array[String] = [""]
	var losses: Array[int] = [0]
	var discoveries: Array[int] = [0]
	var audio := Audio.new()
	audio.state_provider = func() -> MusicState: return State.from_summary(status, focus[0])
	audio.alarm_provider = func() -> int: return losses[0]
	audio.discovery_provider = func() -> int: return discoveries[0]
	get_root().add_child(audio)
	var frozen: Dictionary = root.simulation.run.to_dict()
	var full: bool = OS.get_cmdline_user_args().has("full")
	var previous: float = 0.0
	# One uninterrupted whole score proves wrap/phase rather than a seek alone.
	for second: int in (88 if full else 2):
		await create_timer(1.0).timeout
		var current: float = phase(audio, "uninterrupted:%d" % second)
		if current < previous: wrapped = true
		previous = current
	if full and not wrapped: failed = true
	focus[0] = "nursery"; status.humidity.larval_rate = 0.5
	root.simulation.set_time_scale(64)
	frozen = root.simulation.run.to_dict()
	await create_timer(3.2).timeout
	phase(audio, "focus_condition_paused64")
	if not is_equal_approx(audio.nursery_gain, 0.775) or not is_equal_approx(audio.stem_gain, 0.85): failed = true
	for player: AudioStreamPlayer in audio._music_players(): player.seek(player.stream.get_length() - 0.5)
	await create_timer(0.9).timeout
	if phase(audio, "seek_wrap") > 2: failed = true
	audio.preferences.music = 0
	audio.preferences.cues = 1
	audio._process(0)
	if audio.base_player.volume_db != -80 or audio.alarm_player.volume_db != -15: failed = true
	losses[0] += 1; discoveries[0] += 1
	audio._process(0)
	if not audio.alarm_player.playing or not audio.discovery_player.playing: failed = true
	await create_timer(0.6).timeout
	if audio.alarm_player.playing or audio.discovery_player.playing: failed = true
	phase(audio, "music_muted_keeps_clock")
	audio.preferences.cues = 0
	audio.restart_after_load()
	await create_timer(0.3).timeout
	if audio.poll_returned_alarm() or audio.poll_returned_discovery() or audio.base_player.volume_db != -80: failed = true
	phase(audio, "reload_preferences_baseline")
	if root.simulation.run.to_dict() != frozen: failed = true
	print("[MUSIC] native_audio_phase_wrap_fades_preferences_cues_reload=%s full_uninterrupted=%s driver=%s build=%s" % [not failed, full and wrapped, AudioServer.get_driver_name(), SaveBuild.current()])
	audio.free(); root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
