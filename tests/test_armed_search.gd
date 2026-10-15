extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Survey = preload("res://tests/test_journey_investigation.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Predator = preload("res://tests/test_predator.gd")

func run(test: Object) -> bool:
	var game: SimulationController=Survey.new().investigated_game()
	var root:=Root.new();root.simulation=game
	var view:=View.new();test.get_root().add_child(view)
	view.signal_provider=root.sensory_snapshot.bind("home");view.status_provider=root.outward_status.bind("home")
	view.journey_command=root.respond_to_journey;view.selected_id="signal:known:aphid_01";view.journey_open=true;view._process(0)
	var frozen: Dictionary=game.run.to_dict()
	var route: Dictionary=view._conflict_route()
	test.check(view.conflict.searching(route,view._status) and view.conflict.reason("conflict_send",route,view._status).is_empty(), "A returned unexplained loss offers an armed search immediately")
	for pointer: String in ["mouse","touch"]:
		view.conflict.reset();view._pointer_press(view._conflict_rect("conflict_send").get_center(),pointer)
		test.check(view.conflict.editing and view.conflict.preview(route,view._status).action=="SEARCH & DEFEND · 12 ANTS", "The selected whole search force has one explicit primary order")
		view._pointer_press(view._conflict_rect("draft_goal").get_center(),pointer)
		test.check(view.conflict.goal=="clear", "Unknown threats cannot silently switch to Hunt")
		for enabled: bool in [false,true]:
			view.conflict.all_hands=enabled
			var copy: Dictionary=view.conflict.borrowing_copy()
			test.check(copy.title.ends_with("ON" if enabled else "OFF") and copy.title.begins_with("BORROW WORKERS FROM OTHER JOBS"), "The staffing permission names the action and current state")
			test.check(ThemeDB.fallback_font.get_string_size(copy.title,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<=284 and ThemeDB.fallback_font.get_string_size(copy.detail,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<=284, "Borrowing title and explanation fit the actual compact control")
		test.check(game.run.to_dict()==frozen, "Planning a search and changing borrowing consent is free for "+pointer)
	view.conflict.all_hands=false
	test.check(not root.respond_to_journey("commit_hunt_12","route_1").accepted and game.run.to_dict()==frozen, "Unconfirmed Hunt rejects without changing a goal, food or labor")
	view._pointer_press(view._conflict_rect("draft_commit").get_center(),"touch")
	test.check(game.run.journey_response.active() and game.run.journey_response.defense.sent==12 and game.run.journey_response.reports.is_empty(), "Twelve armed searchers depart without a preliminary three-ant survey")
	test.check(not str(root.sensory_snapshot("home")).contains("wolf_spider"), "Ordering a search reveals no hidden creature identity")
	var departure: Dictionary=Defense.new().snapshot(game)
	game.toggle_pause();frozen=game.run.to_dict();game.advance(100)
	test.check(game.run.to_dict()==frozen,"Pause freezes the entire search")
	game.toggle_pause()
	var twin:=Controller.new()
	test.check(twin.restore_snapshot(departure),"An outbound search with no old predator survey restores")
	var encounter: Dictionary={};var inbound: Dictionary={}
	for tick: int in 1800:
		game.advance(0.25);twin.advance(0.25)
		if tick%40==0:test.check(game.run.to_dict()==twin.run.to_dict(),"Search travel/combat/return continues exactly after save")
		var state: JourneyResponseState=game.run.journey_response
		if state.predator_profile!="" and encounter.is_empty():
			encounter=Defense.new().snapshot(game)
			test.check(state.phase=="fighting" and root.outward_status("home").journey_response.reports.is_empty() and not str(root.sensory_snapshot("home")).contains("wolf_spider"),"Physical encounter remains private until a reporter reaches home")
			var restored:=Controller.new();test.check(restored.restore_snapshot(encounter) and restored.run.to_dict()==game.run.to_dict(),"Private search witness and combat restore exactly")
		if state.phase=="inbound" and inbound.is_empty():
			inbound=Defense.new().snapshot(game)
			var restored:=Controller.new();test.check(restored.restore_snapshot(inbound),"Returning search survivors and their private sighting restore")
		if not state.active():break
	test.check(not encounter.is_empty() and not inbound.is_empty() and not game.run.journey_response.active(),"The paid search physically encounters a predator and returns")
	var report: Dictionary=game.run.journey_response.reports.get("route_1",{})
	test.check(report.get("predator_profile","")=="wolf_spider" and report.received_at>report.observed_at,"Actual returning searchers deliver the witnessed identity with separate dates")
	view._process(0)
	test.check(view.conflict._latest(view._conflict_route(),view._status).text==SourceMemory.defense_label(game.run.journey_response.defense.outcomes.route_1),"The returned combat result leads a same-time species sighting")
	test.check(game.run.journey_response.defense.outcomes.has("route_1") and game.run.colony.piles.home.workers.invariant_holds(),"The ending report and real worker ledger remain authoritative")
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)),"The delivered search report and ending restore together")
	var late_ground: Dictionary=encounter.duplicate(true)
	late_ground.journey_response.orders.route_1=0
	late_ground.journey_response.reports["route_1"]={"finding":"surface","fraction":0.5,"observed_at":late_ground.clock.time,"received_at":late_ground.clock.time}
	assert(twin.restore_snapshot(encounter))
	var later_party:=JourneyResponseState.new()
	test.check(later_party.restore(late_ground.journey_response,twin.run.colony,twin.run.trails,twin.run.simulation_time,twin.run.world),"Later ground evidence preserves already-paid party validation")
	for speed: int in [1,4,16,64]:
		var paced:=Controller.new();var reference:=Controller.new()
		assert(paced.restore_snapshot(departure) and reference.restore_snapshot(departure))
		paced.set_time_scale(speed);paced.advance(80.0/speed);paced.set_time_scale(1);reference.advance(80)
		test.check(paced.run.to_dict()==reference.run.to_dict(),"Armed search is deterministic at speed "+str(speed))
	for fault: String in ["no_evidence","ground","hunt","false_contact","missing_contact"]:
		var broken: Dictionary=(encounter if fault=="missing_contact" else departure).duplicate(true)
		match fault:
			"no_evidence":broken.trails.routes[0].reported_losses=0
			"ground":broken.journey_response.reports["route_1"]={"finding":"surface","fraction":0.5,"observed_at":broken.clock.time-1,"received_at":broken.clock.time}
			"hunt":broken.journey_response.defense.goal="hunt"
			"false_contact":broken.journey_response.ambush_fraction=0.5;broken.journey_response.sampled_at=broken.clock.time;broken.journey_response.predator_profile="wolf_spider"
			"missing_contact":broken.journey_response.ambush_fraction=-1;broken.journey_response.sampled_at=0;broken.journey_response.predator_profile=""
		frozen=twin.run.to_dict();test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==frozen,"Malformed search save rejects atomically: "+fault)
	game=Predator.new()._fixture();root.simulation=game;frozen=game.run.to_dict()
	test.check(not root.respond_to_journey("commit_clear_12","route_1").accepted and game.run.to_dict()==frozen,"A hidden predator without a returned loss cannot enable an armed search")
	game=Survey.new().investigated_game();root.simulation=game
	# Isolated physical-absence fixture: an old loss is not proof a predator remains.
	game.run.predator.defeated_at=game.run.simulation_time
	test.check(root.respond_to_journey("commit_clear_12","route_1").accepted,"A remembered loss can fund a search even if the hidden threat has left")
	while game.run.journey_response.active():game.advance(0.25)
	test.check(game.run.journey_response.reports.is_empty() and game.run.journey_response.defense.outcomes.route_1.outcome=="not_found","An empty search returns Not Found without inventing a species")
	game=Survey.new().investigated_game();root.simulation=game
	assert(root.respond_to_journey("commit_clear_12","route_1").accepted)
	test.check(game.journey_response.recall(),"A search can be recalled before contact")
	while game.run.journey_response.active():game.advance(0.25)
	test.check(game.run.journey_response.reports.is_empty() and twin.restore_snapshot(Defense.new().snapshot(game)),"Early recall has no invented witness and remains a valid save")
	game=Survey.new().investigated_game();root.simulation=game
	var pile: PileState=game.run.colony.piles.home
	pile.midden.revealed=true;assert(game.sanitation.set_workers("home",4))
	assert(pile.workers.create_commitment("test:building","internal","home"))
	var protected: int=pile.workers_assignable-1
	assert(pile.allocate_workers("test:building",protected))
	test.check(root.respond_to_journey("commit_clear_3","route_1").accepted and not game.run.journey_response.active() and pile.midden.cleaners==4,"Borrowing OFF leaves other jobs staffed while an unconfirmed search recruits")
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)),"Queued armed-search intent with no survey report restores")
	test.check(root.respond_to_journey("all_commit_clear_3","route_1").accepted and game.run.journey_response.active() and pile.midden.cleaners==2 and pile.workers.count("test:building")==protected,"Borrowing ON takes only needed cancellable workers and protects building")
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)),"Borrowed unsurveyed search preserves valid care and ledger ownership")
	view.free();root.free();return true
