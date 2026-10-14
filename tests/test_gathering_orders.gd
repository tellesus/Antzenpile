extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const View=preload("res://src/presentation/outward/outward_view.gd")
const Predator=preload("res://tests/test_predator.gd")
func snapshot(game: SimulationController) -> Dictionary: return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func ready() -> SimulationController:
	var game:=Controller.new(482817);game.dispatch_scout("home",PI)
	for i: int in 600:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:carb_sheltered"): break
	return game
func run(test: Object) -> bool:
	var baseline: Dictionary=snapshot(ready())
	for count: int in [1,7,13]:
		var game:=Controller.new();game.restore_snapshot(baseline)
		test.check(game.create_trail("home","known:carb_sheltered",count),"Initial gathering accepts selected %d workers instead of requiring five" % count)
		var route: TrailRouteState=game.run.trails.find_route("home","known:carb_sheltered")
		test.check(route.allocated_workers==count and route.desired_workers==count and route.waiting_workers==0,"Paid labor exactly matches the selected target")
	var game:=Controller.new();game.restore_snapshot(baseline)
	var pile: PileState=game.run.colony.piles.home
	assert(pile.workers.create_commitment("test:busy","internal","home"));assert(pile.allocate_workers("test:busy",pile.workers_assignable-2))
	test.check(game.create_trail("home","known:carb_sheltered",7),"An explicit gathering target can wait for protected local labor")
	var route: TrailRouteState=game.run.trails.find_route("home","known:carb_sheltered")
	test.check(route.allocated_workers==2 and route.waiting_workers==5 and pile.workers_available>=pile.brood_care_workers_required(),"Only two free workers commit; the unsent five and carers remain distinct")
	var twin:=Controller.new()
	test.check(twin.restore_snapshot(snapshot(game)) and twin.run.to_dict()==game.run.to_dict(),"Partially funded gathering restores its unsent intent and real ledger")
	assert(pile.workers.release("test:busy",5));assert(twin.run.colony.piles.home.workers.release("test:busy",5))
	game.advance(0.25);twin.advance(0.25)
	test.check(route.allocated_workers==7 and route.waiting_workers==0 and game.run.to_dict()==twin.run.to_dict(),"New free workers fund only the explicitly queued remainder deterministically")
	var saved: Dictionary=snapshot(game)
	for invalid: Variant in [-1,1.5,8,"5"]:
		var broken: Dictionary=saved.duplicate(true);broken.trails.routes[0].waiting_workers=invalid
		var frozen: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==frozen,"Invalid unsent count rejects atomically")
	var legacy: Dictionary=saved.duplicate(true);legacy.trails.routes[0].erase("waiting_workers")
	test.check(twin.restore_snapshot(legacy) and twin.run.trails.routes[route.id].waiting_workers==0,"Legacy fully funded routes acquire no invented waiting ants")
	game=Controller.new();game.restore_snapshot(baseline);pile=game.run.colony.piles.home
	assert(pile.workers.create_commitment("test:busy","internal","home"));assert(pile.allocate_workers("test:busy",pile.workers_assignable))
	test.check(game.create_trail("home","known:carb_sheltered",3),"A zero-free-worker order remains queued without a fake commitment")
	route=game.run.trails.find_route("home","known:carb_sheltered")
	test.check(route.allocated_workers==0 and route.waiting_workers==3 and pile.workers.count("trail:"+route.id)==-1 and twin.restore_snapshot(snapshot(game)),"Unfunded intent owns no duplicate living ants or orphan pool")
	test.check(game.set_trail_workers(route.id,0) and route.waiting_workers==0,"Cancel clears unsent gathering before labor becomes available")
	assert(pile.workers.release("test:busy",3));game.advance(1)
	test.check(route.allocated_workers==0 and route.waiting_workers==0,"Canceled gathering cannot launch later")
	_check_controls(test,baseline)
	_check_daughter_controls(test)
	game=Predator.new()._fixture();route=game.run.trails.find_route("home","known:aphid_01")
	Predator.new()._until_loss(game)
	for i: int in 200:
		game.advance(0.25)
		if route.reported_losses>0: break
	var assigned: int=route.allocated_workers
	game.advance(5)
	test.check(route.waiting_workers==0 and route.allocated_workers<=assigned,"Reported/ongoing losses never trigger automatic replacement from an already paid target")
	return true

