extends RefCounted
const Maternal=preload("res://tests/test_maternal_lineage.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func fixture() -> SimulationController:
	var game: SimulationController=Maternal.new().mature_daughter()
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,500)
	game.run.colony.piles.home.queen_count=0
	return game
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func copy_of(game: SimulationController, test: Object, label: String) -> SimulationController:
	var copy:=Controller.new();test.check(copy.restore_snapshot(snapshot(game)),label);return copy
func run(test: Object) -> bool:
	_relocation(test);_recall(test);_inheritance(test);_continued_lineage(test);_rejection(test);_saves(test);_controls(test)
	return true
func _relocation(test: Object) -> void:
	var game: SimulationController=fixture();var home: PileState=game.run.colony.piles.home;var daughter: PileState=game.run.colony.piles.satellite_1
	var route_id: String=game.run.founding.route_id;var link: ConnectionTrafficState=game.run.connection_for(route_id)
	var identity: String=daughter.queen.queen_id(daughter.id);var generation: int=daughter.queen.generation;var condition: int=daughter.queen.condition
	var total: int=game.run.colony.workers_total;var leg: int=WorkerReinforcementState.TRAILS.leg_ticks(home.position.distance_to(daughter.position))
	assert(game.start_brood(daughter.id));var source_brood: Dictionary=daughter.brood_cohorts[0].to_dict()
	var before: Dictionary=game.run.to_dict()
	test.check(not game.connection_order(route_id,daughter.id,"relocate_queen",1).accepted and game.run.to_dict()==before,"Queen travel needs actual supported escorts; inadequate orders spend nothing")
	test.check(game.connection_order(route_id,daughter.id,"relocate_queen",4).accepted,"An actual later-generation laying mother can fund adjacent queenless recovery")
	var transport: QueenTransportState=link.queens[daughter.id]
	test.check(daughter.queen.count==0 and home.queen.count==0 and transport.body.identity==identity and transport.body.condition==condition and transport.movement.assigned()==5,"The one mother is physically owned by transit and five real workers remain with their paying ledger")
	test.check(daughter.brood_cohorts[0].to_dict()==source_brood and game.queens.summary(daughter.id).status=="relocating","Funded brood stays local and the departed mother is reported as relocating rather than dead")
	before=game.run.to_dict()
	test.check(not game.queens.start_replacement(home.id) and not game.connection_order(route_id,daughter.id,"supply").accepted and not game.connection_order(route_id,daughter.id,"migrate",2).accepted and game.run.to_dict()==before,"Queen slots and the physical connection reject conflicting jobs atomically")
	var copy: SimulationController=copy_of(game,test,"A physically departing mother restores without duplication")
	game.advance((leg-1)*0.25);copy.advance((leg-1)*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and home.queen.count==0,"Paid queen travel cannot restore laying before actual arrival")
	game.advance(0.25);copy.advance(0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and home.queen.count==1 and home.queen.queen_id(home.id)==identity and home.queen.generation==generation and transport.body.is_empty() and game.run.colony.workers_total==total,"Arrival transfers the actual mother's identity/generation and escorts exactly once")
	test.check(game.connection_summaries(daughter.id)[0].queen.queen_deliveries==0 and transport.movement.assigned()==1,"The actual returning messenger withholds queen delivery while Home observes its own arrived mother")
	copy=copy_of(game,test,"Arrived queen plus unreturned messenger has one body owner")
	game.advance(leg*0.25);copy.advance(leg*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and game.connection_summaries(daughter.id)[0].queen.queen_deliveries==1 and game.queens.summary(daughter.id).status=="relocated","Only the returned messenger confirms delivery and releases both reserved queen slots")
	test.check(game.run.reports.project(daughter.id).any(func(entry: Dictionary)->bool:return entry.kind=="relocation" and entry.detail=="delivered" and entry.amount==4),"Queen relocation has a returned, payer-owned journal settlement")
	test.check(game.start_brood(home.id) and home.brood_cohorts[0].parent_queen_id==identity,"The transported laying mother continues her actual lineage at Home")
	game.advance(360)
	test.check(copy_of(game,test,"Both original-mother source brood and incoming-mother Home offspring restore after growth").run.to_dict()==game.run.to_dict(),"Relocation does not erase funded source brood or invent new parentage")
