extends RefCounted
const Queen=preload("res://tests/test_queen_relocation.gd")
const Maternal=preload("res://tests/test_maternal_lineage.gd")
const Connections=preload("res://tests/test_connection_transport.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func fixture() -> SimulationController:
	var game: SimulationController=Queen.new().fixture()
	assert(game.set_sanitation_workers("home",0));assert(game.set_humidity_workers("home",0));return game
func copy_of(game: SimulationController, test: Object) -> SimulationController:
	var copy:=Controller.new();test.check(copy.restore_snapshot(Connections.new().snapshot(game)),"Final-departure ownership restores atomically");return copy
func run(test: Object) -> bool:
	_departure(test);_staged_rescue(test);_recall(test);_same_tick_destination(test);_empty(test);_rejection(test);_saves(test);_controls(test);return true
func _departure(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var source: PileState=game.run.colony.piles.home;var target: PileState=game.run.colony.piles.satellite_1
	var count: int=source.workers_total;var total: int=game.run.colony.workers_total;var leg: int=WorkerReinforcementState.TRAILS.leg_ticks(source.position.distance_to(target.position));var cost: float=FinalDepartureSystem.new(game.run,source.id,link.route_id)._cost(count);var stock: float=source.resources.carbohydrate
	var projected_left: Dictionary=FinalDepartureSystem.new(game.run,source.id,link.route_id).summary().left_stores
	test.check(game.connection_order(link.route_id,source.id,"final_departure").accepted and source.relinquished and source.workers_available==0 and source.workers.count("trail:"+link.route_id)==count,"Explicit final departure commits every actual remaining worker without a messenger")
	var state: EvacuationTransportState=link.evacuations[source.id];var left: Dictionary=state.current().left_stores.duplicate()
	test.check(left==projected_left,"Free final-departure review quotes exact stock left after the displayed travel charge")
	test.check(state.movement.messengers==0 and state.current().workers==count and absf(source.resources.carbohydrate-(stock-cost))<0.00001 and source.resources==left,"One-way travel pays once and explicitly records finite stores left behind")
	test.check(link.closed and not game.connection_order(link.route_id,target.id,"supply").accepted and not game.connection_order(link.route_id,source.id,"open").accepted,"Relinquished endpoints stop new incoming traffic and cannot be silently reopened")
	var root:=Root.new();root.simulation=game;var known: Dictionary=root.inward_status(source.id)
	var copy: SimulationController=copy_of(game,test);game.advance((leg-1)*0.25);copy.advance((leg-1)*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and source.workers_total==count,"All final travelers retain their actual source ledger before physical landing")
	game.advance(0.25);copy.advance(0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and source.workers_total==0 and target.workers_total==total and not link.busy(),"One-leg arrival transfers all workers, retires the empty source pool and conserves population")
	test.check(root.inward_status(source.id).workers_total==known.workers_total and root.inward_status(source.id).resources==known.resources and game.connection_summaries(source.id)[0].busy,"Vacant source projection freezes known sent count/stores and does not expose private settlement")
	test.check(game.run.reports.project(source.id).all(func(entry: Dictionary)->bool:return entry.kind!="evacuation") and game.run.reports.project(target.id).any(func(entry: Dictionary)->bool:return entry.kind=="evacuation" and entry.detail=="arrived" and entry.amount==count),"Only actual receiver witnesses confirm final arrival; no fictional source receipt appears")
	var before: Dictionary=game.run.to_dict();test.check(game.connection_order(link.route_id,source.id,"recall_departure").accepted and before==game.run.to_dict(),"A late conditional return request cannot reveal landing or undo settled workers")
	test.check(copy_of(game,test).run.to_dict()==game.run.to_dict() and game.start_brood(target.id),"Relinquished history saves and the real receiver continues local growth")
	root.free()
func _staged_rescue(test: Object) -> void:
	var game: SimulationController=Maternal.new().mature_daughter();var link: ConnectionTrafficState=game.run.all_connections()[0];var source: PileState=game.run.colony.piles.home;var target: PileState=game.run.colony.piles.satellite_1
	# A queenless refuge receives the actual original laying mother and her dependents.
	target.queen_count=0
	for pile: PileState in [source,target]:
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,1000)
	assert(game.start_brood(source.id));var mother: String=source.queen.queen_id(source.id);var brood_uid: String=source.brood_cohorts[0].uid(source.id)
	assert(game.connection_order(link.route_id,source.id,"relocate_queen",4).accepted);game.advance(20)
	assert(game.connection_order(link.route_id,source.id,"rescue_brood",6,brood_uid).accepted);game.advance(20)
	assert(game.connection_order(link.route_id,source.id,"rescue_stores",5,"water").accepted);game.advance(20)
	assert(game.set_sanitation_workers(source.id,0));assert(game.set_humidity_workers(source.id,0))
	test.check(source.queen.count==0 and source.brood_cohorts.is_empty() and target.queen.queen_id(target.id)==mother and game.connection_order(link.route_id,source.id,"final_departure").accepted,"Actual staged mother/brood/store rescue makes supported final departure available")
	var copy: SimulationController=copy_of(game,test);game.advance(100);copy.advance(100)
	test.check(game.run.to_dict()==copy.run.to_dict() and source.relinquished and source.workers_total==0 and target.queen.count==1 and target.brood_cohorts.any(func(cohort: BroodCohort)->bool:return cohort.uid(target.id)==brood_uid),"A whole rescued lineage survives while its original nest is actually relinquished")
func _recall(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var count: int=game.run.colony.piles.home.workers_total
	assert(game.connection_order(link.route_id,"home","final_departure").accepted);game.advance(1.25)
	test.check(game.connection_order(link.route_id,"home","recall_departure").accepted and game.run.colony.piles.home.relinquished,"A partial final-departure recall still waits for physical return")
	var copy: SimulationController=copy_of(game,test);game.advance(1.25);copy.advance(1.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and not game.run.colony.piles.home.relinquished and game.run.colony.piles.home.workers_available==count and link.closed,"Actual returning party reactivates its original nest; traffic stays deliberately closed")
	assert(game.connection_order(link.route_id,"home","open").accepted);assert(game.connection_order(link.route_id,"home","final_departure").accepted);assert(game.connection_order(link.route_id,"home","recall_departure").accepted)
	test.check(copy_of(game,test).run.to_dict()==game.run.to_dict() and link.evacuations.home.manifests.size()==2,"Immediate second recall returns the same workforce without a refund or duplicate")
	# Loss of recipient reproductive continuation returns actual workers rather than stranding them.
	assert(game.connection_order(link.route_id,"home","open").accepted);assert(game.connection_order(link.route_id,"home","final_departure").accepted)
	game.run.colony.piles.satellite_1.queen_count=0;game.advance(20)
	test.check(not game.run.colony.piles.home.relinquished and game.run.colony.piles.home.workers_available==count and link.evacuations.home.current().reason=="landing" and copy_of(game,test).run.to_dict()==game.run.to_dict(),"Unsuitable actual landing returns the one-way party and records local failed-return evidence")
func _same_tick_destination(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture();var source: PileState=game.run.colony.piles.satellite_1;source.queen_count=0
	assert(game.set_sanitation_workers(source.id,0));assert(game.set_humidity_workers(source.id,0))
	var first: ConnectionTrafficState=game.run.all_connections()[0];var second: ConnectionTrafficState=game.run.all_connections()[1]
	assert(game.connection_order(first.route_id,source.id,"final_departure").accepted);assert(game.connection_order(first.route_id,source.id,"recall_departure").accepted)
	assert(game.connection_order(second.route_id,source.id,"open").accepted);assert(game.connection_order(second.route_id,source.id,"final_departure").accepted)
	test.check(first.evacuations[source.id].current().departed_tick==second.evacuations[source.id].current().departed_tick and second.evacuations[source.id].current().sequence==2 and copy_of(game,test).run.to_dict()==game.run.to_dict(),"Same-tick destination changes preserve the latest actual final-departure order")
	var copy: SimulationController=copy_of(game,test);game.advance(100);copy.advance(100)
	test.check(game.run.to_dict()==copy.run.to_dict() and game.run.known_final_departure(source.id).destination_id==second.target(source.id),"Changed final destination settles once and retains its correct source knowledge")
func _empty(test: Object) -> void:
	var game: SimulationController=fixture();var source: PileState=game.run.colony.piles.home;var link: ConnectionTrafficState=game.run.all_connections()[0]
	assert(source.workers.remove_living_workers("available",source.workers_total,"Known local loss"))
	test.check(game.connection_order(link.route_id,source.id,"final_departure").accepted and source.relinquished and not link.busy() and link.evacuations.home.movement.trips_started==0,"An already empty nest can be relinquished without invented travelers or transport cost")
	test.check(copy_of(game,test).run.to_dict()==game.run.to_dict(),"Empty abandonment preserves actual mortality and leftover stock proofs")
func _rejection(test: Object) -> void:
	var game: SimulationController=Maternal.new().mature_daughter();var link: ConnectionTrafficState=game.run.all_connections()[0];var before: Dictionary=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,"home","final_departure").accepted and before==game.run.to_dict(),"A living mother cannot be discarded by final departure")
	game=fixture();assert(game.start_brood("satellite_1"));before=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,"satellite_1","final_departure").accepted and before==game.run.to_dict(),"A nest with paid dependent brood cannot silently abandon its bodies")
	game=fixture();game.run.colony.piles.satellite_1.queen_count=0;before=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,"home","final_departure").accepted and before==game.run.to_dict(),"A destination without actual reproductive continuation cannot fund a final departure")
	game=fixture();game.run.colony.piles.home.resources.carbohydrate=0;before=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,"home","final_departure").accepted and before==game.run.to_dict(),"Underfunded whole-workforce travel cannot relinquish a nest for free")
