extends RefCounted
const Connections=preload("res://tests/test_connection_transport.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func run(test: Object) -> bool:
	_transport(test);_traits(test);_recall(test);_rejection(test);_saves(test);_controls(test);return true
func copy_of(game: SimulationController) -> SimulationController:
	var copy:=Controller.new();assert(copy.restore_snapshot(Connections.new().snapshot(game)));return copy
func _transport(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture()
	for link: ConnectionTrafficState in game.run.all_connections():
		for source: String in [link.parent_id,link.child_id]:
			var payer: PileState=game.run.colony.piles[source];var recipient: PileState=game.run.colony.piles[link.target(source)]
			var leg: int=InterpileSupplyState.TRAILS.leg_ticks(payer.position.distance_to(recipient.position))
			for resource: String in PileState.RESOURCE_IDS:
				var available: int=payer.workers_available;var count: int=game.run.colony.workers_total;var stock: float=recipient.resources[resource];var reports: int=link.stores[source].trips_reported
				test.check(game.connection_order(link.route_id,source,"rescue_stores",5,resource).accepted and payer.workers_available==available-8,"Finite "+resource+" pack reserves real returning labor")
				var saved: Dictionary=game.run.to_dict()
				test.check(not game.connection_order(link.route_id,link.target(source),"supply").accepted and not game.connection_order(link.route_id,source,"migrate",1).accepted and saved==game.run.to_dict(),"Store custody excludes the other direction and worker job")
				var copy: SimulationController=copy_of(game);game.advance(leg*0.25);copy.advance(leg*0.25)
				test.check(game.run.to_dict()==copy.run.to_dict() and recipient.resources[resource]>=stock+4 and link.stores[source].trips_reported==reports,"Actual finite cargo arrives once with no early receipt")
				var summary: Dictionary=StoreRescueSystem.new(game.run,source,link.route_id).summary_for()
				test.check(summary.away and summary.reports==reports and not summary.has("phase") and not summary.has("arrived"),"Store summaries hide private landing and direction")
				copy=copy_of(game);game.advance(leg*0.25);copy.advance(leg*0.25)
				test.check(game.run.to_dict()==copy.run.to_dict() and not link.busy() and payer.workers_available==available and game.run.colony.workers_total==count,"Returning carriers report a single pack without migration or repeating")
				test.check(link.stores[source].last_payload[resource]==5 and game.run.reports.project(source).any(func(entry: Dictionary)->bool:return entry.kind=="store_rescue" and entry.detail=="delivered:"+resource),"Returned finite receipt retains actual nutrient and amount")
				test.check(copy_of(game).run.to_dict()==game.run.to_dict(),"Completed store receipt restores on either connection/direction")
		# Ordinary supplies retain their own fixed pack and independent history.
		assert(game.connection_order(link.route_id,link.parent_id,"supply").accepted);game.advance(0.25);game.connection_order(link.route_id,link.parent_id,"stop_supply");game.advance(100)
		test.check(link.supplies[link.parent_id].trips_reported==1 and copy_of(game).run.to_dict()==game.run.to_dict(),"Ordinary packs retain independent exact history after custom rescue")
func _traits(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var source: PileState=game.run.colony.piles.home
	assert(game.connection_order(link.route_id,source.id,"migrate",45).accepted);game.advance(100)
	assert(game.start_adaptation(source.id,"load"));game.advance(360)
	for cycle: int in 8:
		if StoreRescueSystem.new(game.run,source.id,link.route_id).summary_for().capacity>=9:break
		assert(game.start_brood(source.id));game.advance(360)
	var system:=StoreRescueSystem.new(game.run,source.id,link.route_id);var plan: Dictionary=system._draft("water",9)
	test.check(source.adaptation_fraction()>0 and system.summary_for("water",9).capacity>=9 and plan.carry>1 and plan.energy>1,"Actual inherited carrying expression increases finite pack space with its travel-energy cost")
	test.check(game.connection_order(link.route_id,source.id,"rescue_stores",9,"water").accepted and link.stores.home.carry_multiplier==plan.carry and link.stores.home.energy_multiplier==plan.energy,"Departure captures actual carrying and energy traits for the finite cargo")
	var copy: SimulationController=copy_of(game);game.advance(100);copy.advance(100)
	test.check(game.run.to_dict()==copy.run.to_dict() and link.stores.home.last_payload.water==9,"A carrying-trait pack completes and saves with its real enlarged receipt")
func _recall(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture();var link: ConnectionTrafficState=game.run.all_connections()[0];var source: PileState=game.run.colony.piles.home
	var stock: float=source.resources.water;var available: int=source.workers_available
	assert(game.connection_order(link.route_id,"home","rescue_stores",7,"water").accepted);game.advance(1.25)
	test.check(game.connection_order(link.route_id,"home","recall_stores").accepted and absf(source.resources.water-(stock-7))<0.2,"Recall requests travel; packed water remains away")
	var copy: SimulationController=copy_of(game);game.advance(1);copy.advance(1)
	test.check(game.run.to_dict()==copy.run.to_dict() and link.busy(),"A recalled pack and carriers remain physical during reversed travel")
	game.advance(0.25);copy.advance(0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and absf(source.resources.water-stock)<0.2 and source.workers_available==available and link.stores.home.last_payload.water==0,"Real return restores unused stock once and reports no delivery")
	stock=source.resources.protein;assert(game.connection_order(link.route_id,"home","rescue_stores",3,"protein").accepted)
	test.check(game.connection_order(link.route_id,"home","recall_stores").accepted and source.resources.protein==stock and copy_of(game).run.to_dict()==game.run.to_dict(),"Zero-distance recall returns the same packet without refunding paid travel")
	var intake: SimulationController=Connections.new().fixture();link=intake.run.all_connections()[0];source=intake.run.colony.piles.home
	source.food_toxicity.mass=10;var initial: float=source.food_toxicity.mass;var amount: float=source.resources.carbohydrate
	assert(intake.connection_order(link.route_id,"home","rescue_stores",4,"carbohydrate").accepted)
	var carried: float=link.stores.home.contaminant_mass;var after: float=source.food_toxicity.mass
	intake.connection_order(link.route_id,"home","recall_stores")
	test.check(carried>0 and source.food_toxicity.mass>after and source.food_toxicity.mass<=initial and source.resources.carbohydrate<amount,"Recalled carbohydrate preserves contamination and spends only real travel food")
	test.check(copy_of(intake).run.to_dict()==intake.run.to_dict(),"Contaminated recalled cargo and its receipt restore exactly")
func _rejection(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture();var link: ConnectionTrafficState=game.run.all_connections()[0]
	for item: Array in [[0,"water"],[9,"water"],[-1,"protein"],[2,"invented"]]:
		var before: Dictionary=game.run.to_dict();test.check(not game.connection_order(link.route_id,"home","rescue_stores",item[0],item[1]).accepted and before==game.run.to_dict(),"Malformed or oversized store draft rejects atomically")
	game.run.colony.piles.home.resources.water=0;var before: Dictionary=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,"home","rescue_stores",1,"water").accepted and before==game.run.to_dict(),"Unavailable stores do not create cargo or labor")
	var child: PileState=game.run.colony.piles.satellite_1;assert(game.start_brood(child.id))
	var allocated: bool=child.workers.create_commitment("test:busy","internal","test");assert(allocated)
	allocated=child.allocate_workers("test:busy",child.workers_assignable-7);assert(allocated);before=game.run.to_dict()
	test.check(not game.connection_order(link.route_id,child.id,"rescue_stores",1,"water").accepted and before==game.run.to_dict(),"Store rescue protects paid nursery care")
func _saves(test: Object) -> void:
	var game: SimulationController=Connections.new().fixture();var link: ConnectionTrafficState=game.run.all_connections()[1]
	var old: Dictionary=Connections.new().snapshot(game)
	for entry: Dictionary in old.connection_traffic.values():entry.erase("stores");entry.erase("last_cargo_kind")
	var copy:=Controller.new();test.check(copy.restore_snapshot(old) and copy.run.to_dict()==game.run.to_dict(),"Old connections default to no store journey")
	assert(game.connection_order(link.route_id,link.child_id,"rescue_stores",6,"protein").accepted);game.advance(1)
	var saved: Dictionary=Connections.new().snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		copy=Controller.new();assert(copy.restore_snapshot(saved));copy.set_time_scale(scale);copy.advance(80.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Finite store travel is equal at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(100);test.check(before==game.run.to_dict(),"Pause freezes paid store cargo and reports")
	for mode: String in ["amount","cargo","capacity","timing","receipt","double","kind","missing"]:
		var bad: Dictionary=saved.duplicate(true);var record: Dictionary=bad.connection_traffic[link.route_id];var stores: Dictionary=record.stores[link.child_id]
		match mode:
			"amount":stores.manifests[0].amount+=1
			"cargo":stores.cargo.protein+=1
			"capacity":stores.manifests[0].amount=100;stores.cargo.protein=100
			"timing":stores.manifests[0].arrived=stores.departed_tick+1
			"receipt":stores.delivered_units.protein=1
			"double":record.supplies[link.parent_id].phase="waiting";record.supplies[link.parent_id].enabled=true
			"kind":record.last_cargo_kind="supplies"
			"missing":record.erase("stores")
		copy=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and copy.run.to_dict()==before,"Counterfeit store "+mode+" rejects atomic load")
func _controls(test: Object) -> void:
	var root:=Root.new();root.simulation=Connections.new().fixture();var view:=InwardView.new();test.get_root().add_child(view);root._inward_view=view;view.status_provider=root.focused_inward_status;view.connection_command=root.connection_order;view.selected_id="entrance";view._process(0)
	var size: Vector2=view.get_viewport_rect().size;var before: Dictionary=root.simulation.run.to_dict()
	view.activate_at(view.connection_controls.button(size).get_center());view.activate_at(view.connection_controls.rect(size,"stores").get_center());view.activate_at(view.connection_controls.rect(size,"cohort_next").get_center());view.activate_at(view.connection_controls.rect(size,"less").get_center());view._process(0)
	test.check(view.connection_controls.purpose=="stores" and view.connection_controls.cargo_id=="carbohydrate" and view.connection_controls.settlers==7 and before==root.simulation.run.to_dict(),"Resource and amount selection are free store drafts")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.connection_controls.rect(size,"order").get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.connection_for(view.connection_controls.selected).stores.home.active(),"Explicit touch ORDER alone funds one store pack")
	view.activate_at(view.connection_controls.rect(size,"stop").get_center());view._process(0)
	test.check(not root.simulation.run.connection_for(view.connection_controls.selected).busy(),"Store return uses the shared control without migrating carriers")
	view.free();root.free()
