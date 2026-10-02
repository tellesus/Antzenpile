extends SceneTree
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	root.simulation.toggle_pause()
	var settings: AudioSettings = root._audio_settings
	settings.changed = root.audio_preferences.save_file.bind("res://.godot/card069_preferences.cfg")
	var snapshot: Dictionary = root.simulation.run.to_dict()
	for mode: String in ["outward", "inward"]:
		root.set_mode(mode)
		for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
			DisplayServer.window_set_size(size)
			for frame: int in 3: await process_frame
			settings.opened = false
			var touch := InputEventScreenTouch.new()
			touch.pressed = true
			touch.position = settings.button_rect().get_center()
			settings._input(touch)
			if not root.interaction_blocked(): failed = true
			var view: Node2D = root._outward_view if mode == "outward" else root._inward_view
			if not view.input_blocked.call(): failed = true
			settings.activate_at(settings.level_rect("music",0).get_center())
			settings.activate_at(settings.level_rect("cues",4).get_center())
			for frame: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			if get_root().get_texture().get_image().save_png("res://.godot/card069_%s_%d.png" % [mode,size.x]) != OK: failed = true
			if not root._audio_controller.base_player.playing or root._audio_controller.base_player.volume_db != -80 or root._audio_controller.alarm_player.volume_db != -15: failed = true
			settings.activate_at(settings.close_rect().get_center())
			if root.interaction_blocked(): failed = true
	if snapshot != root.simulation.run.to_dict(): failed = true
	print("[AUDIO-PREFERENCES] standard/compact both views, touch/modal/persistence, music off/cues full, snapshot and continuing playback; failed=%s" % failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