func _saves(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var old: Dictionary=Connections.new().snapshot(game)
	for record: Dictionary in old.connection_traffic.values():record.erase("evacuations")
	for pile: Dictionary in old.colony.piles:pile.erase("relinquished")
	var copy:=Controller.new();test.check(copy.restore_snapshot(old) and copy.run.to_dict()==game.run.to_dict(),"Old absence adds no final departure or relinquished nest")
	assert(game.connection_order(link.route_id,"home","final_departure").accepted);game.advance(1)
	var saved: Dictionary=Connections.new().snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		copy=Controller.new();assert(copy.restore_snapshot(saved));copy.set_time_scale(scale);copy.advance(20.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Final one-way travel continues equally at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(100);test.check(before==game.run.to_dict(),"Pause preserves paid one-way travelers and frozen departure knowledge")
	for mode: String in ["flag","messenger","count","profile","arrival","left","marker","duplicate","ordinary_messenger"]:
		var bad: Dictionary=saved.duplicate(true);var state: Dictionary=bad.connection_traffic[link.route_id].evacuations.home
		match mode:
			"flag":bad.colony.piles[0].relinquished=false
			"messenger":state.movement.messengers=1
			"count":state.manifests[0].workers+=1
			"profile":state.manifests[0].profiles={"invented":state.manifests[0].workers}
			"arrival":state.manifests[0].arrived_tick=state.manifests[0].departed_tick+1
			"left":state.manifests[0].left_stores.water=-1
			"marker":bad.connection_traffic[link.route_id].erase("evacuations")
			"duplicate":bad.connection_traffic[link.route_id].evacuations.satellite_1=state
			"ordinary_messenger":bad.reinforcement.messengers=0
		copy=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and before==copy.run.to_dict(),"Forged final departure "+mode+" rejects atomic restore")
func _controls(test: Object) -> void:
	var root:=Root.new();root.simulation=fixture();var view:=InwardView.new();test.get_root().add_child(view);root._inward_view=view;view.status_provider=root.focused_inward_status;view.connection_command=root.connection_order;view.selected_id="entrance";view._process(0)
	var size: Vector2=view.get_viewport_rect().size;var before: Dictionary=root.simulation.run.to_dict();view.activate_at(view.connection_controls.button(size).get_center());view.activate_at(view.connection_controls.rect(size,"departure").get_center());view._process(0)
	test.check(view.connection_controls.purpose=="departure" and before==root.simulation.run.to_dict(),"Reviewing final workers/cost/destination/stores left is a free distinct control")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.connection_controls.rect(size,"order").get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.colony.piles.home.relinquished and root.simulation.run.all_connections()[0].evacuations.home.active(),"Explicit touch FINAL DEPARTURE alone commits one-way evacuation")
	view.activate_at(view.connection_controls.rect(size,"stop").get_center());view._process(0)
	test.check(not root.simulation.run.colony.piles.home.relinquished,"Shared return request physically reactivates a zero-distance final party")
	view.free();root.free()
