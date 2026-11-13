extends RefCounted
const Multi=preload("res://tests/test_additional_piles.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const OLD=preload("res://tests/test_parent_supply.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func copy_of(game: SimulationController) -> SimulationController:
	var copy:=Controller.new();assert(copy.restore_snapshot(snapshot(game)));return copy
func fixture() -> SimulationController:
	var game: SimulationController=Multi.new().three_piles()
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,200)
	return game
func run(test: Object) -> bool:
	_supplies(test);_migration(test);_profiles(test);_rejection(test);_saves(test);_controls(test)
	return true
func _supplies(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[1]
	var route: TrailRouteState=game.run.trails.routes[link.route_id];var parent: PileState=game.run.colony.piles[link.parent_id];var child: PileState=game.run.colony.piles[link.child_id]
	var leg: int=InterpileSupplyState.TRAILS.leg_ticks(parent.position.distance_to(child.position))
	var labor: int=parent.workers_available;var stores: float=child.resources.water
	test.check(game.connection_order(link.route_id,parent.id,"supply").accepted and parent.workers_available==labor-8,"An adjacent third-pile connection reserves actual payer supply labor")
	game.advance(0.25);game.connection_order(link.route_id,parent.id,"stop_supply")
	var copy: SimulationController=copy_of(game)
	game.advance(leg*0.25);copy.advance(leg*0.25)
	test.check(child.resources.water>stores and link.supplies[parent.id].trips_reported==0 and game.run.to_dict()==copy.run.to_dict(),"Third-nest cargo physically arrives with exact saved travel and no early report")
	game.advance(leg*0.25);copy.advance(leg*0.25)
	test.check(link.supplies[parent.id].trips_reported==1 and parent.workers_available==labor and route.status=="inactive" and game.run.to_dict()==copy.run.to_dict(),"Stop finishes the paid third-pile trip and physically releases all eight workers")
	var segments: int=game.run.trails.segments.size()
	test.check(game.connection_order(link.route_id,child.id,"supply").accepted,"Third nest can pay for the reverse direction on its same connection")
	var before: Dictionary=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,parent.id,"supply").accepted and not game.connection_order(link.route_id,child.id,"migrate",1).accepted and before==game.run.to_dict(),"Other directions and purposes cannot double-book one physical connection")
	game.advance(0.25);game.connection_order(link.route_id,child.id,"stop_supply");copy=copy_of(game)
	game.advance(2*leg*0.25);copy.advance(2*leg*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and link.supplies[child.id].trips_reported==1 and link.supplies[parent.id].trips_reported==1 and game.run.trails.segments.size()==segments,"Two-way deliveries retain independent payer receipts and share the actual segment")
	# Separate edges may operate simultaneously; no network-wide phantom slot.
	test.check(game.connection_order(link.route_id,child.id,"supply").accepted and game.set_daughter_supply(true),"Different physical connections can carry independently paid traffic")
	test.check(copy_of(game).run.to_dict()==game.run.to_dict(),"Concurrent distinct connection owners restore")
