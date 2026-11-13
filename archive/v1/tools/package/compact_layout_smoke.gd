extends "interface_smoke.gd"

func _run() -> void:
	game_root = Root.new(); game_root.simulation = Controller.new(3043)
	game_root.simulation.toggle_pause()
	get_root().content_scale_size = Vector2i(900,600); get_root().size = Vector2i(900,600)
	DisplayServer.window_set_size(Vector2i(900,600))
	# A detached approved-summary geometry fixture; actual mature strategies are
	# covered by the separate integrated native probe, without these substitutions.
	var status: Dictionary = game_root.inward_status("home")
	status.nursery_state = "developed"; status.daughter_available = true
	status.other_pile = "satellite_1"; status.other_pile_name = "Daughter"
	status.nursery_expansion = {"state":"available","capacity":32,"costs":{"carbohydrate":60,"protein":24,"water":12},"workers":8,"duration":180}
	status.guest = {"observation":"loss","reported_losses":1,"workers_required":8,"workers_committed":0,"rejection_active":false}
	var inward = load("res://src/presentation/inward/inward_view.gd").new()
	var calls: Array[String] = []
	inward.status_provider = func() -> Dictionary: return status
	inward.nursery_expand_command = func() -> Dictionary: calls.append("expand"); return {"accepted":false,"reason":"Fixture only"}
	inward.pile_command = func(_id: String) -> bool: calls.append("pile"); return true
	get_root().add_child(inward); inward.selected_id = "nursery"; inward._process(0)
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	await press(inward._nursery_expand_rect().get_center())
	if calls != ["expand"]: failed = true
	await press(inward._pile_rect().get_center())
	if calls != ["expand","pile"]: failed = true
	await press(inward._guest_link_rect().get_center())
	if inward.selected_id != "guest" or calls != ["expand","pile"]: failed = true
	inward.selected_id = "nursery"; inward._feedback = ""
	await picture(OS.get_cmdline_user_args()[0])
	var bounds := Rect2(0,0,900,600)
	for action: Rect2 in [inward._brood_rect(),inward._nursery_expand_rect(),inward._guest_link_rect(),inward._pile_rect()]:
		if not bounds.encloses(action): failed = true
	var outward = load("res://src/presentation/outward/outward_view.gd").new()
	get_root().add_child(outward)
	var reports = load("res://src/presentation/report_controls.gd").new()
	if outward._button_rect("pile").intersects(reports.button_rect()): failed = true
	if game_root.simulation.run.to_dict() != frozen: failed = true
	print("[COMPACT-LAYOUT] separate_native_touch_expansion_nest_harm=true passed=%s build=%s" % [not failed,SaveBuild.current()])
	reports.free(); outward.free(); inward.free(); game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
