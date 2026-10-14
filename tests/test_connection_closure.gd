extends RefCounted
const Connections=preload("res://tests/test_connection_transport.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func copy_of(game: SimulationController, test: Object) -> SimulationController:
	var copy:=Controller.new();test.check(copy.restore_snapshot(Connections.new().snapshot(game)),"Closed connection restores atomically");return copy
func run(test: Object) -> bool:
	_dispatches(test);_supplies(test);_paid_parties(test);_saves(test);_controls(test);return true
func _dispatches(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture();var first: ConnectionTrafficState=game.run.all_connections()[0];var other: ConnectionTrafficState=game.run.all_connections()[1]
	var total: int=game.run.colony.workers_total;var stock: Dictionary=game.run.colony.piles.home.resources.duplicate()
	test.check(game.connection_order(first.route_id,"home","close").accepted and first.closed and total==game.run.colony.workers_total and stock==game.run.colony.piles.home.resources,"Closing an idle link is explicit policy, with no instant death, travel or food cost")
	for source: String in [first.parent_id,first.child_id]:
		for action: String in ["supply","migrate","relocate_queen","rescue_brood","rescue_stores","rescue_royals"]:
			var before: Dictionary=game.run.to_dict();var result: Dictionary=game.connection_order(first.route_id,source,action,8,"water")
			test.check(not result.accepted and result.reason.contains("closed") and game.run.to_dict()==before,"Closed link rejects new "+action+" from either side atomically")
	test.check(game.connection_order(other.route_id,"satellite_1","supply").accepted,"Closing one connection leaves another independently paid link available")
	test.check(game.start_brood("home") and game.start_brood("satellite_1"),"Isolated nests retain actual local laying, food and care")
	var before: Dictionary=game.run.to_dict();test.check(not game.connection_order(first.route_id,"home","close").accepted and before==game.run.to_dict(),"Repeated closure changes no orders or policy dates")
	test.check(game.connection_order(first.route_id,"satellite_1","open").accepted and not first.closed and not first.busy(),"Either endpoint can explicitly reopen without restoring old traffic intent")
	test.check(copy_of(game,test).run.to_dict()==game.run.to_dict(),"Independent local work and reopened network policy save exactly")
func _supplies(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var source: PileState=game.run.colony.piles.home
	source.resources.water=0;var available: int=source.workers_available
	assert(game.connection_order(link.route_id,"home","supply").accepted)
	test.check(game.connection_order(link.route_id,"satellite_1","close").accepted and source.workers_available==available and game.run.supply.phase=="none" and not game.run.supply.enabled,"Closing releases unfunded waiting supply labor from its actual payer")
	test.check(copy_of(game,test).run.to_dict()==game.run.to_dict(),"Closed waiting intent has no orphan pool after load")
	game=Connections.new().fixture();link=game.run.all_connections()[0];source=game.run.colony.piles.home;available=source.workers_available
	var destination: PileState=game.run.colony.piles.satellite_1;var leg: int=InterpileSupplyState.TRAILS.leg_ticks(source.position.distance_to(destination.position));var water: float=destination.resources.water
	assert(game.connection_order(link.route_id,"home","supply").accepted);game.advance(0.25)
	assert(game.connection_order(link.route_id,"satellite_1","close").accepted)
	test.check(game.run.supply.phase=="outbound" and not game.run.supply.enabled and source.workers_available==available-8,"Closing a paid pack keeps real cargo/carriers away and only stops repeat intent")
	var copy: SimulationController=copy_of(game,test);game.advance(leg*0.25);copy.advance(leg*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and destination.resources.water>water and game.run.supply.trips_reported==0,"Paid cargo crosses deliberate closure and still withholds its report")
	game.advance(leg*0.25);copy.advance(leg*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and link.closed and not link.busy() and source.workers_available==available and game.run.supply.trips_reported==1,"Carriers return/report once and the connection remains closed to future trips")
	assert(game.connection_order(link.route_id,"home","open").accepted);game.advance(40)
	test.check(game.run.supply.trips_started==1 and not link.busy(),"Reopening never restarts an old repeating supply order")
	test.check(game.run.reports.project("satellite_1").any(func(entry: Dictionary)->bool:return entry.kind=="connection" and entry.detail=="closed"),"The local closing endpoint retains its own policy report")
func _paid_parties(test: Object) -> void:
	for action: String in ["migrate","rescue_stores","relocate_queen","rescue_brood","rescue_royals"]:
		var game: SimulationController
		match action:
			"relocate_queen":game=preload("res://tests/test_queen_relocation.gd").new().fixture()
			"rescue_brood":game=preload("res://tests/test_brood_rescue.gd").new().fixture()
			"rescue_royals":game=preload("res://tests/test_royal_rescue.gd").new().fixture()
			_:game=Connections.new().fixture()
		var link: ConnectionTrafficState=game.run.all_connections()[0];var source: String="satellite_1";var selection: String="water" if action=="rescue_stores" else ""
		assert(game.connection_order(link.route_id,source,action,8,selection).accepted);game.advance(0.75)
		var total: int=game.run.colony.workers_total
		test.check(game.connection_order(link.route_id,source,"close").accepted and link.busy() and game.run.colony.workers_total==total,"Closure preserves already-paid "+action+" bodies and labor")
		var copy: SimulationController=copy_of(game,test);game.advance(100);copy.advance(100)
		test.check(game.run.to_dict()==copy.run.to_dict() and link.closed and not link.busy(),"Paid "+action+" completes actual landing/report through closed policy")
		test.check(copy_of(game,test).run.to_dict()==game.run.to_dict(),"Completed closed "+action+" preserves its receipt and ownership")
	# Return remains allowed while closure blocks new dispatches.
	var game: SimulationController=preload("res://tests/test_royal_rescue.gd").new().fixture("larva");var link: ConnectionTrafficState=game.run.all_connections()[0]
	assert(game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted);game.advance(1.25);assert(game.connection_order(link.route_id,"home","close").accepted)
	test.check(game.connection_order(link.route_id,"satellite_1","recall_royals").accepted,"Closed policy still allows deliberate physical return of a paid reproductive party")
	var copy: SimulationController=copy_of(game,test);game.advance(1.25);copy.advance(1.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and game.run.colony.piles.satellite_1.reproduction.phase=="larva" and link.closed,"A recalled group returns to its original nurses without reopening traffic")
func _saves(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture();var link: ConnectionTrafficState=game.run.all_connections()[1];var old: Dictionary=Connections.new().snapshot(game)
	for record: Dictionary in old.connection_traffic.values():
		for key: String in ["closed","policy_actor","policy_tick"]:record.erase(key)
	var copy:=Controller.new();test.check(copy.restore_snapshot(old) and copy.run.to_dict()==game.run.to_dict(),"Old absent connection policy defaults open without inventing commands")
	assert(game.connection_order(link.route_id,"satellite_1","rescue_stores",5,"protein").accepted);game.advance(1);assert(game.connection_order(link.route_id,"satellite_2","close").accepted)
	var saved: Dictionary=Connections.new().snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		copy=Controller.new();assert(copy.restore_snapshot(saved));copy.set_time_scale(scale);copy.advance(80.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Closed paid travel continues equally at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(100);test.check(before==game.run.to_dict(),"Pause keeps closed-policy cargo and reports stationary")
	for mode: String in ["type","actor","future","missing","before_departure"]:
		var bad: Dictionary=saved.duplicate(true);var record: Dictionary=bad.connection_traffic[link.route_id]
		match mode:
			"type":record.closed="yes"
			"actor":record.policy_actor="home"
			"future":record.policy_tick=game.run.clock.tick_count+1
			"missing":record.policy_actor=""
			"before_departure":record.policy_tick=record.stores.satellite_1.departed_tick-1
		copy=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and before==copy.run.to_dict(),"Forged connection policy "+mode+" rejects atomically")
func _controls(test: Object) -> void:
	var root:=Root.new();root.simulation=Connections.new().fixture();var view:=InwardView.new();test.get_root().add_child(view);root._inward_view=view;view.status_provider=root.focused_inward_status;view.connection_command=root.connection_order;view.selected_id="entrance";view._process(0)
	var size: Vector2=view.get_viewport_rect().size;var before: Dictionary=root.simulation.run.to_dict();view.activate_at(view.connection_controls.button(size).get_center())
	test.check(before==root.simulation.run.to_dict(),"Opening connection inspection cannot close traffic or fund travel")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.connection_controls.rect(size,"policy").get_center();view._unhandled_input(touch);view._process(0)
	var link: ConnectionTrafficState=root.simulation.run.connection_for(view.connection_controls.selected)
	test.check(link.closed and not link.busy(),"Explicit touch CLOSE TRAFFIC changes policy without dispatch")
	view.activate_at(view.connection_controls.rect(size,"order").get_center());view._process(0)
	test.check(link.closed and not link.busy(),"Closed ORDER gives a wait instead of spending a hidden supply order")
	view.activate_at(view.connection_controls.rect(size,"policy").get_center());view._process(0)
	test.check(not link.closed and not link.busy(),"Explicit reopen remains separate from ORDER")
	view.free();root.free()