func _migration(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[1]
	var parent: PileState=game.run.colony.piles[link.parent_id];var child: PileState=game.run.colony.piles[link.child_id]
	var leg: int=WorkerReinforcementState.TRAILS.leg_ticks(parent.position.distance_to(child.position));var total: int=game.run.colony.workers_total
	var source_total: int=child.workers_total;var target_total: int=parent.workers_total
	test.check(game.connection_order(link.route_id,child.id,"migrate",3).accepted and child.workers.count("trail:"+link.route_id)==4,"A whole three-settler draft funds exactly three workers plus a real messenger")
	var copy: SimulationController=copy_of(game);game.advance(leg*0.25);copy.advance(leg*0.25)
	var state: WorkerReinforcementState=link.migrations[child.id];var summary: Dictionary=game.connection_summaries(child.id)[0].migration
	test.check(game.run.to_dict()==copy.run.to_dict() and parent.workers_total==target_total+3 and child.workers_total==source_total-3 and game.run.colony.workers_total==total,"Reverse third-nest settlement changes actual ownership at arrival, without death or duplication")
	test.check(state.assigned()==1 and summary.sent==4 and summary.reported_workers==0 and not summary.has("party_profiles") and not summary.has("settled"),"One messenger travels home; normal summaries retain sent labor and withhold private arrival")
	game.advance(leg*0.25);copy.advance(leg*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and state.reported_workers()==3 and state.last_settled==3,"Only the real returned messenger publishes the variable worker receipt")
	test.check(game.connection_order(link.route_id,parent.id,"migrate",1).accepted,"The next migration may choose a different whole count and paying pile")
	game.advance(0.25*5);test.check(game.connection_order(link.route_id,parent.id,"recall").accepted,"Outbound worker recall requests real reversal")
	copy=copy_of(game);game.advance(1);copy.advance(1)
	test.check(link.migrations[parent.id].active() and game.run.to_dict()==copy.run.to_dict(),"A recalled party stays committed until its physical return")
	game.advance(0.25);copy.advance(0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and link.migrations[parent.id].last_settled==0 and link.migrations[parent.id].moved_workers==0,"Recall before arrival settles nobody and preserves exact accounting")
	test.check(game.connection_order(link.route_id,child.id,"migrate",2).accepted and copy_of(game).run.to_dict()==game.run.to_dict(),"Changed counts preserve previous receipts while a new trip is paid")
	game.advance(2*leg*0.25)
	test.check(state.reported_workers()==5 and state.arrivals==2 and copy_of(game).run.to_dict()==game.run.to_dict(),"Repeated variable arrivals reconcile cumulative body and profile history")
	# The former Home-only worker job now admits a real reverse settlement too.
	var first: ConnectionTrafficState=game.run.all_connections()[0]
	test.check(game.connection_order(first.route_id,"satellite_1","migrate",2).accepted,"The first connection also supports reverse worker migration")
	game.advance(100);test.check(copy_of(game).run.to_dict()==game.run.to_dict(),"Original aliases and reverse first-link profile transfers reconcile together")
func _rejection(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[1];var child: PileState=game.run.colony.piles[link.child_id]
	for count: int in [0,-1,1000000]:
		var before: Dictionary=game.run.to_dict();test.check(not game.connection_order(link.route_id,child.id,"migrate",count).accepted and game.run.to_dict()==before,"Invalid or unsupported worker target rejects atomically")
	child.resources.carbohydrate=0;var before: Dictionary=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,child.id,"migrate",1).accepted and game.run.to_dict()==before,"Underfunded travel cannot reserve labor or replace receipts")
	test.check(game.connection_order(link.route_id,child.id,"supply").accepted,"Supply intent may wait at its own payer for actual food")
	game.advance(1);test.check(link.supplies[child.id].phase=="waiting" and link.supplies[child.id].trips_started==0,"No instant pack replenishment appears at an underfunded payer")
	game.connection_order(link.route_id,child.id,"stop_supply")
	child.resources.carbohydrate=100;game.start_brood(child.id)
	before=game.run.to_dict();test.check(not game.connection_order(link.route_id,child.id,"migrate",child.workers_available-1).accepted and game.run.to_dict()==before,"Migration protects already-laid brood care instead of spending all nominally free workers")
	before=game.run.to_dict();test.check(not game.connection_order("route_999",child.id,"supply").accepted and not game.connection_order(link.route_id,"home","supply").accepted and game.run.to_dict()==before,"Unknown and nonadjacent connections cannot spend or teleport assets")
