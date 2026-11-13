extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Reports=preload("res://src/presentation/report_controls.gd")
const Pressure=preload("res://src/presentation/colony_pressure.gd")
const Defense=preload("res://tests/test_ambusher_defense.gd")
const Rival=preload("res://tests/test_rival_contact.gd")
func snapshot(game: SimulationController) -> Dictionary: return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func core(game: SimulationController) -> Dictionary:
	var result: Dictionary=game.run.to_dict();result.erase("reports");return result

func run(test: Object) -> bool:
	var game:=Controller.new(482817)
	test.check(game.run.reports.entries.is_empty() and game.dispatch_scout("home",PI),"A new journal records no hidden initial world and sends an ordinary scout")
	for i: int in 500:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:carb_sheltered"): break
		for entry: Dictionary in game.run.reports.entries: test.check(entry.kind!="source","Unreturned scout findings cannot create a report")
	var source: Dictionary={}
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="source" and entry.subject_id=="known:carb_sheltered": source=entry
	test.check(not source.is_empty() and source.received_at>=source.observed_at and source.unread,"Actual returning evidence becomes dated persistent unread history")
	var journal_before: Dictionary=game.run.reports.to_dict()
	var qty: float=game.run.world.nodes.carb_sheltered.quantity
	game.run.world.nodes.carb_sheltered.quantity=0;game.reports.capture()
	test.check(game.run.reports.to_dict()==journal_before,"Hidden source depletion cannot update the semantic journal")
	game.run.world.nodes.carb_sheltered.quantity=qty
	test.check(game.create_trail("home","known:carb_sheltered"),"Journal intake test uses actual paid gathering")
	game.advance(60)
	var receipts: Array[Dictionary]=[]
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="intake": receipts.append(entry)
	test.check(receipts.size()==1 and receipts[0].repeats>1 and receipts[0].total>=receipts[0].amount,"Routine actual deliveries coalesce as recorded totals rather than flooding history")
	var root:=Root.new();root.simulation=game
	var before: Dictionary=core(game)
	test.check(root.mark_reports_read(0).accepted and game.run.reports.unread_count()==0 and core(game)==before,"Acknowledgment changes only saved report metadata, never food/workers/RNG/orders")
	var twin:=Controller.new()
	test.check(twin.restore_snapshot(snapshot(game)) and twin.run.to_dict()==game.run.to_dict(),"Journal records and read/group state restore exactly")
	for i: int in 40:
		game.advance(0.25);twin.advance(0.25)
		test.check(game.run.to_dict()==twin.run.to_dict(),"Saved journal collection follows exact ongoing physical work")
	var saved: Dictionary=snapshot(game)
	for gate: String in ["kind","future","pile","unread","duplicate","seen"]:
		var broken: Dictionary=saved.duplicate(true)
		var entry: Dictionary=JSON.parse_string(broken.reports.records[0])
		match gate:
			"kind": entry.kind="world_truth"
			"future": entry.received_at=game.run.simulation_time+1
			"pile": entry.pile_id="missing"
			"unread": entry.unread="yes"
			"duplicate": broken.reports.records.append(broken.reports.records[0])
			"seen": broken.reports.seen["world/truth"]=1
		broken.reports.records[0]=JSON.stringify(entry,"",true,true)
		var frozen: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==frozen,"Malformed journal "+gate+" rejects atomically")
	var legacy: Dictionary=saved.duplicate(true);legacy.erase("reports")
	test.check(twin.restore_snapshot(legacy) and twin.run.reports.entries.is_empty() and twin.run.reports.since==twin.run.simulation_time,"Legacy loading begins a journal without fabricating past events")
	var bounded:=ReportJournal.new();bounded.initialized=true
	for i: int in ReportJournal.LIMIT+12: bounded.add("source","home","known:carb_sheltered",0,0,"flower_nectar",1)
	test.check(bounded.entries.size()==ReportJournal.LIMIT and bounded.omitted==12,"Bounded history discloses omitted older records")
	var status: Dictionary={"guest":{"observation":"foreign","rejection_active":true},"food_sharing":{"recent":true},"brood":[{"care":1.0,"nutrition":0.5,"nutrition_shortfalls":["protein"]}]}
	var needs: Array[Dictionary]=Pressure.needs(status)
	test.check(needs.size()==3 and needs[0].organ=="food_exchange" and needs[1].organ=="nursery" and needs[2].organ=="guest","Simultaneous intake/nutrition/clearing needs remain available; ongoing clearing does not obscure untreated strain")
	var cue:=ActivationFeedback.new();cue.begin();cue.outcome({"accepted":false})
	test.check(cue.status=="rejected","Control feedback acknowledges rejection without implying dispatch")
	cue.begin();cue.outcome({"accepted":true,"queued":true})
	test.check(cue.status=="queued","An accepted waiting order retains a distinct queued cue")
	var before_inspect: Dictionary=core(game)
	test.check(root.inspect_report(int(source.id)).accepted and core(game)==before_inspect and root.mode=="outward","Inspecting a retained source report navigates free attention and changes only read metadata")
	_check_controls(test,root)
	_check_defense(test)
	var extended: SimulationController=Rival.new().fixture();extended.advance(120)
	test.check(twin.restore_snapshot(snapshot(extended)) and twin.run.to_dict()==extended.run.to_dict(),"Long-run grouped decimal reports and rival scent preserve exact JSON continuation")
	extended.advance(10);twin.advance(10)
	test.check(twin.run.to_dict()==extended.run.to_dict(),"Restored grouped totals continue canonically across later real intake")
	root.free();return true

