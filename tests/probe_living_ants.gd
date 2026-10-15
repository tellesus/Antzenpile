extends "res://tests/probe_sensorium_revision.gd"

func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output_dir="res://.godot/card183";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	_fixture()
	var view: OutwardView=game_root._outward_view
	var status: Dictionary=view.status_provider.call();status.paused=true
	view.status_provider=func() -> Dictionary:return status
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size);view._animation_time=11.0
		game_root.set_mode("outward");await _capture("outward_%d" % size.x)
		game_root.set_mode("inward");_mature(true);game_root._inward_view._animation_time=11.0
		await _capture("inward_%d" % size.x)
	game_root.set_mode("outward");_resize(Vector2i(1280,720))
	for i: int in 48:
		view._animation_time=11.0+i*0.05
		await _capture("motion_%03d" % i)
	for frame: int in 20:await process_frame
	await RenderingServer.frame_post_draw
	var paused: PackedByteArray=get_root().get_texture().get_image().get_data()
	for frame: int in 12:await process_frame
	await RenderingServer.frame_post_draw
	if paused!=get_root().get_texture().get_image().get_data():failed=true
	if game_root.simulation.run.to_dict()!=frozen:failed=true
	print("[WORKERS] native_motion_pause_immutable=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
