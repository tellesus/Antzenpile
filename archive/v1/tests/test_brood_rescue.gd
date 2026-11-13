extends RefCounted
const Maternal=preload("res://tests/test_maternal_lineage.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func fixture() -> SimulationController:
	var game: SimulationController=Maternal.new().mature_daughter()
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,500)
	assert(game.start_brood("satellite_1"));return game
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func copy_of(game: SimulationController, test: Object, label: String) -> SimulationController:
	var copy:=Controller.new();test.check(copy.restore_snapshot(snapshot(game)),label);return copy
func run(test: Object) -> bool:
	_stages(test);_recall(test);_trial(test);_chain_and_partial(test);_old(test);_rejections(test);_saves(test);_controls(test)
	return true
func _stages(test: Object) -> void:
	for stage: String in ["egg","larva","pupa"]:
		var game: SimulationController=fixture();var source: PileState=game.run.colony.piles.satellite_1;var target: PileState=game.run.colony.piles.home
		var cohort: BroodCohort=source.brood_cohorts[0]
		for tick: int in 3000:
			if cohort.stage==stage:break
			game.advance(0.25)
		assert(cohort.stage==stage);assert(game.start_brood(target.id));var target_cohorts: int=target.brood_cohorts.size();var uid: String=cohort.uid(source.id);var parent: String=cohort.parent_queen_id;var progress: float=cohort.progress_seconds
		var route_id: String=game.run.founding.route_id;var workers: int=game.run.colony.workers_total;var original_workers: int=source.workers_total
		var system:=BroodRescueSystem.new(game.run,source.id,route_id,uid);var costs: Dictionary=system.summary(6).provisions;var protein: float=source.resources.protein
		test.check(game.connection_order(route_id,source.id,"rescue_brood",6,uid).accepted,"A funded "+stage+" cohort can enter supported physical rescue")
		var transport: BroodTransportState=game.run.connection_for(route_id).broods[source.id]
		test.check(source.brood_cohorts.is_empty() and target.brood_cohorts.size()==target_cohorts and transport.body.count==8 and source.brood_reserved_space==8 and target.brood_reserved_space==8,"Departure has one immature owner and real return/receiving space promises")
		test.check(is_equal_approx(source.resources.protein,protein-costs.protein) and (costs.protein>0)==(stage=="larva"),"Only actual feeding larvae pay captured whole-trip feeding provisions")
		var before: Dictionary=game.run.to_dict();test.check(not game.start_brood(target.id) and game.run.to_dict()==before,"Receiving promise prevents Auto/manual laying from spending the primitive Nursery space")
		var copy: SimulationController=copy_of(game,test,"A paid "+stage+" body and actual carriers restore")
		var leg: int=WorkerReinforcementState.TRAILS.leg_ticks(source.position.distance_to(target.position));game.advance((leg-1)*0.25);copy.advance((leg-1)*0.25)
		test.check(game.run.to_dict()==copy.run.to_dict() and transport.body.progress_seconds==progress and target.brood_cohorts.size()==target_cohorts,"Handling interrupts development without premature arrival or free stage progress")
		game.advance(0.25);copy.advance(0.25)
		var received: BroodCohort=target.brood_cohorts.filter(func(item: BroodCohort)->bool:return item.uid(target.id)==uid)[0]
		test.check(game.run.to_dict()==copy.run.to_dict() and received.uid(target.id)==uid and received.stage==stage and received.parent_queen_id==parent and target.brood_reserved_space==0 and source.brood_reserved_space==8,"Actual arrival keeps the original body, stage and mother while turning promised room into occupancy")
		test.check(game.run.colony.workers_total==workers and source.workers_total==original_workers-6 and transport.movement.assigned()==1,"Six actual carriers/carers settle and a real messenger remains with the source")
		var root:=Root.new();root.simulation=game
		test.check(root.inward_status(source.id).workers_total==original_workers and game.connection_summaries(source.id)[0].brood.deliveries==0,"Source headcount and delivery reports withhold private settlement until messenger return")
		root.free();copy=copy_of(game,test,"Received immature ownership and unreturned source promises restore")
		game.advance(leg*0.25);copy.advance(leg*0.25)
		test.check(game.run.to_dict()==copy.run.to_dict() and source.brood_reserved_space==0 and transport.movement.reported_arrivals()==1,"Returned report clears the source promise and publishes one real body delivery")
		game.advance(400);copy_of(game,test,"Rescued "+stage+" offspring/losses conserve birth accounting after local care")
