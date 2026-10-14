extends RefCounted
const Root=preload("res://src/core/game_root.gd")
const Memory=preload("res://src/presentation/outward/source_memory.gd")
func run(test: Object) -> bool:
	var rows: Array[Dictionary]=[]
	for values: Array in [["a","AA",50,7,3,false],["b","B",10,0,9,true],["c","A",10,2,1,false]]:
		rows.append({"knowledge_id":values[0],"memory_label":values[1],"age":values[2],"delivered_total":values[3],"desired_workers":values[4],"workers":1,"waiting_workers":2,"danger":values[5]})
	for pair: Array in [["label","c"],["recent","b"],["intake","a"],["labor","b"],["risk","b"]]:
		var sorted: Array=rows.duplicate(true);Memory.sort_entries(sorted,pair[0])
		test.check(sorted[0].knowledge_id==pair[1],"Source sort uses approved "+pair[0]+" with stable ties")
	test.check(Memory.intake_label(rows[1]).contains("unproven") and Memory.staffing_label(rows[0]).contains("2 wait"),"Zero intake remains unproven and queued labor is separate")
	var game: SimulationController=preload("res://tests/test_gathering_orders.gd").new().ready()
	var root:=Root.new();root.simulation=game
	game.set_investigation_priority("known:carb_sheltered",true)
	var policy: Dictionary=root.exploration_summary()
	test.check(policy.wait=="off" and policy.priority_details[0].name.to_lower().contains("nectar") and not policy.priority_details[0].awaiting,"Off exploration retains named queued source intent without dispatch")
	game.scouting.set_effort(2)
	var pile: PileState=game.run.colony.piles.home
	pile.workers.create_commitment("test:busy","internal","home");pile.allocate_workers("test:busy",pile.workers_assignable)
	test.check(root.exploration_summary().wait==("care" if pile.workers_available>0 else "labor"),"Standing scouting explains protected care or unavailable local labor")
	pile.workers.release("test:busy",pile.workers.count("test:busy"));pile.workers.retire_commitment("test:busy")
	game.dispatch_scout("home",0.0)
	test.check(root.exploration_summary().manual_away==1,"Manual scouts remain distinct from the standing effort target")
	for index: int in 7: game.dispatch_scout("home",PI)
	test.check(root.exploration_summary().wait=="cap" and root.exploration_summary().shared_away==8,"Manual missions fill the known shared cap and explain delayed standing dispatch")
	var view:=OutwardView.new();test.get_root().add_child(view)
	view._signals=root.sensory_snapshot("home");view._status=root.outward_status("home");view.sources_open=true
	var frozen: Dictionary=game.run.to_dict()
	for pointer: String in ["mouse","touch"]:
		var previous: String=view.source_sort
		view._pointer_press(view._source_sort_rect().get_center(),pointer)
		test.check(view.source_sort==Memory.next_sort(previous) and game.run.to_dict()==frozen,"Source sorting is free attention with "+pointer)
	var remembered: Array=view._source_entries()
	game.run.world.nodes.carb_sheltered.quantity=0;game.run.world.nodes.carb_sheltered.active=false
	view._signals=root.sensory_snapshot("home");view._status=root.outward_status("home")
	test.check(view._source_entries()==remembered,"Hidden depletion cannot alter comparison data or rank")
	var original: Vector2i=test.get_root().size;var scale: Vector2i=test.get_root().content_scale_size
	test.get_root().content_scale_size=Vector2i.ZERO
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		test.get_root().size=size
		var home_box: Rect2=view._sources_panel_rect()
		test.check(home_box.end.y<=size.y-112 and home_box.encloses(view._source_sort_rect()) and home_box.encloses(view._source_page_rect()),"Home comparison controls fit above compact time controls")
		for index: int in view._source_rows(): test.check(home_box.encloses(view._source_row_rect(index)),"Responsive Home source rows stay enclosed")
		var browser:=DaughterGathering.new();var box: Rect2=browser.panel(size)
		test.check(box.end.y<=size.y-112,"Daughter comparison fits above compact time controls")
		for action: String in ["sort","page","order","stop","scout","back"]:
			var target: Rect2=browser.rect(size,action)
			test.check(box.encloses(target) and target.size.x>=44 and target.size.y>=44,"Daughter "+action+" is enclosed and touch-sized")
		for index: int in 2: test.check(box.encloses(browser.rect(size,"row",index)),"Comparison source card is enclosed")
	test.get_root().size=original;test.get_root().content_scale_size=scale
	view.free();root.free()
	return true
