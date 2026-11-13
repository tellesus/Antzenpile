extends RefCounted
const Maternal=preload("res://tests/test_maternal_lineage.gd")
const Connections=preload("res://tests/test_connection_transport.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func fixture(stage: String="egg") -> SimulationController:
	var game: SimulationController=Maternal.new().mature_daughter()
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,1000)
	assert(game.start_reproduction("satellite_1"))
	for tick: int in 6000:
		if game.run.colony.piles.satellite_1.reproduction.phase==stage:break
		game.advance(0.25)
	assert(game.run.colony.piles.satellite_1.reproduction.phase==stage);return game
func copy_of(game: SimulationController, test: Object) -> SimulationController:
	var copy:=Controller.new();test.check(copy.restore_snapshot(Connections.new().snapshot(game)),"Reproductive custody restores atomically");return copy
func run(test: Object) -> bool:
	_stages(test);_recall(test);_succession(test);_founding(test);_space_and_inheritance(test);_rejection(test);_saves(test);_controls(test);return true
func _stages(test: Object) -> void:
	for stage: String in ["egg","larva","pupa","ready"]:
		var game: SimulationController=fixture(stage);var link: ConnectionTrafficState=game.run.all_connections()[0];var source: PileState=game.run.colony.piles.satellite_1;var target: PileState=game.run.colony.piles.home
		var group: Dictionary=source.reproduction.to_dict();var identity: String=source.reproduction.identity(source.id);var total: int=game.run.colony.workers_total;var available: int=source.workers_available
		var leg: int=WorkerReinforcementState.TRAILS.leg_ticks(source.position.distance_to(target.position));var system:=RoyalRescueSystem.new(game.run,source.id,link.route_id);var costs: Dictionary=system._provisions()
		test.check((costs.protein>0)==(stage=="larva"),"Only handled reproductive larvae pay actual feeding provisions")
		test.check(game.connection_order(link.route_id,source.id,"rescue_royals",8).accepted and source.reproduction.phase=="none" and source.royal_reserved and target.royal_reserved,"A paid "+stage+" group physically departs with exclusive receiving/return slots")
		var transport: RoyalTransportState=link.royals[source.id]
		test.check(transport.body.phase==stage and transport.body.origin_pile==source.id and transport.body.inherited_traits==group.inherited_traits and transport.movement.assigned()==9,"Transport owns the original stage/lineage plus real carriers/nurses/messenger")
		test.check(source.workers.count("reproduction:"+source.id)==-1 and source.workers_available==available-9+(4 if stage!="ready" else 0),"Source reproductive nurses release only at real departure")
		var before: Dictionary=game.run.to_dict()
		test.check(not game.start_reproduction(source.id) and not game.start_reproduction(target.id) and not game.connection_order(link.route_id,"home","supply").accepted and before==game.run.to_dict(),"Promised group slots and the shared connection cannot double-fund stock or nurses")
		var copy: SimulationController=copy_of(game,test);game.advance((leg-1)*0.25);copy.advance((leg-1)*0.25)
		test.check(game.run.to_dict()==copy.run.to_dict() and target.reproduction.phase=="none" and transport.body.progress_quarters==group.progress_quarters,"Handling pauses original reproductive progress without early landing")
		game.advance(0.25);copy.advance(0.25)
		test.check(game.run.to_dict()==copy.run.to_dict() and target.reproduction.identity(target.id)==identity and target.reproduction.phase==stage and transport.body.is_empty() and game.run.colony.workers_total==total,"Arrival transfers one actual group and eight settling staff without changing identity or population")
		test.check(target.workers.count("reproduction:"+target.id)==(4 if stage!="ready" else -1) and not target.royal_reserved and source.royal_reserved,"Receiving nurses are actual settled workers; source return promise awaits report")
		test.check(game.connection_summaries(source.id)[0].royals.deliveries==0 and game.run.unreported_transfers(source.id)==8,"One real messenger withholds arrival and known source headcount changes")
		copy=copy_of(game,test);game.advance(leg*0.25);copy.advance(leg*0.25)
		test.check(game.run.to_dict()==copy.run.to_dict() and not source.royal_reserved and transport.movement.reported_arrivals()==1 and game.run.reports.project(source.id).any(func(entry: Dictionary)->bool:return entry.kind=="royal_rescue" and entry.detail=="delivered"),"Messenger return alone clears the source promise and reports reproductive delivery")
