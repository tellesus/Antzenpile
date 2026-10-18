extends SceneTree
## External development check of the unchanged pack; no excluded fixtures/debug UI.
const Root = preload("res://src/core/game_root.gd")
const Inward = preload("res://src/presentation/inward/inward_view.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const Memory = preload("res://src/presentation/outward/encounter_memory.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
var failed: bool=false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	get_root().content_scale_size=Vector2i(900,600);get_root().size=Vector2i(900,600)
	# Root stays detached so the editor's excluded debug view is never composed.
	# Real packed summaries/commands and native InwardView are used unchanged.
	var game := Root.new(); game.simulation=Controller.new(3043)
	game.simulation.run.colony.piles.home.deposit_resource("carbohydrate",20)
	var view := Inward.new(); game._inward_view=view
	view.status_provider=game.focused_inward_status
	view.develop_command=game.start_food_exchange
	view.chamber_command=game.order_chamber
	get_root().add_child(view);view._process(0)
	view.activate_at(view.chamber_controls.button().get_center())
	view.activate_at(view.chamber_controls.rect(Vector2(900,600),"order").get_center())
	if game.simulation.run.colony.piles.home.food_exchange_state!="developing": failed=true
	var frozen: Dictionary=game.simulation.run.to_dict()
	if not game.quick_save().accepted or not game.quick_load().accepted or game.simulation.run.to_dict()!=frozen: failed=true
	game.set_mode("inward");view._process(0);view.selected_id="adaptation"
	if not view.visible: failed=true
	view.activate_at(Web.positions(Vector2(900,600)).persistent)
	if view.web_selection!="persistent" or Web.known(view._status,"persistent") or view._can_choose_adaptation(): failed=true
	var out_dir: String=OS.get_environment("ANTZENPILE_PROBE_OUT")
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
		for frame: int in 4: await process_frame
		await RenderingServer.frame_post_draw
		if get_root().get_texture().get_image().save_png(out_dir.path_join("web_900.png"))!=OK: failed=true
	var status: Dictionary={"trails":[{"id":"r","destination_knowledge_id":"food","last_loss_time":1,"last_witness_time":1}],"journey_response":{"reports":{"r":{"received_at":1}},"outcomes":{}}}
	var signals: Array[Dictionary]=[{"id":"threat:r","source_knowledge_id":"food","category":"threat","threat_kind":"ambush"}]
	var memory := Memory.new();memory.apply(signals,status,0)
	status.journey_response.outcomes.r={"outcome":"secured","received_at":2}
	var faded: Array[Dictionary]=memory.apply(signals,status,1)
	if faded.size()!=1 or not faded[0].memory_resolved or not memory.apply(signals,status,2).is_empty(): failed=true
	var placed: Array[Dictionary]=[{"id":"danger","center":Vector2(10,10),"radius":50,"signal":{"category":"threat"}},{"id":"food","center":Vector2(30,10),"radius":30,"signal":{"category":"carbohydrate"}}]
	if Panorama.pick(placed,Vector2(10,10))!="food": failed=true
	if game.simulation.run.to_dict()!=frozen: failed=true
	print("[CLARITY-PACK] native_web_question_marks_real_build_save_load_resolved_fade_resource_pick=%s build=%s" % [not failed,SaveBuild.current()])
	view.free();game.free()
	for frame: int in 4:await process_frame
	await create_timer(.3).timeout
	quit(1 if failed else 0)