func _check_controls(test: Object, baseline: Dictionary) -> void:
	var game:=Controller.new();game.restore_snapshot(baseline)
	var root:=Root.new();root.simulation=game
	var view:=View.new();test.get_root().add_child(view)
	view.signal_provider=root.sensory_snapshot.bind("home");view.status_provider=root.outward_status.bind("home");view.gather_order_command=root.order_gathering
	view.selected_id="signal:known:carb_sheltered";view._process(0)
	for pointer: String in ["mouse","touch"]:
		view.gathering_draft.opened=false
		var frozen: Dictionary=game.run.to_dict()
		view._pointer_press(view._trail_button_rect("trail_create").get_center(),pointer)
		test.check(view.gathering_draft.opened and game.run.to_dict()==frozen,"Opening the gathering count draft spends nothing for "+pointer)
		view._pointer_press(view.gathering_draft.rect(view.get_viewport_rect().size,"gather_more").get_center(),pointer)
		test.check(view.gathering_draft.amount==6 and game.run.to_dict()==frozen,"Single-worker draft editing does not dispatch")
		view._pointer_press(view.gathering_draft.rect(view.get_viewport_rect().size,"gather_back").get_center(),pointer)
	view._run_command("trail_create");view.gathering_draft.amount=1
	view._pointer_press(view.gathering_draft.rect(view.get_viewport_rect().size,"gather_commit").get_center(),"touch")
	test.check(game.run.trails.find_route("home","known:carb_sheltered").allocated_workers==1 and not view.gathering_draft.opened,"Explicit ORDER sends the chosen one-worker commitment")
	for size: Vector2 in [Vector2(1280,720),Vector2(900,600)]:
		var box: Rect2=view.gathering_draft.panel(size)
		test.check(box.end.y<=size.y-112,"Gathering draft fits above time controls")
		for command: String in ["gather_less","gather_more","gather_suggest","gather_less_many","gather_more_many","gather_commit","gather_back"]:
			var target: Rect2=view.gathering_draft.rect(size,command)
			test.check(box.encloses(target) and target.size.x>=44 and target.size.y>=44,"Every gathering draft control remains enclosed and touch-sized")
	view.free();root.free()

func _check_daughter_controls(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_daughter_gathering.gd").new().fixture()
	var root:=Root.new();root.simulation=game;root.inward_pile_id="satellite_1"
	var view:=InwardView.new();test.get_root().add_child(view)
	view._status=root.focused_inward_status();view.gathering_command=root.daughter_gathering_command;view.selected_id="food_exchange"
	view.gathering.opened=true;view.gathering.selected="known:carb_exposed"
	var size: Vector2=view.get_viewport_rect().size
	var frozen: Dictionary=game.run.to_dict()
	view.activate_at(view.gathering.rect(size,"order").get_center())
	test.check(view.gathering.draft.opened and game.run.to_dict()==frozen,"Daughter gathering opens the same free staffing draft")
	view.gathering.draft.amount=3
	view.activate_at(view.gathering.draft.rect(size,"gather_commit").get_center())
	var route: TrailRouteState=game.run.trails.find_route("satellite_1","known:carb_exposed")
	test.check(route!=null and route.allocated_workers==3 and not view.gathering.draft.opened and game.run.colony.piles.home.workers.to_dict()==frozen.colony.piles[0].workers,"Daughter ORDER pays exactly three local ants and cannot draw from Home")
	view.free();root.free()