func _recall(test: Object) -> void:
	var game: SimulationController=fixture("larva");var link: ConnectionTrafficState=game.run.all_connections()[0];var source: PileState=game.run.colony.piles.satellite_1;var identity: String=source.reproduction.identity(source.id)
	assert(game.connection_order(link.route_id,source.id,"rescue_royals",8).accepted);game.advance(1.25)
	test.check(game.connection_order(link.route_id,source.id,"recall_royals").accepted and source.reproduction.phase=="none","Recalled immature reproductives remain physically away")
	var copy: SimulationController=copy_of(game,test);game.advance(1.25);copy.advance(1.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and source.reproduction.identity(source.id)==identity and source.reproduction.phase=="larva" and source.workers.count("reproduction:"+source.id)==4,"Actual recall returns the original larva group and reassigns real source nurses once")
	test.check(not source.royal_reserved and link.royals[source.id].movement.last_settled==0,"Returned group has no migration or lingering promise")
	assert(game.connection_order(link.route_id,source.id,"rescue_royals",8).accepted);assert(game.connection_order(link.route_id,source.id,"recall_royals").accepted)
	test.check(copy_of(game,test).run.to_dict()==game.run.to_dict() and source.reproduction.transport_count==2,"Immediate second recall preserves original identity and custody ordinal")
func _succession(test: Object) -> void:
	var game: SimulationController=fixture("ready");var link: ConnectionTrafficState=game.run.all_connections()[0];var group: Dictionary=game.run.colony.piles.satellite_1.reproduction.to_dict();var identity: String=ReproductionState.body_identity(group,"satellite_1")
	game.run.colony.piles.home.queen_count=0
	assert(game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted);game.advance(100)
	test.check(game.replace_queen("home"),"A physically rescued ready queen/males can fund local successor establishment")
	var copy: SimulationController=copy_of(game,test);game.advance(QueenState.CONFIG.replacement_ticks*0.25);copy.advance(QueenState.CONFIG.replacement_ticks*0.25)
	var mother: QueenState=game.run.colony.piles.home.queen
	test.check(game.run.to_dict()==copy.run.to_dict() and mother.count==1 and mother.queen_id("home")==identity and mother.parent_identity==group.parent_queen_id and mother.generation==group.parent_generation+1,"Rescued successor keeps original birth identity and maternal generation")
	test.check(copy_of(game,test).run.to_dict()==game.run.to_dict(),"Consumed transported young queen becomes one valid laying body after save")
	# Further onward custody uses a different real connection and original identity.
	game=Connections.new().fixture();assert(game.start_reproduction("satellite_1"));game.advance(800)
	link=game.run.all_connections()[1];identity=game.run.colony.piles.satellite_1.reproduction.identity("satellite_1")
	assert(game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted);game.advance(100)
	test.check(game.run.colony.piles.satellite_2.reproduction.identity("satellite_2")==identity and copy_of(game,test).run.to_dict()==game.run.to_dict(),"A ready group reaches an immature third pile without fabricating local births or a new queen ID")
	assert(game.connection_order(link.route_id,"satellite_2","rescue_royals",8).accepted);game.advance(100)
	test.check(game.run.colony.piles.satellite_1.reproduction.identity("satellite_1")==identity and game.run.colony.piles.satellite_1.reproduction.transport_count==2 and copy_of(game,test).run.to_dict()==game.run.to_dict(),"Reverse reproductive rescue proves the same original young body across two custody changes")
func _founding(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_additional_piles.gd").new().fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var group: Dictionary=game.run.colony.piles.satellite_1.reproduction.to_dict()
	assert(game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted);game.advance(100)
	test.check(game.start_founding("known:nest_site_02","home"),"An actually rescued ready group can pay for a new nest from its receiver")
	var copy: SimulationController=copy_of(game,test);game.advance(200);copy.advance(200)
	test.check(game.run.to_dict()==copy.run.to_dict() and game.establish_daughter("known:nest_site_02","home"),"Rescued reproductive founding still requires actual preparation and returned report")
	var child: PileState=game.run.colony.piles.satellite_2
	test.check(child.queen.queen_id(child.id)==ReproductionState.body_identity(group,"satellite_1") and child.queen.generation==group.parent_generation+1 and copy_of(game,test).run.to_dict()==game.run.to_dict(),"A founded daughter owns the original rescued queen identity, not a renamed or duplicated mother")
func _space_and_inheritance(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var target: PileState=game.run.colony.piles.home
	assert(game.start_brood(target.id));assert(game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted)
	var before: Dictionary=game.run.to_dict()
	test.check(target.free_worker_brood_space()==0 and not game.start_brood(target.id) and before==game.run.to_dict(),"Receiving active reproductives reserve actual shared Nursery room alongside worker brood")
	var copy: SimulationController=copy_of(game,test);game.advance(850);copy.advance(850)
	test.check(game.run.to_dict()==copy.run.to_dict() and target.reproduction.phase=="ready" and target.reproduction.origin_pile=="satellite_1","Rescued immature reproductives resume actual local feeding and mature under their original ancestry")
	# Maternal bundle travels without changing the recipient's queen/adult genes.
	game=Maternal.new().mature_daughter();var source: PileState=game.run.colony.piles.satellite_1
	assert(game.start_adaptation(source.id,"lean"));game.advance(360);assert(game.start_reproduction(source.id));game.advance(800)
	link=game.run.all_connections()[0];target=game.run.colony.piles.home
	assert(game.connection_order(link.route_id,source.id,"rescue_royals",8).accepted);game.advance(100)
	test.check("lean" in target.reproduction.inherited_traits and target.queen.inherited_traits.is_empty() and copy_of(game,test).run.to_dict()==game.run.to_dict(),"Rescued inheritance remains a funded young group's bundle beside an unrelated recipient mother")
func _rejection(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var before: Dictionary=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,"satellite_1","rescue_royals",7).accepted and before==game.run.to_dict(),"Insufficient carrier/nurse burden rejects atomically")
	game.run.colony.piles.satellite_1.resources.water=0;game.run.colony.piles.satellite_1.reproduction.phase="larva";before=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted and before==game.run.to_dict(),"Handled larvae cannot borrow unpaid water or commit a free group")
	game=fixture();var home: PileState=game.run.colony.piles.home
	assert(game.start_reproduction(home.id));before=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted and before==game.run.to_dict(),"Actual receiving reproductive occupants block rescue")
