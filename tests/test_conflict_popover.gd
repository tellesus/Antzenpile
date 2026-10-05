extends RefCounted
const Popover = preload("res://src/presentation/outward/conflict_popover.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Root = preload("res://src/core/game_root.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")

func run(test: Object) -> bool:
	var game: SimulationController=Defense.new().ready_game()
	var root := Root.new(); root.simulation=game
	var view := View.new(); test.get_root().add_child(view)
	view._signals=root.sensory_snapshot("home"); view._status=root.outward_status("home"); view.selected_id="threat:route_1"
	view.signal_provider=root.sensory_snapshot.bind("home"); view.status_provider=root.outward_status.bind("home")
	view.journey_command=root.respond_to_journey; view.trail_set_command=root.set_trail_target
	var frozen: Dictionary=game.run.to_dict()
	view.selected_id=""
	for signal_data: Dictionary in view._signals:
		if signal_data.id=="threat:route_1": view.facing=signal_data.bearing
	view._process(0)
	var markers: Array[Dictionary]=View.Scent.alarm_markers(view._status.trails,view._placed,view.get_viewport_rect().size)
	test.check(not markers.is_empty(), "Ordinary returned threat creates a selectable journey alarm")
	if not markers.is_empty():
		for pointer: String in ["mouse","touch"]:
			view.selected_id=""; view.journey_open=false
			view._pointer_press(markers[0].center,pointer); view._pointer_release(markers[0].center,pointer)
			test.check(view.journey_open and view._journey_attention() and game.run.to_dict()==frozen, "One tap on the alarm opens direct conflict actions for "+pointer)
	view.selected_id="threat:route_1"
	for pointer: String in ["mouse","touch"]:
		view.conflict.reset()
		view._pointer_press(view._conflict_rect("conflict_send").get_center(),pointer)
		test.check(view.conflict.editing and not view.conflict.all_hands and game.run.to_dict()==frozen, "Radial send opens a free draft with all hands off for "+pointer)
		view._pointer_press(view._conflict_rect("draft_more").get_center(),pointer)
		test.check(view.conflict.amount==13, "Single-ant staffing adjustment shares mouse/touch behavior")
		view._pointer_press(view._conflict_rect("draft_all").get_center(),pointer)
		test.check(view.conflict.all_hands and game.run.to_dict()==frozen, "All-hands permission is an explicit draft choice, not an immediate job recall")
		view._pointer_press(view._conflict_rect("draft_back").get_center(),pointer)
		view._pointer_press(view._conflict_rect("conflict_reports").get_center(),pointer)
		test.check(view.conflict.history_open and game.run.to_dict()==frozen, "Report history is separate attention with no worker mutation")
	var popover := Popover.new()
	for size: Vector2 in [Vector2(1280,720),Vector2(900,600)]:
		for mode: String in ["status","draft","history"]:
			popover.editing=mode=="draft"; popover.history_open=mode=="history"
			var positions: Dictionary=popover.layout(size)
			var field := Rect2(Vector2(0,140),Vector2(size.x,size.y-250))
			test.check(field.encloses(positions.bounds), "Conflict status/actions fit above time controls at %s/%s" % [size,mode])
			var boxes: Array[Rect2]=[]
			for command: String in positions.buttons:
				var box: Rect2=positions.buttons[command]
				test.check(box.size.x>=44 and box.size.y>=44, "Every radial/draft target retains touch-sized input")
				if (popover.editing or popover.history_open) and not command.begins_with("draft_") and positions.editor.intersects(box): continue
				for previous: Rect2 in boxes: test.check(not box.intersects(previous), "Visible pop-over actions have distinct input areas")
				boxes.append(box)
			for command: String in positions.buttons:
				if command.begins_with("draft_"): test.check(popover.button_at(positions.buttons[command].get_center(),size)==command, "Draft actions absorb underlying radial input")
	popover.editing=false; popover.history_open=false
	var route: Dictionary=view._conflict_route()
	var status: Dictionary=view._status.duplicate(true)
	status.journey_response.reports.clear()
	test.check(popover._identity(route,status)=="Unidentified threat" and not popover.reason("conflict_send",route,status).is_empty(), "Unidentified danger cannot acquire a predator picture or an unexplained force action")
	route.surface_warning=true
	test.check(popover._identity(route,status)=="Surface disturbance" and not popover.reason("conflict_send",route,status).is_empty(), "Impact evidence stays an unassailable impression without an invented animal name")
	_check_report_order(test,popover)
	view.free(); root.free()
	return true

func _check_report_order(test: Object, popover: RefCounted) -> void:
	var route: Dictionary={"id":"r","last_loss_time":5}
	var status: Dictionary={"time":100,"journey_response":{"away":false,
		"outcomes":{"r":{"outcome":"withdrew","sent":13,"lost":1,"observed_at":15,"received_at":20}},
		"reports":{"r":{"finding":"ambush","observed_at":25,"received_at":30}},
		"pressure_reports":{"r":{"pressure":"resisted","observed_at":10,"received_at":18}},
		"approach_reports":{"r":{"outcome":"found","received_at":40}}}}
	test.check(popover._latest(route,status).text=="Alternate course established", "A newer returned approach leads the center instead of an older defensive ending")
	status.journey_response.approach_reports.clear()
	test.check(popover._latest(route,status).text=="Predator witnessed", "A fresh survey supersedes older defensive history")
	status.journey_response.merge({"away":true,"route_id":"r","mode":"defend","age":10},true)
	test.check(popover._latest(route,status).text=="Awaiting the party's report", "A new response cannot display a previous attempt's pressure as its current update")
	status.journey_response.pressure_reports.r={"pressure":"holding","observed_at":95,"received_at":99}
	test.check(popover._latest(route,status).text=="Holding against resistance", "A messenger from the current attempt updates the center only after delivery")
