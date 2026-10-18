extends "res://tests/probe_neon_trails.gd"
const Defense201 = preload("res://tests/test_ambusher_defense.gd")

func _run() -> void:
	output_dir="res://.godot/card201/native"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new(); get_root().add_child(game_root); game_root.set_process(false)
	game_root.simulation.toggle_pause()
	game_root.simulation.run.colony.piles.home.deposit_resource("carbohydrate",20)
	var inward: InwardView=game_root._inward_view
	game_root.set_mode("inward"); inward._process(0)
	_resize(Vector2i(900,600))
	inward.activate_at(inward.chamber_controls.button().get_center())
	await _capture("construction_ready_900")
	var carbs: float=game_root.simulation.run.colony.piles.home.resources.carbohydrate
	inward.activate_at(inward.chamber_controls.rect(get_root().size,"order").get_center())
	inward._process(0)
	if game_root.simulation.run.colony.piles.home.food_exchange_state!="developing" or game_root.simulation.run.colony.piles.home.resources.carbohydrate>=carbs: failed=true
	await _capture("construction_building_900")
	var saved: Dictionary=game_root.simulation.run.to_dict()
	if not game_root.quick_save().accepted or not game_root.quick_load().accepted or game_root.simulation.run.to_dict()!=saved: failed=true
	print("[CLARITY201] real_build_and_same_build_reload=%s" % (not failed))
	# Detached presentation fixtures show every brood stage and later web state.
	var visual: Dictionary=game_root.inward_status("home")
	visual.brood=[]
	for stage: String in ["egg","larva","pupa"]: visual.brood.append({"stage":stage,"count":3,"care":1.0,"nutrition":1.0,"progress_seconds":10})
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	inward.status_provider=func() -> Dictionary: return visual
	for size: Vector2i in [Vector2i(900,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		_resize(size); game_root.set_mode("inward")
		inward.chamber_controls.opened=false; inward.selected_id=""
		await _capture("brood_%d" % size.x)
		inward.chamber_controls.opened=true; inward.chamber_controls.selected="midden"
		await _capture("construction_midden_%d" % size.x)
		if size.x==900:
			visual.midden.revealed=true
			await _capture("construction_open_heap_900")
			visual.midden.revealed=false
		inward.chamber_controls.opened=false; inward.selected_id="adaptation"; inward.web_selection="foraging"
		await _capture("web_initial_%d" % size.x)
		inward.activate_at(AdaptationWeb.positions(Vector2(size)).persistent)
		if inward.web_selection!="persistent" or inward._can_choose_adaptation(): failed=true
		await _capture("web_unknown_%d" % size.x)
	for id: String in TraitCatalog.IDS:
		visual.adaptation_options[id]={"available":true,"inherited":false,"expressed":0,"costs":visual.adaptation_costs}
	for size: Vector2i in [Vector2i(900,600),Vector2i(1280,720)]:
		_resize(size); inward.web_selection="lean"
		await _capture("web_known_%d" % size.x)
	if game_root.simulation.run.to_dict()!=frozen: failed=true
	# Real encounter: inspect -> choose sixteen -> SEND -> real travel/report.
	game_root.simulation=Defense201.new().ready_game()
	game_root._refresh_loaded_views(); game_root.set_mode("outward")
	var outward: OutwardView=game_root._outward_view
	outward.selected_id="threat:route_1"; outward._process(0)
	_resize(Vector2i(900,600)); await _capture("combat_before_900")
	outward._run_conflict_command("conflict_send")
	outward.conflict.amount=16
	outward._run_conflict_command("draft_commit")
	for tick: int in 2400:
		if game_root.simulation.run.journey_response.defense.outcomes.has("route_1"): break
		game_root.simulation.advance(.25)
	var outcome: Dictionary=game_root.simulation.run.journey_response.defense.outcomes.get("route_1",{})
	if outcome.get("outcome","")!="secured": failed=true
	outward._process(0)
	await _capture("combat_return_900")
	await create_timer(3.3).timeout
	for signal_data: Dictionary in outward._signals:
		if signal_data.id=="threat:route_1": failed=true
	var target: Dictionary={}
	for entry: Dictionary in outward._placed:
		if entry.signal.category in ["carbohydrate","protein","water"]: target=entry; break
	if target.is_empty(): failed=true
	else:
		outward.selected_id=""; outward.journey_open=false
		outward._pointer_press(target.center,"mouse"); outward._pointer_release(target.center,"mouse")
		if outward.selected_id!=target.id: failed=true
	await _capture("combat_faded_source_clickable_900")
	var context: Rect2=outward._context_panel_rect()
	if context.intersects(outward._button_rect("inward")): failed=true
	var before_draft: Dictionary=game_root.simulation.run.to_dict()
	outward._pointer_press(outward._trail_button_rect("trail_create").get_center(),"mouse")
	if not outward.gathering_draft.opened or game_root.simulation.run.to_dict()!=before_draft: failed=true
	outward.gathering_draft.opened=false
	print("[CLARITY201] real_response=%s returned=%d sent=%d resolved_fade_and_source_click=%s graphics=%s" % [outcome.get("outcome","missing"),outcome.get("sent",0)-outcome.get("lost",0),outcome.get("sent",0),not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(.3).timeout
	quit(1 if failed else 0)
