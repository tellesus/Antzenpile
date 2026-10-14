extends RefCounted
const Fixture=preload("res://tests/test_reproduction.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func snapshot(game: SimulationController) -> Dictionary: return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func run(test: Object) -> bool:
	var game: SimulationController=Fixture.new().fixture();var pile: PileState=game.run.colony.piles.home
	var stores: Dictionary=pile.resources.duplicate();var ledger: Dictionary=pile.workers.to_dict()
	test.check(game.order_chamber("home","reproductive_alcove") and pile.resources==stores and pile.workers.to_dict()==ledger and pile.chambers.reproductive_spaces()==0,"Alcove queues without payment or premature capacity")
	game.advance(0.25);var project: ChamberProject=pile.chambers.projects.reproductive_alcove
	test.check(project.phase=="developing" and pile.workers.count("organ:home:reproductive_alcove")==4 and pile.resources.carbohydrate==stores.carbohydrate-24 and pile.resources.protein==stores.protein-12,"Funding pays once and uses four real construction workers")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)) and twin.run.to_dict()==game.run.to_dict(),"First funded construction tick restores exactly")
	game.advance(89.5);twin.advance(89.5)
	test.check(project.phase=="developing" and pile.chambers.reproductive_spaces()==0 and game.run.to_dict()==twin.run.to_dict(),"Space stays unavailable throughout real construction time")
	game.advance(0.25);twin.advance(0.25)
	test.check(project.phase=="complete" and pile.chambers.reproductive_spaces()==8 and pile.workers.count("organ:home:reproductive_alcove")==-1 and game.run.to_dict()==twin.run.to_dict(),"Completion adds only eight reproductive spaces and releases builders once")
	var before: Dictionary=game.run.to_dict()
	test.check(not game.order_chamber("home","reproductive_alcove",true) and not game.order_chamber("home","reproductive_alcove") and game.run.to_dict()==before,"Completed organs cannot be canceled or purchased twice")
	game.start_brood("home");game.start_brood("home");game.queue_reproduction("home");game.set_brood_intent("home","grow");game.advance(0.25)
	test.check(pile.reproduction.phase=="egg" and pile.brood_cohorts.size()==2 and pile.nursery_occupied_space()==24 and pile.shared_nursery_occupied_space()==16 and pile.free_worker_brood_space()==0,"Alcove supports reproduction beside a full worker Nursery without gifting worker slots")
	test.check(pile.nursery_care_capacity()==16 and pile.workers.count("reproduction:home")==4 and twin.restore_snapshot(snapshot(game)),"Worker carers and dedicated reproductive nurses count once across the extra space")
	game.advance(30);twin.advance(30)
	test.check(game.run.to_dict()==twin.run.to_dict() and pile.brood_cohorts[0].care==1,"Concurrent paid groups feed and continue exactly after load")
	test.check(game.run.reports.entries.any(func(entry: Dictionary) -> bool: return entry.kind=="chamber" and entry.detail=="complete"),"Completed organ has a retained local report")
	game=Fixture.new().fixture();pile=game.run.colony.piles.home;game.order_chamber("home","reproductive_alcove");game.advance(1);stores=pile.resources.duplicate()
	test.check(game.order_chamber("home","reproductive_alcove",true) and pile.resources==stores and pile.workers.count("organ:home:reproductive_alcove")==-1 and pile.chambers.projects.is_empty(),"Canceling construction releases labor and never recreates consumed stores/capacity")
	game=Controller.new();pile=game.run.colony.piles.home;ledger=pile.workers.to_dict();stores=pile.resources.duplicate();game.order_chamber("home","reproductive_alcove");game.advance(0.25)
	test.check(pile.chambers.projects.reproductive_alcove.phase=="queued" and pile.resources==stores and pile.workers.to_dict()==ledger and game.chambers.summary("home")[0].wait.contains("Nursery"),"Early project explicitly waits for development without taking existing carers")
	test.check(game.order_chamber("home","reproductive_alcove",true) and pile.chambers.projects.is_empty(),"Unfunded construction cancellation spends nothing")
	game=Fixture.new().fixture();pile=game.run.colony.piles.home;game.start_brood("home")
	pile.workers.create_commitment("test:busy","internal","home");pile.allocate_workers("test:busy",pile.workers_assignable);game.order_chamber("home","reproductive_alcove");game.advance(0.25)
	test.check(pile.chambers.projects.reproductive_alcove.phase=="queued" and pile.workers_available==pile.brood_care_workers_required() and pile.brood_cohorts[0].care==1,"Construction cannot take workers held for current brood care")
	game=Fixture.new().fixture();game.order_chamber("home","reproductive_alcove");game.advance(1);var saved: Dictionary=snapshot(game)
	for field: String in ["count","owner","time","future","id","orphan"]:
		var broken: Dictionary=saved.duplicate(true);var record: Dictionary=broken.colony.piles[0];before=twin.run.to_dict()
		match field:
			"count": record.workers.commitments["organ:home:reproductive_alcove"].count=3;record.workers.available+=1
			"owner": record.workers.commitments["organ:home:reproductive_alcove"].owner_id="satellite_1"
			"time": record.chambers[0].progress_ticks=360;record.chambers[0].phase="complete"
			"future": record.chambers[0].funded_tick=int(broken.clock.ticks)+1
			"id": record.chambers[0].id="unknown"
			"orphan": record.chambers=[]
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==before,"Malformed organ "+field+" rejects atomically")
	var legacy: Dictionary=snapshot(Fixture.new().fixture());legacy.colony.piles[0].erase("chambers")
	test.check(twin.restore_snapshot(legacy) and twin.run.colony.piles.home.chambers.projects.is_empty(),"Legacy piles gain no invented organ or capacity")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		game=Fixture.new().fixture();game.order_chamber("home","reproductive_alcove");game.set_time_scale(scale);game.advance(90.0/scale);game.set_time_scale(1)
		if expected.is_empty(): expected=game.run.to_dict()
		test.check(game.run.to_dict()==expected and game.run.colony.piles.home.chambers.complete("reproductive_alcove"),"Paid construction completes identically at %dx" % scale)
	_check_daughter(test);_check_controls(test)
	return true
