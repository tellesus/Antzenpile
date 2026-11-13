extends SceneTree
const Root = preload("res://src/core/game_root.gd")

class PackedRoot extends "res://src/core/game_root.gd":
	func _ready() -> void:
		# The editor's debug view is intentionally absent from the release pack.
		# Exercise unchanged packed lifecycle/audio methods with their real owner.
		simulation = Controller.new()
		_own_window_close_requests()
		_audio_controller = Audio.new()
		_audio_controller.alarm_provider = func() -> int: return 0
		_audio_controller.discovery_provider = func() -> int: return 0
		add_child(_audio_controller)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game: Node = Root.new() if ResourceLoader.exists("res://src/debug/debug_world_view.gd") else PackedRoot.new()
	get_root().add_child(game)
	game.set_process(false)
	await create_timer(1.0).timeout
	var frozen: Dictionary = game.simulation.run.to_dict()
	get_root().propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	# Repeated requests must not create a second asynchronous shutdown.
	get_root().propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	for frame: int in 2: await process_frame
	var passed: bool = game._closing and not auto_accept_quit and not game._audio_controller.is_processing() and game.simulation.run.to_dict() == frozen
	for player: AudioStreamPlayer in game._audio_controller._players():
		passed = passed and not player.playing and player.stream == null
	print("[WINDOW-CLOSE] queued_audio_release_no_save_or_simulation_change=%s build=%s" % [passed,SaveBuild.current()])
	if not passed: quit(1)
	# The actual inherited Root handler ends the process after its drain period.
