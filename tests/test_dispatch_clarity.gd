extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Draft = preload("res://src/presentation/gathering_draft.gd")
const Fixture = preload("res://tests/test_gathering_orders.gd")
const Predator = preload("res://tests/test_predator.gd")

func run(test: Object) -> bool:
	for pointer: String in ["mouse","touch"]:
		var root := Root.new()
		root.simulation = Fixture.new().ready()
		var game: SimulationController = root.simulation
		var pile: PileState = game.run.colony.piles.home
		pile.workers.create_commitment("test:busy","internal","home")
		pile.allocate_workers("test:busy",pile.workers_assignable-2)
		var view := OutwardView.new()
		test.get_root().add_child(view)
		view.signal_provider = root.sensory_snapshot.bind("home")
		view.status_provider = root.outward_status.bind("home")
		view.gather_order_command = root.order_gathering
		view.selected_id = "signal:known:carb_sheltered"
		view._process(0)
		var frozen: Dictionary = game.run.to_dict()
		view._pointer_press(view._trail_button_rect("trail_create").get_center(),pointer)
		var draft: GatheringDraft = view.gathering_draft
		view._pointer_press(draft.rect(view.get_viewport_rect().size,"gather_more_many").get_center(),pointer)
		test.check(draft.amount==10 and game.run.to_dict()==frozen,"Planning/editing never commits or advances anything for "+pointer)
		draft.amount = 7
		test.check(draft.action_title(0,2)=="ORDER 7 GATHERERS" and draft.preview(0,2).waiting==5,"Partially funded proposal separates its target from the labor queue")
		view._pointer_press(draft.rect(view.get_viewport_rect().size,"gather_commit").get_center(),pointer)
		var route: TrailRouteState = game.run.trails.find_route("home","known:carb_sheltered")
		test.check(route.allocated_workers==2 and route.waiting_workers==5 and pile.workers_available>=pile.brood_care_workers_required(),"One explicit action assigns only free workers, queues five and protects care")
		test.check(not draft.opened and view._feedback.contains("2 assigned · 5 queued"),"Acknowledgment reports actual accepted commitments without claiming a harvest")
		view._process(0)
		view._run_command("gather_edit")
		frozen = game.run.to_dict()
		draft.amount = 500
		view._pointer_press(draft.rect(view.get_viewport_rect().size,"gather_commit").get_center(),pointer)
		test.check(draft.opened and game.run.to_dict()==frozen,"A rejected/stale proposal remains editable without partial funding")
		draft.amount = 1
		test.check(draft.action_title(2,0)=="SET TOTAL TO 1" and draft.preview(2,0).surplus==1,"Lowering an existing order is clearly a total, not one extra ant")
		view._pointer_press(draft.rect(view.get_viewport_rect().size,"gather_back").get_center(),pointer)
		test.check(not draft.opened and game.run.to_dict()==frozen,"Closing a proposal discards edits without recalling actual workers")
		view.free()
		root.free()
	var draft := Draft.new()
	draft.begin("known:test",0,40)
	test.check(draft.action_title(0,38)=="SEND 5 GATHERERS" and draft.action_title(0,0)=="QUEUE 5 GATHERERS","Primary action explains whether free workers can be assigned now")
	for size: Vector2 in [Vector2(1920,1080),Vector2(1280,720),Vector2(900,600)]:
		var boxes: Array[Rect2] = []
		for command: String in ["gather_less","gather_more","gather_suggest","gather_less_many","gather_more_many","gather_commit","gather_back"]:
			var box: Rect2 = draft.rect(size,command)
			test.check(draft.panel(size).encloses(box) and box.size.x>=44 and box.size.y>=44,"Controls fit the panel and preserve touch targets")
			for previous: Rect2 in boxes: test.check(not box.intersects(previous),"Visible actions do not overlap")
			boxes.append(box)
		test.check(draft.rect(size,"gather_commit").size.x==draft.panel(size).size.x-32,"There is one full-width primary commitment action")
	# An actual unreported casualty must remain unknown in the new receipt too.
	var root := Root.new()
	root.simulation = Predator.new()._fixture()
	Predator.new()._until_loss(root.simulation)
	var physical: TrailRouteState = root.simulation.run.trails.routes.route_1
	var before: Dictionary = root.simulation.run.to_dict()
	var receipt: Dictionary = root.order_gathering("known:aphid_01",5)
	test.check(receipt.accepted and receipt.assigned==5 and physical.allocated_workers==4,"Receipt retains the expected fifth traveler until a real report arrives")
	test.check(root.simulation.run.to_dict()==before,"Acknowledging the unchanged expected target cannot replace a private casualty or consume RNG")
	root.free()
	return true
