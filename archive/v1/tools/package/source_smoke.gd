extends "chemical_smoke.gd"
## Exercise actual delivered identity and all source-mask bindings in the release PCK.
const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")

func _run() -> void:
	game_root=Root.new();game_root.simulation=Controller.new(482817)
	var game: SimulationController=game_root.simulation
	game.dispatch_scout("home",PI)
	for tick: int in 800:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:carb_sheltered"):break
	if not game.create_trail("home","known:carb_sheltered"):quit(1);return
	for tick: int in 800:
		game.advance(0.25)
		if not game.run.knowledge.nodes["known:carb_sheltered"].source_type.is_empty():break
	game.toggle_pause()
	get_root().content_scale_size=Vector2i(900,600);get_root().size=Vector2i(900,600)
	var view:=Outward.new();get_root().add_child(view)
	view.signal_provider=game_root.sensory_snapshot.bind("home");view.status_provider=game_root.outward_status.bind("home")
	view.facing=PI;view._process(0)
	var failed: bool=true
	for signal_data: Dictionary in view._signals:
		if signal_data.source_knowledge_id=="known:carb_sheltered":failed=Cloud.appearance(signal_data,false).identity!="nectar"
	var frozen: Dictionary=game.run.to_dict()
	for frame: int in 15:await process_frame
	await RenderingServer.frame_post_draw
	var output: String=OS.get_cmdline_user_args()[0]
	failed=failed or get_root().get_texture().get_image().save_png(output)!=OK
	var signals: Array[Dictionary]=[]
	var status: Dictionary=game_root.outward_status("home");status.trails=[]
	view.signal_provider=func()->Array[Dictionary]:return signals
	view.status_provider=func()->Dictionary:return status
	view.facing=0.0
	var types: Array=Cloud.SOURCE_FORMS.keys()
	for group: int in 2:
		signals.clear()
		for i: int in 5:
			var type: String=types[group*5+i]
			signals.append({"id":"packed:"+type,"source_knowledge_id":"known:"+type,"source_type":type,"category":SourceCatalog.PROFILES[type].resource_id,"confidence":0.9,"confidence_label":"clear","strength":0.8,"age":10.0,"bearing":-0.96+i*0.48,"estimated_distance":9.0,"uncertainty_radius":1.0})
		view._process(0)
		for frame: int in 8:await process_frame
		for entry: Dictionary in view._placed:
			var cloud: ChemicalCloud=view.chemical_field.clouds[entry.id]
			if cloud.cloud_material.get_shader_parameter("impression_mask")!=Cloud.MASKS[Cloud.SOURCE_FORMS[entry.signal.source_type]]:failed=true
		var target: Dictionary=view._placed[2]
		for pointer: String in ["mouse","touch"]:
			view.selected_id="";view._pointer_press(target.center,pointer);view._pointer_release(target.center,pointer)
			if view.selected_id!=target.id:failed=true
		view.selected_id=""
		for frame: int in 8:await process_frame
		await RenderingServer.frame_post_draw
		if get_root().get_texture().get_image().save_png(output.get_basename()+"_gallery_%d.png" % group)!=OK:failed=true
	if game.run.to_dict()!=frozen:failed=true
	print("[PACKED-SOURCES] native_returned_source_forms=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	view.free();game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)
