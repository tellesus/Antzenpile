class_name AudioController
extends Node
## Authored C2 cycle; musical time belongs to the audio mixer, never simulation.

const MUSIC_LOOP = preload("res://assets/audio/warm_current.ogg")
const ALARM_CUE = preload("res://assets/audio/returned_alarm.wav")
const DISCOVERY_CUE = preload("res://assets/audio/returned_discovery.wav")
const START_FADE_SECONDS: float = 1.4

var alarm_provider: Callable
var discovery_provider: Callable
var music_player: AudioStreamPlayer
var alarm_player: AudioStreamPlayer
var discovery_player: AudioStreamPlayer
var preferences: AudioPreferences = preload("res://src/audio/audio_preferences.gd").new()
var _reported_losses: int = 0
var _reported_discoveries: int = 0
var _start_gain: float = 0.0
var _shutting_down: bool = false


func _ready() -> void:
	music_player = _make_player(MUSIC_LOOP)
	if alarm_provider.is_valid(): alarm_player = _make_player(ALARM_CUE)
	if discovery_provider.is_valid(): discovery_player = _make_player(DISCOVERY_CUE)
	restart_after_load()


func restart_after_load() -> void:
	if _shutting_down or music_player == null: return
	_reported_losses = int(alarm_provider.call()) if alarm_provider.is_valid() else 0
	_reported_discoveries = int(discovery_provider.call()) if discovery_provider.is_valid() else 0
	for player: AudioStreamPlayer in _players():
		if player != null: player.stop()
	_start_gain = 0.0
	_update_volume()
	if DisplayServer.get_name() != "headless": music_player.play()


func _process(delta: float) -> void:
	if _shutting_down: return
	_start_gain = move_toward(_start_gain, 1.0, delta / START_FADE_SECONDS)
	_update_volume()
	poll_returned_alarm()
	poll_returned_discovery()


func poll_returned_alarm() -> bool:
	if _shutting_down or not alarm_provider.is_valid(): return false
	var reports: int = int(alarm_provider.call())
	var new_report: bool = reports > _reported_losses
	_reported_losses = reports
	if new_report and alarm_player != null and DisplayServer.get_name() != "headless": alarm_player.play()
	return new_report


func poll_returned_discovery() -> bool:
	if _shutting_down or not discovery_provider.is_valid(): return false
	var reports: int = int(discovery_provider.call())
	var new_report: bool = reports > _reported_discoveries
	_reported_discoveries = reports
	if new_report and discovery_player != null and DisplayServer.get_name() != "headless": discovery_player.play()
	return new_report


func _exit_tree() -> void:
	stop_playback()


func stop_playback() -> void:
	_shutting_down = true
	set_process(false)
	for player: AudioStreamPlayer in _players():
		if player != null:
			player.stop()
			player.stream = null


func _make_player(source: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = source
	add_child(player)
	return player


func _update_volume() -> void:
	music_player.volume_db = _level_db(preferences.music * _start_gain, 0.0)
	if alarm_player != null: alarm_player.volume_db = _level_db(preferences.cues, -15.0)
	if discovery_player != null: discovery_player.volume_db = _level_db(preferences.cues, -15.0)


func _level_db(level: float, authored_db: float) -> float:
	return -80.0 if level <= 0 else authored_db + linear_to_db(level)


func _players() -> Array[AudioStreamPlayer]:
	return [music_player, alarm_player, discovery_player]
