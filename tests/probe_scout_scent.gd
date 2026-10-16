extends "res://tests/probe_neon_trails.gd"
func _run() -> void:
	output_dir="res://.godot/card192"
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	for bearing: float in [-1.0,-0.5,0.0,0.5,1.0]:
		if not game_root.simulation.dispatch_scout("home",bearing):failed=true
	var view: OutwardView=game_root._outward_view
	view._process(0)
	var before: Dictionary=game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size);view._process(0)
		await _capture("scouts_%d" % size.x)
		view.selected_id="mission:scout_3"
		await _capture("scout_selected_%d" % size.x)
		view.selected_id=""
	if game_root.simulation.run.to_dict()!=before:failed=true
	var old_time: float=view._animation_time
	for frame: int in 6:await process_frame
	if old_time!=view._animation_time:failed=true
	print("[SCOUT SCENT] paused snapshots and decorative clock preserved=",not failed)
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