func _check_daughter(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_daughter_gathering.gd").new().fixture()
	var daughter: PileState=game.run.colony.piles.satellite_1
	for id: String in PileState.RESOURCE_IDS: daughter.deposit_resource(id,500)
	game.start_nursery_development("satellite_1");game.advance(90)
	var home: Dictionary=game.run.colony.piles.home.workers.to_dict()
	game.order_chamber("satellite_1","reproductive_alcove");game.advance(0.25)
	test.check(daughter.chambers.projects.reproductive_alcove.phase=="developing" and daughter.workers.count("organ:satellite_1:reproductive_alcove")==4 and game.run.colony.piles.home.workers.to_dict()==home,"Daughter project pays its own independent construction labor")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Daughter organ and Home/Daughter worker ownership restore")
func _check_controls(test: Object) -> void:
	var root:=Root.new();root.simulation=Fixture.new().fixture()
	var view:=InwardView.new();test.get_root().add_child(view);view.status_provider=root.focused_inward_status;view.chamber_command=root.order_chamber;view._process(0)
	var before: Dictionary=root.simulation.run.to_dict();view.activate_at(view.chamber_controls.button().get_center())
	test.check(view.chamber_controls.opened and root.simulation.run.to_dict()==before,"Inspecting chambers is free attention")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.chamber_controls.rect(view.get_viewport_rect().size,"order").get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.colony.piles.home.chambers.projects.reproductive_alcove.phase=="queued","Touch queues the named organ through its owner")
	var mouse:=InputEventMouseButton.new();mouse.pressed=true;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=touch.position;view._unhandled_input(mouse);view._process(0)
	test.check(root.simulation.run.colony.piles.home.chambers.projects.is_empty(),"Mouse cancellation clears only the queued project")
	for size: Vector2 in [Vector2(1280,720),Vector2(900,600)]:
		var box: Rect2=view.chamber_controls.panel(size)
		test.check(box.end.y<=size.y-112,"Chamber context fits above time controls")
		for action: String in ["row","order","back"]: test.check(box.encloses(view.chamber_controls.rect(size,action)),"Chamber "+action+" stays enclosed and touch-sized")
	view.free();root.free()
