extends "res://tests/probe_neon_trails.gd"
const Identity = preload("res://tests/test_resource_identity.gd")
const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")

func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output_dir="res://.godot/card184";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	var view: OutwardView=game_root._outward_view
	var groups: Array=[ ["flower_nectar","aphid_honeydew","ripe_fruit","cracked_seeds","picnic_crumbs"], ["dew_drops","rain_puddle","sheltered_seep","insect_remains","hunted_arthropod"] ]
	var signals: Array[Dictionary]=[]
	var status: Dictionary=game_root.outward_status("home");status.paused=true
	view.signal_provider=func()->Array[Dictionary]:return signals
	view.status_provider=func()->Dictionary:return status
	for group: int in groups.size():
		signals.clear()
		for i: int in groups[group].size():
			var type: String=groups[group][i]
			signals.append({"id":"source:"+type,"source_knowledge_id":"known:"+type,"source_type":type,"category":SourceCatalog.PROFILES[type].resource_id,"confidence":0.9,"confidence_label":"clear","strength":0.8,"age":10.0,"bearing":-0.96+i*0.48,"estimated_distance":9.0,"uncertainty_radius":1.0})
		for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
			_resize(size);view._animation_time=11.0
			await _capture("sources_%d_%d" % [group,size.x])
			var target: Dictionary=view._placed[2]
			for pointer: String in ["mouse","touch"]:
				view.selected_id="";view._pointer_press(target.center,pointer);view._pointer_release(target.center,pointer)
				if view.selected_id!=target.id:failed=true
			await _capture("selected_%d_%d" % [group,size.x])
			view.selected_id=""
	_resize(Vector2i(1280,720))
	for variant: String in ["weak","stale","unknown","empty"]:
		status.temporal_hints={}
		for signal_data: Dictionary in signals:
			signal_data.confidence=0.2 if variant=="weak" else 0.9
			signal_data.age=1800.0 if variant=="stale" else 10.0
			if variant=="unknown":signal_data.source_type=""
			if variant=="empty":status.temporal_hints[signal_data.source_knowledge_id]={"has_report":true,"last_return_empty":true}
		await _capture(variant)
	status.temporal_hints={}
	signals.clear()
	for i: int in 3:
		var type: String=["flower_nectar","ripe_fruit","dew_drops"][i]
		signals.append({"id":"source:"+type,"source_knowledge_id":"known:"+type,"source_type":type,"category":SourceCatalog.PROFILES[type].resource_id,"confidence":0.9,"confidence_label":"clear","strength":0.8,"age":10.0,"bearing":-0.7+i*0.7,"estimated_distance":9.0,"uncertainty_radius":1.0})
	for i: int in 36:
		view._animation_time=11.0+i*0.07;await _capture("motion_%03d" % i)
	for frame: int in 20:await process_frame
	await RenderingServer.frame_post_draw
	var paused: PackedByteArray=get_root().get_texture().get_image().get_data()
	for frame: int in 12:await process_frame
	await RenderingServer.frame_post_draw
	if paused!=get_root().get_texture().get_image().get_data():failed=true
	view.facing=PI;await _capture("rear")
	if not view.chemical_field.clouds.is_empty():failed=true
	if frozen!=game_root.simulation.run.to_dict():failed=true
	await _actual_return()
	print("[SOURCES] native_layout_input_age_pause_return=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)

func _actual_return() -> void:
	game_root.simulation=SimulationController.new(482817)
	var game: SimulationController=game_root.simulation
	game.advance(0.25)
	var evidence: Observation=Identity.new().sample(game,1,Vector2(11.25,20),game.run.simulation_time)
	assert(Identity.new().archive(game.run.knowledge,evidence,game.run.simulation_time));game.run.next_scout_id=2
	assert(game.create_trail("home","known:carb_sheltered"))
	var captured: bool=false
	for tick: int in 240:
		game.advance(0.25)
		for cohort: TransitCohort in game.run.trails.cohorts.values():
			if cohort.harvest_report!=null:captured=true
		if captured:break
	var view: OutwardView=game_root._outward_view
	view.signal_provider=game_root.focused_outward_signals;view.status_provider=game_root.focused_outward_status
	view.facing=PI;game.toggle_pause();await _capture("private_sample")
	if not Cloud.appearance(view._signals[0],false).identity.is_empty():failed=true
	game.toggle_pause()
	for tick: int in 240:
		game.advance(0.25)
		if not game.run.knowledge.nodes["known:carb_sheltered"].source_type.is_empty():break
	game.toggle_pause();await _capture("returned_nectar")
	if Cloud.appearance(view._signals[0],false).identity!="nectar":failed=true