func _recall(test: Object) -> void:
	var game: SimulationController=fixture();var route_id: String=game.run.founding.route_id;var source: PileState=game.run.colony.piles.satellite_1
	var identity: String=source.queen.queen_id(source.id);var available: int=source.workers_available
	test.check(game.connection_order(route_id,source.id,"relocate_queen",2).accepted,"A small supported queen party may depart")
	game.advance(1.75);test.check(game.connection_order(route_id,source.id,"recall_queen").accepted and source.queen.count==0,"Recall reverses travel without immediately repatriating the mother")
	var copy: SimulationController=copy_of(game,test,"A recalled physical queen and escorts restore")
	game.advance(1.5);copy.advance(1.5);test.check(game.run.to_dict()==copy.run.to_dict() and source.queen.count==0,"Recalled mother remains away for the actual return distance")
	game.advance(0.25);copy.advance(0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and source.queen.count==1 and source.queen.queen_id(source.id)==identity and source.workers_available==available,"Returning party restores the original mother and all real workers once")
	test.check(game.run.connection_for(route_id).queens[source.id].movement.reported_arrivals()==0 and game.run.colony.piles.home.queen.count==0,"Recalled relocation creates neither a recipient queen nor migrated workers")
	test.check(game.connection_order(route_id,source.id,"relocate_queen",3).accepted and game.connection_order(route_id,source.id,"recall_queen").accepted and source.queen.count==1,"A zero-distance queen recall restores ownership immediately without a second body")
	copy_of(game,test,"Repeated queen recall receipts restore")
func _inheritance(test: Object) -> void:
	var game: SimulationController=fixture();var source: PileState=game.run.colony.piles.satellite_1;var target: PileState=game.run.colony.piles.home
	assert(game.start_adaptation(source.id,"lean"));game.advance(360)
	var identity: String=source.queen.queen_id(source.id);var route_id: String=game.run.founding.route_id
	test.check(game.connection_order(route_id,source.id,"relocate_queen",2).accepted,"A trait-owning queen may travel with baseline escorts")
	var state: QueenTransportState=game.run.connection_for(route_id).queens[source.id]
	test.check(state.movement.party_profiles=={"":2} and state.body.inherited_traits==["lean"],"Maternal inheritance is independent of the adult escort phenotype bundle")
	game.advance(100);copy_of(game,test,"An inherited queen without expressed recipient adults restores")
	test.check(target.offspring_traits()==["lean"] and target.genetics.count_trait("lean")==0 and target.genetics.established.is_empty(),"Queen arrival neither converts adults nor invents an expressed repertoire")
	test.check(game.start_brood(target.id) and target.brood_cohorts[0].adaptation_id=="lean" and target.brood_cohorts[0].parent_queen_id==identity,"Her first paid local brood captures inheritance without needing imported adapted adults")
	copy_of(game,test,"Unemerged inherited offspring restore independently of adult expression")
	game.advance(360);copy_of(game,test,"Real offspring establish expressed adult traits through birth after relocation")
	test.check(target.genetics.count_trait("lean")>0 and target.genetics.count_trait("lean")<=8 and target.offspring_traits()==["lean"],"Only actual offspring emergence expresses the transported mother's trait")
	# Move an older mother into a younger queenless site with its own paid brood.
	var reverse: SimulationController=Maternal.new().mature_daughter();source=reverse.run.colony.piles.home;target=reverse.run.colony.piles.satellite_1
	for pile: PileState in reverse.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,500)
	assert(reverse.start_brood(target.id));var former: String=target.queen.queen_id(target.id);target.queen_count=0
	test.check(reverse.connection_order(reverse.run.founding.route_id,source.id,"relocate_queen",3).accepted,"A recipient's funded old-mother brood does not forbid rescue by an unrelated older mother")
	reverse.advance(100);copy_of(reverse,test,"Unrelated parent generations retain their actual mother history on arrival")
	test.check(target.queen.generation==0 and target.brood_cohorts[0].parent_queen_id==former and target.brood_cohorts[0].parent_generation==1,"Mother transfer preserves generation rather than rewriting existing brood or inventing ancestry")
