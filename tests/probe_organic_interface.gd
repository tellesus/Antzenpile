extends "res://tests/probe_sensorium_revision.gd"
## Native review of organic surfaces, local relief and known-family navigation.
func _run() -> void:
	output_dir="res://.godot/card192"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new(); get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	_fixture();_mature(true)
	var inward: InwardView=game_root._inward_view
	var status: Dictionary=inward.status_provider.call()
	# Detached visual stress projection, not evidence of unlocking these leaves.
	for id: String in ["lean","load","fighter","security","tolerance","efficient_nurses","heat_resilience","moisture_resilience","persistent","rapid_repair"]:
		status.adaptation_options[id]={"available":true,"expressed":0,"inherited":false}
	inward.status_provider=func() -> Dictionary:return status
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
		_resize(size)
		game_root.set_mode("outward");game_root._outward_view.selected_id=""
		await _capture("outward_%d" % size.x)
		game_root._colony_controls.open_menu()
		await _capture("menu_%d" % size.x)
		game_root._colony_controls.opened=false
		game_root.set_mode("inward");inward.selected_id=""
		await _capture("inward_%d" % size.x)
		inward.selected_id="adaptation";inward.web_selection="foraging"
		for family: String in ["foraging","environment"]:
			inward.activate_at(inward._web_family_rect(family).get_center())
			if inward.web_family!=family:failed=true
			await _capture("web_%s_%d" % [family,size.x])
		inward.selected_id="midden"
		await _capture("midden_%d" % size.x)
	if frozen!=game_root.simulation.run.to_dict():failed=true
	print("[ORGANIC] immutable=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
