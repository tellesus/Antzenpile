extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const State = preload("res://src/audio/music_state.gd")
var failed: bool = false

func _initialize(): _run.call_deferred()

func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	root.simulation.toggle_pause()
	var status: Dictionary = root.inward_status("home")
	status.food_exchange_state = "developed"
	status.nursery_state = "developed"
	status.midden.state = "developed"
	for cohort: Dictionary in status.brood:
		cohort.nutrition = 1.0
		cohort.care = 1.0
	var focus: Array[String] = [""]
	var audio: AudioController = root._audio_controller
	audio.state_provider = func() -> MusicState: return State.from_summary(status, focus[0])
	audio.restart_after_load()
	var snapshot: Dictionary = root.simulation.run.to_dict()
	await create_timer(1.0).timeout
	_phase(audio, "developed")
	focus[0] = "nursery"
	status.humidity.larval_rate = 0.5
	await create_timer(3.2).timeout
	_phase(audio, "focused_strain")
	if not is_equal_approx(audio.nursery_gain, 0.775) or not is_equal_approx(audio.stem_gain, 0.85): failed = true
	root.simulation.set_time_scale(64)
	snapshot = root.simulation.run.to_dict()
	# Seek every running voice together near the actual longer loop boundary;
	# development/condition tests above still use uninterrupted real playback.
	for player: AudioStreamPlayer in audio._music_players(): player.seek(46.0)
	await create_timer(2.5).timeout
	_phase(audio, "paused_64x_looped")
	if snapshot != root.simulation.run.to_dict(): failed = true
	audio.restart_after_load()
	await create_timer(0.3).timeout
	_phase(audio, "reloaded")
	print("[CHAMBER-MUSIC] phase/headless contracts, focused condition, real-time tempo and reload checked; failed=%s" % failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)

func _phase(audio: AudioController, stage: String):
	var values: Array[float] = []
	for player: AudioStreamPlayer in audio._music_players():
		values.append(player.get_playback_position())
		if not player.playing: failed = true
	var spread: float = values.max() - values.min()
	if spread > 0.02: failed = true
	print("[CHAMBER-MUSIC] stage=%s phases=%s spread=%.6fs" % [stage, values, spread])