func _recall(test: Object) -> void:
	var game: SimulationController=fixture();var source: PileState=game.run.colony.piles.satellite_1;var cohort: BroodCohort=source.brood_cohorts[0];var uid: String=cohort.uid(source.id)
	game.brood.lose_one(source.id);game.brood.lose_one(source.id);source.brood_health.losses+=2;source.brood_health.last_loss_tick=game.run.clock.tick_count;var losses: int=source.brood_lost_total
	var route_id: String=game.run.founding.route_id;var workers: int=source.workers_total
	test.check(game.connection_order(route_id,source.id,"rescue_brood",5,uid).accepted,"A partially lost paid cohort carries only its actual surviving brood")
	game.advance(1.75);test.check(game.connection_order(route_id,source.id,"recall_brood").accepted and source.brood_cohorts.is_empty(),"Recall does not teleport dependents or reuse their original cells")
	var copy: SimulationController=copy_of(game,test,"Recalled partial body and original losses restore")
	game.advance(1.75);copy.advance(1.75)
	var returned: BroodCohort=source.brood_cohorts[0]
	test.check(game.run.to_dict()==copy.run.to_dict() and returned.uid(source.id)==uid and returned.count==6 and returned.lost_count==2 and source.brood_lost_total==losses and source.workers_total==workers,"Physical return preserves survivors/past loss and releases the actual party without births")
	test.check(source.brood_transferred_out==6 and source.brood_transferred_in==6 and source.brood_reserved_space==0,"Returned custody balances outgoing/received dependents without refunding travel")
	test.check(game.connection_order(route_id,source.id,"rescue_brood",5,uid).accepted and game.connection_order(route_id,source.id,"recall_brood").accepted and source.brood_cohorts.size()==1,"Zero-distance body reversal restores exactly one original cohort")
	copy_of(game,test,"Repeated original-body receipts restore with an increasing transport ordinal")
func _trial(test: Object) -> void:
	var game: SimulationController=Maternal.new().mature_daughter();var source: PileState=game.run.colony.piles.satellite_1;var target: PileState=game.run.colony.piles.home
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,500)
	assert(game.start_adaptation(source.id,"lean"));var cohort: BroodCohort=source.trial_cohort();var uid: String=cohort.uid(source.id);var parent: String=cohort.parent_queen_id;var route_id: String=game.run.founding.route_id
	test.check(game.connection_order(route_id,source.id,"rescue_brood",6,uid).accepted and source.workers.count("adaptation:"+source.id)==-1 and source.brood_reserved_trial=="lean","Actual departure releases source trial nurses while retaining the paid trial/return promise")
	var copy: SimulationController=copy_of(game,test,"A locked paid trial can be physically carried")
	game.advance(100);copy.advance(100)
	test.check(game.run.to_dict()==copy.run.to_dict() and target.trial_cohort()!=null and target.workers.count("adaptation:"+target.id)==2 and source.brood_reserved_trial.is_empty(),"Received trial nurses are actual settled workers, never transferred or duplicated reservations")
	game.advance(400)
	test.check(target.genetics.count_trait("lean")>0 and target.offspring_traits().is_empty() and source.queen.queen_id(source.id)==parent,"Imported trial adults express their paid trait while an unrelated receiver mother keeps her own inheritance")
	copy_of(game,test,"Imported trial expression and original maternal identity restore after emergence")
	# Follow the physically relocated actual mother with her own already-funded trial.
	game=Maternal.new().mature_daughter();source=game.run.colony.piles.satellite_1;target=game.run.colony.piles.home
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,500)
	assert(game.start_adaptation(source.id,"lean"));uid=source.trial_cohort().uid(source.id);target.queen_count=0;route_id=game.run.founding.route_id
	assert(game.connection_order(route_id,source.id,"relocate_queen",2).accepted);game.advance(50)
	test.check(game.connection_order(route_id,source.id,"rescue_brood",6,uid).accepted,"The actual mother can be followed by her unchanged paid dependent trial")
	game.advance(500)
	test.check(target.offspring_traits()==["lean"] and target.queen.queen_id(target.id)==source.queen.queen_id(source.id),"Only supported emergence beside that same physical mother establishes her new inherited choice")
	copy_of(game,test,"A mother-and-dependent rescue chain preserves lineage and actual birth ownership")