func _check_controls(test: Object, root: Node) -> void:
	var view:=Reports.new();test.get_root().add_child(view)
	view.provider=root.report_snapshot;view.read_command=root.mark_reports_read;view.pause_command=root.simulation.toggle_pause
	view.inspect_command=root.inspect_report;view.need_command=root.inspect_need;view._process(0)
	for pointer: String in ["mouse","touch"]:
		var before: Dictionary=core(root.simulation)
		view.opened=false
		if pointer=="mouse":
			var event:=InputEventMouseButton.new();event.pressed=true;event.button_index=MOUSE_BUTTON_LEFT;event.position=view.button_rect().get_center();view._input(event)
		else:
			var event:=InputEventScreenTouch.new();event.pressed=true;event.position=view.button_rect().get_center();view._input(event)
		test.check(view.opened and core(root.simulation)==before,"Opening reports is free attention for "+pointer)
		var paused: bool=root.simulation.run.clock.paused
		view.activate_at(view.command_rect("pause").get_center())
		test.check(root.simulation.run.clock.paused!=paused,"Reports preserves deliberate pause control")
		view.activate_at(view.command_rect("pause").get_center())
		view.activate_at(view.command_rect("needs").get_center())
		view.activate_at(view.command_rect("read").get_center())
		test.check(view.feedback=="Inspect a need to act","Reading report history cannot dismiss a current need as solved")
		view.activate_at(view.command_rect("history").get_center());view.activate_at(view.command_rect("close").get_center())
		test.check(not view.opened and core(root.simulation)==before,"Report navigation/close does not issue a colony order")
	var original: Vector2i=test.get_root().size
	var scale: Vector2i=test.get_root().content_scale_size
	test.get_root().content_scale_size=Vector2i.ZERO
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		test.get_root().size=size
		var panel: Rect2=view.panel_rect()
		test.check(panel.position.y>=142 and panel.end.y<=size.y-112,"Report modal fits between global and time controls at "+str(size))
		for command: String in ["history","needs","pause","previous","next","read","close"]:
			var box: Rect2=view.command_rect(command)
			test.check(panel.encloses(box) and box.size.x>=44 and box.size.y>=44,"Report targets are enclosed/touch-sized")
	test.get_root().size=original;test.get_root().content_scale_size=scale
	view.free()

func _check_defense(test: Object) -> void:
	var game: SimulationController=Defense.new().ready_game()
	var old: int=0
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="defense": old+=1
	assert(game.journey_response.defend("route_1"))
	var saw_private: bool=false
	for i: int in 900:
		game.advance(0.25)
		if not game.run.journey_response.active(): break
		if game.run.journey_response.defense.lost>0:
			saw_private=true;var visible: int=0
			for entry: Dictionary in game.run.reports.entries:
				if entry.kind=="defense": visible+=1
			test.check(visible==old,"Private combat loss/end state cannot become a journal result before return")
	var ending: Dictionary={}
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="defense": ending=entry
	test.check(not ending.is_empty() and ending.amount==game.run.journey_response.defense.outcomes.route_1.lost,"Actual defensive return creates its honest dated result")