func _saves(test: Object) -> void:
	var game: SimulationController=fixture("pupa");var link: ConnectionTrafficState=game.run.all_connections()[0];assert(game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted);game.advance(1)
	var saved: Dictionary=Connections.new().snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();assert(copy.restore_snapshot(saved));copy.set_time_scale(scale);copy.advance(80.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Reproductive rescue has equal fixed-step continuation at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(100);test.check(before==game.run.to_dict(),"Pause does not age or report handled reproductives")
	for mode: String in ["clone","parent","body","ordinal","promise","missing","receiver"]:
		var bad: Dictionary=saved.duplicate(true);var transport: Dictionary=bad.connection_traffic[link.route_id].royals.satellite_1
		match mode:
			"clone":bad.colony.piles[1].reproduction=transport.body.duplicate(true)
			"parent":transport.body.parent_queen_id="queen:invented:founder";transport.manifests[0].body.parent_queen_id="queen:invented:founder"
			"body":transport.body.inherited_traits=["load"]
			"ordinal":transport.body.transport_count=2;transport.manifests[0].body.transport_count=2
			"promise":bad.colony.piles[0].royal_reserved_space=0
			"missing":bad.connection_traffic[link.route_id].erase("royals")
			"receiver":bad.connection_traffic[link.route_id].royals.home=transport
		var copy:=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and copy.run.to_dict()==before,"Forged reproductive "+mode+" rejects atomically")
	game=fixture();saved=Connections.new().snapshot(game)
	for record: Dictionary in saved.connection_traffic.values():record.erase("royals")
	for pile: Dictionary in saved.colony.piles:
		for key: String in ["royal_reserved","royal_reserved_space","royal_reserved_traits"]:pile.erase(key)
		pile.reproduction.erase("origin_pile");pile.reproduction.erase("transport_count")
	var copy:=Controller.new();test.check(copy.restore_snapshot(saved) and copy.run.colony.piles.satellite_1.reproduction.identity("satellite_1")==game.run.colony.piles.satellite_1.reproduction.identity("satellite_1"),"Old native reproductive groups retain their original local identity without invented journeys")
func _controls(test: Object) -> void:
	var root:=Root.new();root.simulation=fixture();root.inward_pile_id="satellite_1";var view:=InwardView.new();test.get_root().add_child(view);root._inward_view=view;view.status_provider=root.focused_inward_status;view.connection_command=root.connection_order;view.selected_id="entrance";view._process(0)
	var size: Vector2=view.get_viewport_rect().size;var before: Dictionary=root.simulation.run.to_dict()
	view.activate_at(view.connection_controls.button(size).get_center());view.activate_at(view.connection_controls.rect(size,"royals").get_center());view._process(0)
	test.check(view.connection_controls.purpose=="royals" and before==root.simulation.run.to_dict(),"Young queen rescue selection is free and separate from laying/queen relocation")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.connection_controls.rect(size,"order").get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.connection_for(view.connection_controls.selected).royals.satellite_1.active(),"Touch ORDER physically funds the selected paid reproductive body")
	view.activate_at(view.connection_controls.rect(size,"stop").get_center());view._process(0)
	test.check(not root.simulation.run.connection_for(view.connection_controls.selected).busy(),"Shared return control restores a zero-distance young-queen party once")
	view.free();root.free()