func _saves(test: Object) -> void:
	var game: SimulationController=fixture();var route_id: String=game.run.founding.route_id
	game.connection_order(route_id,"satellite_1","relocate_queen",2);var saved: Dictionary=snapshot(game)
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();test.check(copy.restore_snapshot(saved),"Queen journey baseline restores for fixed-step test")
		copy.set_time_scale(scale);copy.advance(20.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Queen ownership/travel is equal at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(60);test.check(before==game.run.to_dict(),"Pause preserves queen/body/escort/care/report ownership")
	for mode: String in ["duplicate","body","manifest","payer","slot","profiles"]:
		var bad: Dictionary=saved.duplicate(true);var state: Dictionary=bad.connection_traffic[route_id].queens.satellite_1
		match mode:
			"duplicate":bad.colony.piles[1].queen_count=1;bad.colony.piles[1].queen.count=1;bad.colony.piles[1].queen.condition=1000000
			"body":state.body.clear()
			"manifest":state.manifests[0].body.condition=0
			"payer":bad.supply_origin="home"
			"slot":bad.colony.piles[0].queen.previous_mothers=[{"identity":"queen:fake","generation":0,"inherited_traits":[]}]
			"profiles":state.movement.party_profiles={"lean":2}
		var copy:=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and before==copy.run.to_dict(),"Corrupt queen transport "+mode+" rejects atomically")
	var old: SimulationController=fixture();saved=snapshot(old)
	for pile: Dictionary in saved.colony.piles:pile.queen.erase("arrival_record");pile.queen.erase("previous_mothers");pile.queen.erase("in_transit")
	for record: Dictionary in saved.connection_traffic.values():record.erase("queens")
	var copy:=Controller.new();test.check(copy.restore_snapshot(saved) and copy.run.to_dict()==old.run.to_dict(),"Old absent queen transport/history fields invent neither bodies nor trips")
func _controls(test: Object) -> void:
	var root:=Root.new();root.simulation=fixture();root.inspect_pile("satellite_1")
	var view:=InwardView.new();test.get_root().add_child(view);root._inward_view=view;view.status_provider=root.focused_inward_status;view.connection_command=root.connection_order;view.selected_id="entrance";view._process(0)
	var size: Vector2=view.get_viewport_rect().size;var before: Dictionary=root.simulation.run.to_dict()
	view.activate_at(view.connection_controls.button(size).get_center());var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.connection_controls.rect(size,"queen").get_center();view._unhandled_input(touch)
	view.activate_at(view.connection_controls.rect(size,"less").get_center());view._process(0)
	test.check(view.connection_controls.purpose=="queen" and view.connection_controls.settlers==7 and root.simulation.run.to_dict()==before,"Queen selection/escort draft use free shared touch/mouse paths")
	view.activate_at(view.connection_controls.rect(size,"order").get_center());view._process(0)
	test.check(root.simulation.run.connection_for(view.connection_controls.selected).queens.satellite_1.active(),"Explicit Queen ORDER moves the actual mother into paid transport")
	view.activate_at(view.connection_controls.rect(size,"stop").get_center());view._process(0)
	test.check(root.simulation.run.colony.piles.satellite_1.queen.count==1,"The common return control recalls the currently assigned queen party")
	view.free();root.free()

