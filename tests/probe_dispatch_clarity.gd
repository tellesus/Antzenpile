extends "res://tests/probe_neon_trails.gd"
const GatheringFixture = preload("res://tests/test_gathering_orders.gd")
const DaughterFixture = preload("res://tests/test_daughter_gathering.gd")

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	output_dir="res://.godot/card181"
	DirAccess.make_dir_recursive_absolute(output_dir)
	game_root=Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	var view: OutwardView=game_root._outward_view
	for scene: String in ["fresh","queued","reduce","rejected"]:
		game_root.simulation=GatheringFixture.new().ready()
		game_root.simulation.toggle_pause()
		var pile: PileState=game_root.simulation.run.colony.piles.home
		if scene=="queued":
			pile.workers.create_commitment("probe:busy","internal","home")
			pile.allocate_workers("probe:busy",pile.workers_assignable-2)
			game_root.order_gathering("known:carb_sheltered",7)
		elif scene=="reduce": game_root.order_gathering("known:carb_sheltered",13)
		game_root.set_mode("outward")
		view.selected_id="signal:known:carb_sheltered"
		view._process(0)
		view.facing=view._selected_signal().bearing
		view._run_command("trail_create")
		if scene=="reduce":view.gathering_draft.amount=5
		var frozen: Dictionary=game_root.simulation.run.to_dict()
		if scene=="rejected":
			view.gathering_draft.amount=500
			view._run_command("gather_commit")
			view.gathering_draft.amount=5
		for size: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,600)]:
			_resize(size)
			await _capture("%s_%d" % [scene,size.x])
			if not view.gathering_draft.panel(Vector2(size)).end.y<=size.y-112:failed=true
		if game_root.simulation.run.to_dict()!=frozen:failed=true
	game_root.simulation=DaughterFixture.new().fixture()
	game_root.simulation.toggle_pause()
	game_root.inward_pile_id="satellite_1"
	game_root.set_mode("inward")
	var inward: InwardView=game_root._inward_view
	inward.selected_id="food_exchange"
	inward._process(0)
	inward.gathering.opened=true
	inward.gathering.selected="known:carb_exposed"
	inward.gathering.draft.begin("known:carb_exposed",0,40)
	var frozen: Dictionary=game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(900,600)]:
		_resize(size)
		await _capture("daughter_%d" % size.x)
	if game_root.simulation.run.to_dict()!=frozen:failed=true
	print("[DISPATCH] native_layout_free_drafts_immutable=%s adapter=%s" % [not failed,RenderingServer.get_video_adapter_name()])
	game_root.free()
	for frame: int in 4:await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
