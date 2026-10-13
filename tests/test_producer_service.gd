extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Web=preload("res://tests/test_adaptation_web.gd")
const Water=preload("res://tests/test_small_water_sources.gd")
func fixture() -> SimulationController:
	var game: SimulationController=Web.new().known_fixture();var pile: PileState=game.run.colony.piles.home
	for id: String in PileState.RESOURCE_IDS:pile.deposit_resource(id,2000)
	assert(game.create_trail("home","known:aphid_01"))
	for tick: int in 1000:
		if game.run.honeydew.relationship=="exploited":break
		game.advance(0.25)
	assert(game.run.honeydew.relationship=="exploited");game.set_trail_workers("route_1",0);game.advance(100);return game
func snapshot(game: SimulationController) -> Dictionary:return Water.new().snapshot(game)
func copy_of(game: SimulationController, test: Object) -> SimulationController:
	var copy:=Controller.new();test.check(copy.restore_snapshot(snapshot(game)),"Producer service restores its actual party and source ledger");return copy
func run(test: Object) -> bool:
	_travel(test);_effort(test);_edits(test);_failed_landing(test);_multiple_piles(test);_legacy(test);_rejection(test);_saves(test);_controls(test);return true
func _travel(test: Object) -> void:
	var game: SimulationController=fixture();var pile: PileState=game.run.colony.piles.home;var available: int=pile.workers_available;var carbs: float=pile.resources.carbohydrate;var system:=ProducerServiceSystem.new(game.run);var cost: float=system._cost(pile.id,3)
	test.check(game.set_honeydew_target(pile.id,3) and pile.workers.count("honeydew:home")==3 and absf(pile.resources.carbohydrate-(carbs-cost))<0.00001,"A whole three-attendant order pays actual round-trip food and care-protected labor")
	var state: ProducerServiceState=game.run.honeydew.services.home;var leg: int=state.leg_ticks
	test.check(state.phase=="outbound" and state.contribution()==0 and state.count==3,"Ordered attendants do not improve remote production before physically arriving")
	var known: Dictionary=system.summary(pile.id);var copy: SimulationController=copy_of(game,test);game.advance((leg-1)*0.25);copy.advance((leg-1)*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and state.phase=="outbound","Attendant travel continues exactly to the last pre-arrival interval")
	game.advance(0.25);copy.advance(0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and state.phase=="working" and state.contribution()==0.5 and system.summary(pile.id)==known,"Actual half-effort begins at the producer without a private arrival cue in the source summary")
	test.check(game.set_honeydew_target(pile.id,0) and pile.workers_available==available-3,"Withdrawal requests actual travel without releasing remote workers")
	copy=copy_of(game,test);game.advance(leg*0.25);copy.advance(leg*0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and state.phase=="none" and pile.workers_available==available and pile.workers.count("honeydew:home")==-1,"Actual attendant return releases one source commitment and never migrates workers")
func _effort(test: Object) -> void:
	var base: SimulationController=fixture();var before: Dictionary=snapshot(base);var outcomes: Array[float]=[]
	for count: int in [0,3,6,12,16]:
		var game:=Controller.new();assert(game.restore_snapshot(before))
		if count>0:assert(game.set_honeydew_target("home",count))
		game.advance(30)
		var source: WorldNodeState=game.run.world.nodes.aphid_01;source.quantity=0;source.active=false
		var condition: float=game.run.honeydew.condition;game.advance(30)
		outcomes.append(source.quantity)
		test.check(source.quantity>=0 and source.quantity<=40 and game.run.colony.piles.home.workers.invariant_holds(),"Producer output/worker conservation remains bounded at %d attendants" % count)
		if count>=6:test.check(game.run.honeydew.condition>condition,"Default or stronger actual service improves future producer condition")
	test.check(outcomes[0]<outcomes[1] and outcomes[1]<outcomes[2] and outcomes[2]<outcomes[3] and outcomes[3]==outcomes[4],"Below/default/above effort affects real new output, with benefit capped at double suggested support")