func _rejections(test: Object) -> void:
	var game: SimulationController=fixture();var source: PileState=game.run.colony.piles.satellite_1;var target: PileState=game.run.colony.piles.home;var uid: String=source.brood_cohorts[0].uid(source.id);var route_id: String=game.run.founding.route_id
	var before: Dictionary=game.run.to_dict()
	test.check(not game.connection_order(route_id,source.id,"rescue_brood",5,uid).accepted and before==game.run.to_dict(),"Understaffed care/burden rejection is atomic")
	test.check(not game.connection_order(route_id,source.id,"rescue_brood",6,"missing").accepted and before==game.run.to_dict(),"Inspection cannot synthesize an unowned cohort")
	assert(game.start_brood(target.id));assert(game.start_brood(target.id));before=game.run.to_dict()
	test.check(not game.connection_order(route_id,source.id,"rescue_brood",6,uid).accepted and before==game.run.to_dict(),"Paid recipient brood cannot be discarded to make receiving room")
	game=fixture();source=game.run.colony.piles.satellite_1;uid=source.brood_cohorts[0].uid(source.id);game.advance(180);source.resources.protein=0;before=game.run.to_dict()
	test.check(not game.connection_order(game.run.founding.route_id,source.id,"rescue_brood",6,uid).accepted and before==game.run.to_dict(),"Underfunded actual larval feeding cannot withdraw a paid body or reserve a second job")
func _saves(test: Object) -> void:
	var game: SimulationController=fixture();var route_id: String=game.run.founding.route_id;var source: PileState=game.run.colony.piles.satellite_1
	game.connection_order(route_id,source.id,"rescue_brood",6,source.brood_cohorts[0].uid(source.id));var saved: Dictionary=snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();test.check(copy.restore_snapshot(saved),"Brood travel baseline restores")
		copy.set_time_scale(scale);copy.advance(20.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Supported handling/body/food/space is equal at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(60);test.check(game.run.to_dict()==before,"Pause cannot grow, clone, feed or report a travelling cohort")
	for mode: String in ["body","parent","counter","promise","duplicate","origin","food"]:
		var bad: Dictionary=saved.duplicate(true);var state: Dictionary=bad.connection_traffic[route_id].broods.satellite_1
		match mode:
			"body":state.body.clear()
			"parent":state.body.parent_queen_id="queen:fake"
			"counter":bad.colony.piles[1].brood_transferred_out+=1
			"promise":bad.colony.piles[0].brood_reserved_space=0
			"duplicate":bad.colony.piles[1].brood_cohorts.append(state.body.duplicate(true))
			"origin":state.body.origin_pile="satellite_99"
			"food":state.body.nutrition=2
		var copy:=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and before==copy.run.to_dict(),"Forged brood rescue "+mode+" rejects atomically")
