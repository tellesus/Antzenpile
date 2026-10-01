class_name AudioController
extends Node
## Two persistent phase-matched players; simulation state only chooses the mix.

const BASE_LOOP = preload("res://assets/audio/base_loop.wav")
const GROWTH_LOOP = preload("res://assets/audio/growth_loop.wav")
const ALARM_CUE = preload("res://assets/audio/returned_alarm.wav")
const FADE_SECONDS: float = 3.0
const MIX_DB: float = -4.0

var state_provider: Callable
var alarm_provider: Callable
var alarm_player: AudioStreamPlayer
var _reported_losses: int = 0
var stem_gain: float = 0.0
var base_player: AudioStreamPlayer
var growth_player: AudioStreamPlayer


func _ready() -> void:
	base_player = _make_player(BASE_LOOP, MIX_DB)
	growth_player = _make_player(GROWTH_LOOP, -80.0)
	if alarm_provider.is_valid():
		alarm_player = AudioStreamPlayer.new()
		alarm_player.stream = ALARM_CUE
		alarm_player.volume_db = -15.0
		add_child(alarm_player)
	restart_after_load()


func restart_after_load() -> void:
	if base_player == null or growth_player == null:
		return
	_reported_losses = int(alarm_provider.call()) if alarm_provider.is_valid() else 0
	if alarm_player != null:
		alarm_player.stop()
	base_player.stop()
	growth_player.stop()
	var state: MusicState = _current_state()
	stem_gain = float(state.development_level)
	_update_growth_volume()
	# Both play calls enter the same audio mix frame and retain their own phase.
	if DisplayServer.get_name() != "headless":
		base_player.play(0.0)
		growth_player.play(0.0)


func _process(delta: float) -> void:
	var target: float = float(_current_state().development_level)
	stem_gain = move_toward(stem_gain, target, delta / FADE_SECONDS)
	_update_growth_volume()
	poll_returned_alarm()


func poll_returned_alarm() -> bool:
	if not alarm_provider.is_valid():
		return false
	var losses: int = int(alarm_provider.call())
	var new_report: bool = losses > _reported_losses
	_reported_losses = losses
	if new_report and alarm_player != null and DisplayServer.get_name() != "headless":
		alarm_player.play()
	return new_report


func _exit_tree() -> void:
	for player: AudioStreamPlayer in [base_player, growth_player, alarm_player]:
		if player != null:
			player.stop()
			player.stream = null


func _current_state() -> MusicState:
	if state_provider.is_valid():
		var state: MusicState = state_provider.call()
		if state != null:
			return state
	return MusicState.new()


func _make_player(source: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var loop: AudioStreamWAV = source.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = 176400
	player.stream = loop
	player.volume_db = volume
	add_child(player)
	return player


func _update_growth_volume() -> void:
	growth_player.volume_db = MIX_DB + linear_to_db(maxf(stem_gain, 0.0001))