func _edits(test: Object) -> void:
	var game: SimulationController=fixture();assert(game.set_honeydew_target("home",6));game.advance(30)
	var state: ProducerServiceState=game.run.honeydew.services.home;var pile: PileState=game.run.colony.piles.home;var available: int=pile.workers_available
	test.check(game.set_honeydew_target("home",2) and state.target==2 and state.count==6 and state.phase=="returning" and pile.workers_available==available,"Edited service keeps six actual returning workers while the replacement target waits")
	var copy: SimulationController=copy_of(game,test);var return_seconds: float=state.leg_ticks*0.25;game.advance(return_seconds);copy.advance(return_seconds)
	test.check(game.run.to_dict()==copy.run.to_dict() and state.phase=="none" and state.count==0,"Old crew returns before replacement can claim its labor")
	game.advance(0.25);copy.advance(0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and state.count==2 and state.phase=="outbound" and pile.workers_available==available+4,"Replacement funds only its actual new two-worker party and travel")
	test.check(game.set_honeydew_target("home",0),"Outbound replacement can request physical recall")
func _failed_landing(test: Object) -> void:
	var game: SimulationController=fixture();assert(game.set_honeydew_target("home",4));var state: ProducerServiceState=game.run.honeydew.services.home
	var old: Dictionary=ProducerServiceSystem.new(game.run).summary("home");game.run.world.nodes.aphid_01.position+=Vector2(3,0)
	game.advance(state.leg_ticks*0.25)
	test.check(state.private_failure and state.phase=="returning" and ProducerServiceSystem.new(game.run).summary("home")==old,"An unsuitable remembered producer returns the party without leaking its private failure")
	var copy: SimulationController=copy_of(game,test);var return_seconds: float=state.leg_ticks*0.25;game.advance(return_seconds);copy.advance(return_seconds)
	test.check(game.run.to_dict()==copy.run.to_dict() and state.count==0 and state.last_result=="not_found" and game.run.honeydew.relationship=="exploited","Only actual returned attendants report a failed landing and stop service intent")