func _controls(test: Object) -> void:
	var root:=Root.new();root.simulation=fixture();root.inspect_pile("satellite_1")
	var view:=InwardView.new();test.get_root().add_child(view);root._inward_view=view;view.status_provider=root.focused_inward_status;view.connection_command=root.connection_order;view.selected_id="entrance";view._process(0)
	var size: Vector2=view.get_viewport_rect().size;var before: Dictionary=root.simulation.run.to_dict()
	view.activate_at(view.connection_controls.button(size).get_center());var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.connection_controls.rect(size,"brood").get_center();view._unhandled_input(touch);view._process(0)
	test.check(view.connection_controls.purpose=="brood" and not view.connection_controls.cohort_uid.is_empty() and root.simulation.run.to_dict()==before,"Free shared touch/mouse selection chooses actual local paid brood")
	view.activate_at(view.connection_controls.rect(size,"order").get_center());view._process(0)
	test.check(root.simulation.run.connection_for(view.connection_controls.selected).broods.satellite_1.active(),"Explicit ORDER alone withdraws the original dependent body and funds carriers")
	view.activate_at(view.connection_controls.rect(size,"stop").get_center());view._process(0)
	test.check(root.simulation.run.colony.piles.satellite_1.brood_cohorts.size()==1,"The current-job return control recalls exactly one real dependent cohort")
	view.free();root.free()

func _chain_and_partial(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_additional_piles.gd").new().three_piles()
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,500)
	var source: PileState=game.run.colony.piles.satellite_1;var third: PileState=game.run.colony.piles.satellite_2;var link: ConnectionTrafficState=game.run.all_connections()[1]
	assert(game.start_brood(source.id));var uid: String=source.brood_cohorts[0].uid(source.id)
	game.brood.lose_one(source.id);game.brood.lose_one(source.id);source.brood_health.losses+=2;source.brood_health.last_loss_tick=game.run.clock.tick_count
	test.check(game.connection_order(link.route_id,source.id,"rescue_brood",5,uid).accepted,"Partially lost brood uses a real additional nest connection")
	game.advance(100)
	test.check(third.brood_cohorts.size()==1 and third.brood_cohorts[0].count==6 and third.brood_lost_total==0 and source.brood_lost_total==2,"Arrival retains inherited past losses without reporting them a second time at the new nursery")
	copy_of(game,test,"Partial body/loss ownership on a third-pile link restores")
	test.check(game.connection_order(link.route_id,third.id,"rescue_brood",5,uid).accepted,"The same original paid cohort can be physically returned over its adjacent edge")
	game.advance(100)
	test.check(source.brood_cohorts.size()==1 and source.brood_cohorts[0].uid(source.id)==uid and source.brood_cohorts[0].transport_count==2,"A staged second journey keeps original identity instead of laying a new batch")
	copy_of(game,test,"Two-direction original custody/worker/profile/receipt history reconciles")
	game.advance(400);copy_of(game,test,"Received partial births conserve local and global paid-batch accounting")
func _old(test: Object) -> void:
	var game: SimulationController=fixture();var saved: Dictionary=snapshot(game)
	for pile: Dictionary in saved.colony.piles:
		for key: String in ["brood_reserved_groups","brood_transferred_in","brood_transferred_out","brood_reserved_space","brood_reserved_trial","brood_reserved_traits","brood_lineages"]:pile.erase(key)
		for cohort: Dictionary in pile.brood_cohorts:
			for key: String in ["origin_pile","transport_count","inherited_lost"]:cohort.erase(key)
	for record: Dictionary in saved.connection_traffic.values():record.erase("broods")
	var copy:=Controller.new();test.check(copy.restore_snapshot(saved) and copy.run.to_dict()==game.run.to_dict(),"Old absent immature-transfer fields create no bodies, promises or trips")
	game.advance(16);copy.advance(16);test.check(copy.run.to_dict()==game.run.to_dict(),"Old local cohort identity and inherited growth continue exactly")