func _saves(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[1];game.connection_order(link.route_id,link.child_id,"migrate",2)
	var saved: Dictionary=snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();copy.restore_snapshot(saved);copy.set_time_scale(scale);copy.advance(16.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Connection travel is fixed-step equal at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(60);test.check(game.run.to_dict()==before,"Pause cannot move bodies, consume packs or report settlements")
	for mode: String in ["missing","payer","double","counts","receipt","profiles","orphan"]:
		var bad: Dictionary=saved.duplicate(true);var record: Dictionary=bad.connection_traffic[link.route_id]
		match mode:
			"missing":bad.connection_traffic.erase(link.route_id)
			"payer":record.payer_id=link.parent_id
			"double":record.supplies[link.parent_id].phase="waiting";record.supplies[link.parent_id].enabled=true
			"counts":record.migrations[link.child_id].settlers+=1
			"receipt":record.migrations[link.child_id].moved_workers=1
			"profiles":record.migrations[link.child_id].party_profiles={"invented":2}
			"orphan":bad.connection_traffic.route_999=record
		var copy:=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and copy.run.to_dict()==before,"Forged connection "+mode+" rejects fresh-state restore atomically")
	var old: SimulationController=OLD.new().fixture();saved=snapshot(old);saved.erase("connection_traffic")
	for key: String in ["settlers","moved_workers","profiles_captured","party_profiles"]:saved.reinforcement.erase(key)
	var copy:=Controller.new();test.check(copy.restore_snapshot(saved) and copy.run.to_dict()==old.run.to_dict(),"Old absent transport records keep first-link semantics and invent no journeys")
func _controls(test: Object) -> void:
	var root:=Root.new();root.simulation=fixture();root.inspect_pile("satellite_1")
	var view:=InwardView.new();test.get_root().add_child(view);view.status_provider=root.focused_inward_status;view.connection_command=root.connection_order;view.selected_id="entrance";view._process(0)
	var before: Dictionary=root.simulation.run.to_dict();var size: Vector2=view.get_viewport_rect().size
	var mouse:=InputEventMouseButton.new();mouse.pressed=true;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=view.connection_controls.button(size).get_center();view._unhandled_input(mouse)
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.connection_controls.rect(size,"next").get_center();view._unhandled_input(touch)
	view.activate_at(view.connection_controls.rect(size,"workers").get_center());view.activate_at(view.connection_controls.rect(size,"less").get_center())
	test.check(view.connection_controls.opened and view.connection_controls.selected==root.simulation.run.all_connections()[1].route_id and view.connection_controls.settlers==7 and root.simulation.run.to_dict()==before,"Mouse/touch select a real adjacent link and draft whole migrants without funding")
	view.activate_at(view.connection_controls.rect(size,"order").get_center());view._process(0)
	test.check(root.simulation.run.connection_for(view.connection_controls.selected).migrations.satellite_1.active(),"Explicit ORDER is the only draft action that funds the selected route and payer")
	view.activate_at(view.connection_controls.rect(size,"stop").get_center());view._process(0)
	test.check(not root.simulation.run.connection_for(view.connection_controls.selected).busy(),"A same-frame Home departure recall releases actual zero-distance travelers once")
	view.free();root.free()

func _profiles(test: Object) -> void:
	var game: SimulationController=fixture();var link: ConnectionTrafficState=game.run.all_connections()[1]
	var source: PileState=game.run.colony.piles[link.parent_id];var target: PileState=game.run.colony.piles[link.child_id]
	assert(game.start_adaptation(source.id,"lean"));game.advance(360)
	assert(game.start_brood(source.id))
	var cohort: BroodCohort=source.brood_cohorts[0]
	for tick: int in 3000:
		if cohort.stage=="pupa" and cohort.progress_seconds>=BroodCohort.CONFIG.stage_seconds("pupa")-0.25:break
		game.advance(0.25)
	assert(cohort.stage=="pupa")
	test.check(game.connection_order(link.route_id,source.id,"migrate",8).accepted,"Mixed expressed/baseline adults can fund a real captured migration party")
	var state: WorkerReinforcementState=link.migrations[source.id];var captured: Dictionary=state.party_profiles.duplicate()
	test.check(captured.has("lean") and captured.has(""),"Departure captures disjoint actual phenotype bundles rather than converting all migrants")
	var copy: SimulationController=copy_of(game);var leg: int=WorkerReinforcementState.TRAILS.leg_ticks(source.position.distance_to(target.position))
	game.advance(leg*0.25);copy.advance(leg*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and state.settled and state.moved_profiles==captured and source.brood_cohorts.is_empty(),"New local adults emerging during travel do not rewrite the physically dispatched migrant bundle")
	test.check(target.genetics.count_trait("lean")==captured.lean and target.offspring_traits().is_empty(),"Imported expressed workers retain effects without silently rewriting the recipient queen")
	test.check(game.run.reports.project(source.id).all(func(entry: Dictionary)->bool:return entry.kind!="migration"),"No private worker settlement enters the report journal before its real messenger")
	game.advance(leg*0.25)
	var entries: Array[Dictionary]=game.run.reports.project(source.id)
	test.check(entries.any(func(entry: Dictionary)->bool:return entry.kind=="migration" and entry.amount==8 and entry.subject_id==target.id),"Returned migration receipt enters the correct paying pile's bounded reports")
	test.check(copy_of(game).run.to_dict()==game.run.to_dict(),"Mixed phenotype migration history restores after the independent receipt")
