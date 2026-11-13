extends "chemical_smoke.gd"
const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")

func _run() -> void:
	create_timer(25).timeout.connect(func() -> void:printerr("FAIL: packed context watchdog");quit(2))
	game_root=Root.new();game_root.simulation=Controller.new(3048)
	var game: SimulationController=game_root.simulation
	assert(game.dispatch_scout("home",0.0));game.advance(670)
	assert(game.create_trail("home","known:carb_exposed"))
	var route: TrailRouteState=game.run.trails.routes.route_1
	for tick: int in 3000:
		if route.conflict_report in ["withdrew","dispersed"] and route.allocated_workers==0:break
		game.advance(0.25)
	assert(game.journey_response.investigate("route_1"))
	for tick: int in 1600:
		if not game.run.journey_response.active():break
		game.advance(0.25)
	game.toggle_pause()
	get_root().content_scale_size=Vector2i(900,600);DisplayServer.window_set_size(Vector2i(900,600))
	var view:=Outward.new();get_root().add_child(view)
	view.signal_provider=game_root.sensory_snapshot.bind("home");view.status_provider=game_root.outward_status.bind("home")
	view.selected_id="threat:route_1";view.journey_open=true;view._process(0)
	view.facing=view._selected_signal().get("bearing",0.0)
	var failed: bool=not game.run.journey_response.reports.has("route_1") or game.run.journey_response.reports.route_1.finding!="foreign"
	failed=failed or Cloud.appearance(view._selected_signal(),false).identity!="foreign_ants"
	var frozen: Dictionary=game.run.to_dict()
	for frame: int in 12:await process_frame
	await RenderingServer.frame_post_draw
	var output: String=OS.get_cmdline_user_args()[0]
	failed=failed or get_root().get_texture().get_image().save_png(output)!=OK
	var signals: Array[Dictionary]=[]
	var status: Dictionary=game_root.outward_status("home");status.trails=[]
	view.signal_provider=func()->Array[Dictionary]:return signals
	view.status_provider=func()->Dictionary:return status
	view.selected_id="";view.journey_open=false;view.facing=0.0
	for group: Array in [["site_loam","site_root","site_stone","site_edge"],["large_animal","dog_like","foreign_ants"]]:
		signals.clear()
		for index: int in group.size():
			var identity: String=group[index]
			var signal_data: Dictionary={"id":"packed:"+identity,"source_knowledge_id":"known:"+identity,"category":"threat","confidence":0.9,"confidence_label":"clear","strength":0.7,"age":5.0,"bearing":(index-(group.size()-1)*0.5)*0.6,"estimated_distance":9.0,"uncertainty_radius":1.0}
			if identity.begins_with("site_"):signal_data.category="nest_site";signal_data.site_profile=identity.trim_prefix("site_")
			elif identity=="foreign_ants":signal_data.threat_kind="foreign"
			else:signal_data.threat_kind="surface";signal_data.passage_impression=identity
			signals.append(signal_data)
		view._process(0)
		for frame: int in 8:await process_frame
		for entry: Dictionary in view._placed:
			var style: Dictionary=Cloud.appearance(entry.signal,false)
			if view.chemical_field.clouds[entry.id].cloud_material.get_shader_parameter("impression_mask")!=Cloud.MASKS[style.identity]:failed=true
		var target: Dictionary=view._placed[1]
		for pointer: String in ["mouse","touch"]:
			view.selected_id="";view._pointer_press(target.center,pointer);view._pointer_release(target.center,pointer)
			if view.selected_id!=target.id:failed=true
		view.selected_id=""
		await RenderingServer.frame_post_draw
		if get_root().get_texture().get_image().save_png(output.get_basename()+"_%s.png"%("shelters" if group.size()==4 else "animals"))!=OK:failed=true
	failed=failed or game.run.to_dict()!=frozen
	print("[PACKED-CONTEXT] native_returned_foreign_and_seven_forms=%s adapter=%s"%[not failed,RenderingServer.get_video_adapter_name()])
	view.free();game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)
