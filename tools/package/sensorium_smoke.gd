extends "chemical_smoke.gd"
## External native probe of the unchanged PCK; authoring tool, never exported.
const Inward = preload("res://src/presentation/inward/inward_view.gd")
const Menu = preload("res://src/presentation/colony_controls.gd")

func _run() -> void:
	game_root = Root.new()
	game_root.simulation = Controller.new()
	game_root.simulation.toggle_pause()
	get_root().content_scale_size = Vector2i(1920,1080)
	get_root().size = Vector2i(1920,1080)
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	var view := Inward.new()
	view.status_provider = game_root.inward_status.bind("home")
	view._animation_time = 11.0
	get_root().add_child(view)
	var menu := Menu.new()
	get_root().add_child(menu)
	var folder: String = OS.get_cmdline_user_args()[0]
	var failed: bool = false
	for label: String in ["inward", "menu"]:
		if label == "menu": menu.open_menu()
		for frame: int in 20: await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = get_root().get_texture().get_image()
		failed = failed or picture.get_size() != Vector2i(1920,1080) or picture.save_png(folder.path_join("packed_%s.png" % label)) != OK
	failed = failed or frozen != game_root.simulation.run.to_dict()
	print("[PACKED-SENSORIUM] inward_menu_native=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	menu.free()
	view.free()
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
