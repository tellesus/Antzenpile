extends SceneTree
const Root = preload("res://src/core/game_root.gd")
const Save = preload("res://src/core/save_service.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	root.simulation.set_exploration(2)
	root.simulation.advance(300)
	root.simulation.toggle_pause()
	root.save_service = Save.new("res://.godot/card070_probe_save.json")
	if not root.quick_save().accepted: failed = true
	root.audio_preferences.music = 0.25
	var snapshot: Dictionary = root.simulation.run.to_dict()
	var controls: ColonyControls = root._colony_controls
	for mode: String in ["outward","inward"]:
		root.set_mode(mode)
		for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
			DisplayServer.window_set_size(size)
			for frame: int in 3: await process_frame
			controls.activate_at(controls.button_rect().get_center())
			if not root.interaction_blocked() or not root.sound_controls_blocked(): failed = true
			if root._audio_settings.activate_at(root._audio_settings.button_rect().get_center()): failed = true
			for frame: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			if get_root().get_texture().get_image().save_png("res://.godot/card070_%s_%d.png" % [mode,size.x]) != OK: failed = true
			controls.activate_at(controls.choice_rect("cancel").get_center())
	if snapshot != root.simulation.run.to_dict(): failed = true
	controls.opened = true
	controls.activate_at(controls.choice_rect("repeat").get_center())
	if controls.opened or root.mode != "outward" or root.simulation.run.simulation_time != 0 or root.audio_preferences.music != 0.25: failed = true
	root._outward_view.dispatch_command.call(0.0)
	if root.simulation.run.scouts.size() != 1: failed = true
	if not root.quick_load().accepted or root.simulation.run.to_dict() != snapshot: failed = true
	print("[NEW-COLONY] both layouts/modes, exclusive modal, repeat seed, retained levels/save and rebound scout command; failed=%s" % failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