func _multiple_piles(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_connection_transport.gd").new().fixture()
	var authored:=Controller.new();var node: WorldNodeState=authored.run.world.nodes.aphid_01;node.position=Vector2(26,25);game.run.world.nodes.aphid_01=node
	var evidence: Observation=Water.new().sample(game,"aphid_01",game.run.next_scout_id);var inbox: Dictionary[String,Observation]={evidence.id:evidence};assert(game.run.knowledge.consume(inbox,game.run.simulation_time));game.run.next_scout_id+=1
	assert(game.create_trail("home","known:aphid_01"));assert(game.create_trail("satellite_1","known:aphid_01"));game.advance(100)
	var home_route: TrailRouteState=game.run.trails.find_route("home","known:aphid_01");var daughter_route: TrailRouteState=game.run.trails.find_route("satellite_1","known:aphid_01")
	assert(home_route.delivered_total>0 and daughter_route.delivered_total>0)
	game.set_trail_workers(home_route.id,0);game.set_trail_workers(daughter_route.id,0);game.advance(50)
	var home_free: int=game.run.colony.piles.home.workers_available;var daughter_free: int=game.run.colony.piles.satellite_1.workers_available
	test.check(game.set_honeydew_target("home",3) and game.set_honeydew_target("satellite_1",4) and game.run.colony.piles.home.workers_available==home_free-3 and game.run.colony.piles.satellite_1.workers_available==daughter_free-4,"Independent nests pay their own actual producer-service labor and travel")
	var copy: SimulationController=copy_of(game,test);game.advance(30);copy.advance(30)
	test.check(game.run.to_dict()==copy.run.to_dict() and game.run.honeydew.services.home.phase=="working" and game.run.honeydew.services.satellite_1.phase=="working","Two real parties reach the same producer without copying workers or source output")
	var root:=Root.new();root.simulation=game
	test.check(root.honeydew_summary("satellite_1").target==4 and not root.honeydew_summary("satellite_1").has("condition") and not root.honeydew_summary("satellite_1").has("phase"),"Daughter producer controls use her own target and approved knowledge")
	assert(game.set_honeydew_target("satellite_1",0));game.advance(20)
	test.check(game.run.honeydew.services.home.count==3 and game.run.honeydew.services.satellite_1.count==0 and copy_of(game,test).run.to_dict()==game.run.to_dict(),"Withdrawing one nest's duty preserves the other's independently staffed service")
	root.free()
func _legacy(test: Object) -> void:
	var game: SimulationController=fixture();assert(game.set_honeydew_target("home",6));game.advance(30)
	var old: Dictionary=snapshot(game);old.honeydew.erase("services");old.honeydew.erase("service_version")
	var copy:=Controller.new();test.check(copy.restore_snapshot(old) and copy.run.honeydew.services.home.legacy_onsite and copy.run.honeydew.services.home.phase=="working" and copy.run.colony.piles.home.resources==game.run.colony.piles.home.resources,"Already-paid old Home duty migrates onsite without new food charges or reporters")
	test.check(copy_of(copy,test).run.to_dict()==copy.run.to_dict(),"Migrated legacy onsite service becomes a canonical current snapshot")
func _rejection(test: Object) -> void:
	var game: SimulationController=fixture()
	for count: Variant in [-1,1.5,17,"six"]:
		var before: Dictionary=game.run.to_dict();test.check(not game.set_honeydew_target("home",count) and before==game.run.to_dict(),"Malformed/out-of-cap service target rejects atomically")
	game.run.colony.piles.home.resources.carbohydrate=0;var before: Dictionary=game.run.to_dict()
	test.check(not game.set_honeydew_target("home",1) and before==game.run.to_dict(),"Underfunded initial service cannot claim labor or production")
func _saves(test: Object) -> void:
	var game: SimulationController=fixture();assert(game.set_honeydew_target("home",5));game.advance(1)
	var saved: Dictionary=snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();assert(copy.restore_snapshot(saved));copy.set_time_scale(scale);copy.advance(50.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Paid producer service is equal at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(100);test.check(before==game.run.to_dict(),"Pause cannot move attendants or generate extra output")
	for mode: String in ["count","phase","time","owner","mirror","capture","partial_modern"]:
		var bad: Dictionary=saved.duplicate(true);var service: Dictionary=bad.honeydew.services.home
		match mode:
			"count":service.count+=1
			"phase":service.phase="working"
			"time":service.departed_tick=game.run.clock.tick_count+1
			"owner":bad.honeydew.services.satellite_999=service
			"mirror":bad.honeydew.protection_workers=1
			"capture":service.required=1
			"partial_modern":bad.honeydew.erase("services")
		var copy:=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and before==copy.run.to_dict(),"Forged producer "+mode+" rejects atomic restore")
func _controls(test: Object) -> void:
	var root:=Root.new();root.simulation=fixture();var view:=InwardView.new();test.get_root().add_child(view);root._inward_view=view;view.status_provider=root.focused_inward_status;view.effort_command=root.set_effort;view.selected_id="adaptation";view.web_selection="honeydew";view._process(0)
	var before: Dictionary=root.simulation.run.to_dict();view.activate_at(view._honeydew_rect().get_center())
	test.check(view.effort_draft.opened and before==root.simulation.run.to_dict(),"Tending selection opens a free draft rather than committing workers")
	view.activate_at(view.effort_draft.rect(view.get_viewport_rect().size,"effort_less").get_center());view._process(0)
	test.check(view.effort_draft.amount==5 and before==root.simulation.run.to_dict(),"Whole attendant edits and quoted price remain free")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view.effort_draft.rect(view.get_viewport_rect().size,"effort_commit").get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.honeydew.services.home.count==5 and not view.effort_draft.opened,"Explicit touch ORDER alone funds the selected five-attendant party")
	view.free();root.free()