func _rejection(test: Object) -> void:
	var game: SimulationController=fixture();var route_id: String=game.run.founding.route_id;var source: PileState=game.run.colony.piles.satellite_1;var target: PileState=game.run.colony.piles.home
	source.resources.protein=0;var before: Dictionary=game.run.to_dict()
	test.check(not game.connection_order(route_id,source.id,"relocate_queen",2).accepted and game.run.to_dict()==before,"Unfunded queen care provisions cannot reserve an escort or remove the mother")
	source.resources.protein=100;target.queen_count=1;before=game.run.to_dict()
	test.check(not game.connection_order(route_id,source.id,"relocate_queen",2).accepted and game.run.to_dict()==before,"Current one-mother ownership rejects an occupied recipient without creating queen coexistence")
	target.queen_count=0;assert(game.start_brood(source.id));before=game.run.to_dict()
	test.check(not game.connection_order(route_id,source.id,"relocate_queen",source.workers_available-1).accepted and game.run.to_dict()==before,"Queen rescue holds care for already-funded local brood")
	# Funded opposite local traits are already known commitments and cannot be erased.
	game=Maternal.new().mature_daughter();source=game.run.colony.piles.satellite_1;target=game.run.colony.piles.home
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,500)
	assert(game.start_adaptation(source.id,"lean"));game.advance(360);assert(game.start_adaptation(target.id,"load"));target.queen_count=0;route_id=game.run.founding.route_id
	before=game.run.to_dict();test.check(not game.connection_order(route_id,source.id,"relocate_queen",2).accepted and game.run.to_dict()==before,"A queen cannot overwrite incompatible already-funded recipient brood")
	# A separate connection's real migrants can change suitability during the journey.
	game=preload("res://tests/test_additional_piles.gd").new().three_piles()
	for pile: PileState in game.run.colony.piles.values():
		for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,500)
	source=game.run.colony.piles.home;target=game.run.colony.piles.satellite_1;var third: PileState=game.run.colony.piles.satellite_2
	assert(game.start_adaptation(source.id,"lean"));assert(game.start_adaptation(third.id,"load"));game.advance(360);target.queen_count=0
	var other: ConnectionTrafficState=game.run.all_connections()[1];route_id=game.run.founding.route_id
	assert(game.connection_order(other.route_id,third.id,"migrate",8).accepted)
	var leg: int=WorkerReinforcementState.TRAILS.leg_ticks(source.position.distance_to(target.position));var other_leg: int=WorkerReinforcementState.TRAILS.leg_ticks(third.position.distance_to(target.position))
	game.advance(maxi(1,other_leg-leg+1)*0.25)
	test.check(game.connection_order(route_id,source.id,"relocate_queen",2).accepted,"Queen travel can share a network with a distinct connection's real incoming workers")
	var copy: SimulationController=copy_of(game,test,"Different-edge migrant and queen journeys coexist with distinct physical owners")
	game.advance(100);copy.advance(100)
	var transport: QueenTransportState=game.run.connection_for(route_id).queens[source.id]
	test.check(game.run.to_dict()==copy.run.to_dict() and source.queen.count==1 and target.queen.count==0 and transport.movement.arrivals==0 and target.genetics.count_trait("load")>0,"Incompatible actual arrival returns the real mother/escort rather than installing contradictory traits")
	test.check(transport.last_report().reason=="landing" and game.connection_summaries(source.id)[0].queen.last_result=="landing","Only a returned party explains the recipient became unsuitable")
	copy_of(game,test,"A failed landing has no invented arrival/body/profile receipt")

func _continued_lineage(test: Object) -> void:
	var game: SimulationController=fixture();var target: PileState=game.run.colony.piles.home;var route_id: String=game.run.founding.route_id
	assert(game.connection_order(route_id,"satellite_1","relocate_queen",3).accepted);game.advance(100)
	var arrived: String=target.queen.queen_id(target.id)
	assert(game.start_adaptation(target.id,"lean"));game.advance(360)
	test.check(target.offspring_traits()==["lean"],"A physically arrived mother can fund her own later local inherited trial")
	assert(game.start_reproduction(target.id));game.advance(800);assert(target.reproduction.phase=="ready")
	target.queen_count=0;assert(game.replace_queen(target.id));game.advance(120)
	var copy: SimulationController=copy_of(game,test,"Local replacement after an imported mother's paid trait learning restores its actual ancestor")
	test.check(copy.run.to_dict()==game.run.to_dict() and target.queen.queen_id(target.id)!=arrived and target.queen.parent_identity==arrived and target.offspring_traits()==["lean"],"Queen relocation permits continued paid local lineage rather than freezing its imported bundle forever")
