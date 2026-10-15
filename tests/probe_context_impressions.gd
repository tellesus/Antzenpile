extends "res://tests/probe_neon_trails.gd"
const Context = preload("res://tests/test_context_impressions.gd")
const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")
const Nest = preload("res://tests/test_nest_sites.gd")
const Impact = preload("res://tests/test_surface_disturbance.gd")

func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output_dir="res://.godot/card188";DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new();get_root().add_child(game_root);game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var view: OutwardView=game_root._outward_view
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	var signals: Array[Dictionary]=[]
	var status: Dictionary=game_root.outward_status("home");status.paused=true
	view.signal_provider=func()->Array[Dictionary]:return signals
	view.status_provider=func()->Dictionary:return status
	for group: Array in [["site_loam","site_root","site_stone","site_edge"],["large_animal","dog_like","foreign_ants"]]:
		signals.clear()
		for index: int in group.size():
			var s: Dictionary=Context.new().sample(group[index])
			s.merge({"id":"context:"+group[index],"source_knowledge_id":"known:"+group[index],"confidence_label":"clear","bearing":(index-(group.size()-1)*0.5)*0.6,"estimated_distance":9.0,"uncertainty_radius":1.0})
			signals.append(s)
		for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
			_resize(size);view._animation_time=11.0;await _capture("%s_%d"%["shelters" if group.size()==4 else "animals",size.x])
			var target: Dictionary=view._placed[1]
			for pointer: String in ["mouse","touch"]:
				view.selected_id="";view._pointer_press(target.center,pointer);view._pointer_release(target.center,pointer)
				if view.selected_id!=target.id:failed=true
			view.selected_id=""
	_resize(Vector2i(1280,720))
	var original: Array[Dictionary]=signals.duplicate(true)
	for variant: String in ["weak","stale","generic"]:
		for s: Dictionary in signals:
			s.confidence=0.2 if variant=="weak" else 0.9;s.age=1800.0 if variant=="stale" else 5.0
			if variant=="generic":s.erase("passage_impression");s.threat_kind=""
		await _capture(variant)
		for s: Dictionary in signals:
			if not Cloud.appearance(s,false).identity.is_empty():failed=true
	signals.assign(original);view._animation_time=12.0;await _capture("motion")
	await create_timer(0.4).timeout;await RenderingServer.frame_post_draw
	var pixels: PackedByteArray=get_root().get_texture().get_image().get_data()
	for frame: int in 12:await process_frame
	await RenderingServer.frame_post_draw
	if pixels!=get_root().get_texture().get_image().get_data():failed=true
	view.facing=PI;await _capture("rear")
	if not view.chemical_field.clouds.is_empty() or game_root.simulation.run.to_dict()!=frozen:failed=true
	view.facing=0.0
	await _actual()
	print("[CONTEXT] returned_forms_layout_input_private_pause=%s adapter=%s"%[not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout;quit(1 if failed else 0)

func _actual() -> void:
	var view: OutwardView=game_root._outward_view
	view.signal_provider=game_root.focused_outward_signals;view.status_provider=game_root.focused_outward_status
	var game: SimulationController=Nest.new().fixture();game.run.world.nodes.nest_site_01.site_profile="root"
	while not game.run.scouts.is_empty():game.advance(0.25)
	game_root.simulation=game
	view._process(0);view.facing=view._signals[0].bearing
	await _capture("actual_root_1280")
	game=Impact.new().fixture();game_root.simulation=game
	var route: TrailRouteState=game.run.trails.routes.route_1
	while route.passage_memory.count<1:game.advance(0.25)
	await _actual_threat("actual_large")
	game.set_trail_workers("route_1",0)
	while route.allocated_workers>0:game.advance(0.25)
	var second: float=(SurfaceImpactState.first_tick(game.run.run_seed)+SurfaceImpactState.CONFIG.interval_ticks)*SimulationClock.TICK_INTERVAL
	game.advance(maxf(0,second-game.run.simulation_time));assert(game.journey_response.investigate("route_1"))
	while game.run.journey_response.active():game.advance(0.25)
	await _actual_threat("actual_dog")
	game=Context.new().foreign_game();game_root.simulation=game
	while game.run.journey_response.active():game.advance(0.25)
	await _actual_threat("actual_foreign")

func _actual_threat(tag: String) -> void:
	var view: OutwardView=game_root._outward_view
	game_root.simulation.toggle_pause();view._process(0)
	view.selected_id="threat:route_1";view.journey_open=true;view.conflict.reset()
	view.facing=view._selected_signal().get("bearing",0.0)
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(900,600)]:
		_resize(size);await _capture(tag+"_%d"%size.x)
	game_root.simulation.toggle_pause();view.selected_id="";view.journey_open=false
