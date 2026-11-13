extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Choices = preload("res://src/presentation/inward/development_choices.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const Memory = preload("res://src/presentation/outward/encounter_memory.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Conflict = preload("res://src/presentation/outward/conflict_popover.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	test.get_root().add_child(root)
	var status: Dictionary=root.inward_status("home")
	var entries: Array[Dictionary]=Choices.entries(status,status.chambers)
	test.check(entries.size()==7 and entries[0].id=="food_exchange", "One development overview includes current functions and later dedicated chambers")
	test.check(entries[0].now.contains("already") and entries[1].now.contains("already"), "Basic feeding/care are separated from improvements")
	test.check(entries[2].wait.contains("waste") and entries[3].wait.contains("full Nursery"), "Unready local improvements explain how they become useful")
	var constrained: Dictionary=status.duplicate(true)
	constrained.workers_assignable=0
	test.check(Choices.entries(constrained,constrained.chambers)[0].wait.contains("workers"), "Construction protects care and reports the actual labor shortage")
	var view := View.new()
	test.get_root().add_child(view)
	view._status=status
	var frozen: Dictionary=root.simulation.run.to_dict()
	view.activate_at(view.chamber_controls.button().get_center())
	test.check(view.chamber_controls.opened and root.simulation.run.to_dict()==frozen, "Development inspection is free and modal")
	view._status.connections=[{"id":"test_link"}]
	view.activate_at(view.connection_controls.button(view.get_viewport_rect().size).get_center())
	test.check(view.chamber_controls.opened and not view.connection_controls.opened, "A grown network launcher cannot intercept the construction modal")
	view.activate_at(view.refuge_controls.button().get_center())
	test.check(view.chamber_controls.opened and not view.refuge_controls.opened, "Refuge controls cannot steal an improvement selection")
	view._status.connections=[]
	for size: Vector2 in [Vector2(900,600),Vector2(1280,720),Vector2(1920,1080)]:
		for i: int in entries.size():
			var target: Rect2=view.chamber_controls.rect(size,"row",i)
			test.check(target.size.y>=44 and view.chamber_controls.panel(size).encloses(target), "Every improvement keeps a separate contained touch target")
	view.chamber_controls.opened=false
	view.selected_id="adaptation"
	view.activate_at(Web.positions(view.get_viewport_rect().size).persistent)
	test.check(view.web_selection=="persistent" and not Web.known(status,"persistent") and not view._can_choose_adaptation(), "Undiscovered slots can be inspected without revealing/buying their contents")
	test.check(Web.visible_nodes(status).size()==11 and Web.trait_state(status,"persistent")=="Undiscovered", "All ten trait slots share one graph with anonymous locked variation")
	test.check(root.simulation.run.to_dict()==frozen, "Web/overview interaction never changes run or RNG")
	var route: Dictionary={"id":"r","destination_knowledge_id":"food","last_loss_time":10.0,"last_witness_time":10.0,"conflict_report":"","conflict_received_at":0.0}
	var signals: Array[Dictionary]=[{"id":"threat:r","category":"threat","threat_kind":"ambush","source_knowledge_id":"food"}]
	var state: Dictionary={"trails":[route],"journey_response":{"reports":{"r":{"received_at":10.0}},"outcomes":{}}}
	var original: Array[Dictionary]=signals.duplicate(true)
	var memory := Memory.new()
	test.check(memory.apply(signals,state,0).size()==1, "Unresolved delivered danger remains visible")
	memory.notices(state)
	state.journey_response.outcomes.r={"outcome":"secured","goal":"clear","received_at":20.0,"sent":8,"lost":1}
	var fading: Array[Dictionary]=memory.apply(signals,state,1)
	test.check(fading.size()==1 and fading[0].memory_resolved and fading[0].memory_alpha>0 and fading[0].memory_alpha<1, "A returned win fades the old cloud using presentation time")
	test.check(memory.notices(state)[0].contains("7/8") and memory.notices(state).is_empty(), "One returned result states survival and does not repeat every frame")
	test.check(memory.apply(signals,state,2).is_empty(), "Resolved combat memory disappears after its fade")
	var baseline := Memory.new()
	test.check(baseline.apply(signals,state,0).is_empty() and baseline.notices(state).is_empty(), "Loaded old victories neither reappear nor announce a new win")
	state.journey_response.reports.r.received_at=30.0
	test.check(memory.apply(signals,state,0).size()==1, "New returned danger restores the impression after an old victory")
	test.check(signals==original, "Memory fading never mutates provider-owned signal data")
	var placed: Array[Dictionary]=[{"id":"danger","center":Vector2(10,10),"radius":50,"signal":{"category":"threat"}},{"id":"source","center":Vector2(35,10),"radius":30,"signal":{"category":"protein"}}]
	test.check(Panorama.pick(placed,Vector2(10,10))=="source", "A resource stays clickable under an overlapping encounter")
	placed[0].signal.memory_resolved=true
	placed.remove_at(1)
	test.check(Panorama.pick(placed,Vector2(10,10)).is_empty(), "Fading resolved memories cannot intercept clicks")
	var popover := Conflict.new()
	state.journey_response.reports.r.received_at=10.0
	test.check(popover.progress_lines(route,state)[0].contains("7/8") and popover.progress_lines(route,state)[1].contains("gathering"), "Returned victory explains losses and the next useful action")
	state.journey_response.recruitment={"r":{"reserved":2,"requested":8,"returning":6}}
	test.check(popover.progress_lines(route,state)[0].contains("2/8") and popover.progress_lines(route,state)[1].contains("6"), "Recruiting and travelers are separate from a sent response")
	var field := Outward.new()
	test.get_root().add_child(field)
	var notice_status: Dictionary={"journey_response":{"outcomes":{}}}
	field.signal_provider=func() -> Array[Dictionary]: return []
	field.status_provider=func() -> Dictionary: return notice_status
	field._process(0); field.hide()
	notice_status.journey_response.outcomes.r={"outcome":"secured","received_at":20.0,"sent":16,"lost":4}
	field._process(0)
	test.check(not field._pending_combat_notice.is_empty() and field._feedback.is_empty(), "An outcome arriving while INWARD waits to be shown")
	field.show(); field._process(0)
	test.check(field._pending_combat_notice.is_empty() and field._feedback.contains("12/16"), "Returning OUTWARD shows the retained survival result once")
	field.free()
	var viewport := SubViewport.new()
	viewport.size=Vector2i(900,600);test.get_root().add_child(viewport)
	var compact := Outward.new()
	viewport.add_child(compact)
	compact._signals=[{"id":"source","category":"carbohydrate","source_knowledge_id":"food"}]
	compact.selected_id="source"
	for honey: bool in [false,true]:
		compact._status={"honeydew":{"knowledge_id":"food"} if honey else {}}
		var panel: Rect2=compact._context_panel_rect()
		test.check(not panel.intersects(compact._button_rect("inward")), "Compact source facts stay above persistent navigation")
		for target: Rect2 in [compact._trail_button_rect("gather_edit"),compact._trail_button_rect("trail_cancel"),compact._investigate_button_rect(),compact._journey_rect("journey_open")]:
			test.check(panel.encloses(target) and target.size.y>=44, "Compact gathering, recall, recheck and journey actions stay contained and clickable")
		if honey:test.check(panel.encloses(compact._honeydew_button_rect()), "Aphid staffing retains its own compact target")
	viewport.free()
	view.free(); root.free()
	return true
