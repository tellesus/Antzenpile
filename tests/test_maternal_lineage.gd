extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Founding=preload("res://tests/test_founding.gd")
const Daughter=preload("res://tests/test_daughter_pile.gd")
const Root=preload("res://src/core/game_root.gd")
const SITE=Founding.SITE

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func daughter_game(imported: bool=false) -> SimulationController:
	var game: SimulationController=Founding.new().fixture()
	if imported: assert(game.start_adaptation("home","lean"));game.advance(360)
	assert(game.start_founding(SITE))
	for tick: int in 2000:
		game.advance(0.25)
		if game.run.founding.phase=="ready": break
	assert(game.establish_daughter(SITE))
	var pile: PileState=game.run.colony.piles.satellite_1
	for id: String in PileState.RESOURCE_IDS: pile.deposit_resource(id,2000)
	assert(game.start_nursery_development("satellite_1"));game.advance(90)
	assert(game.start_food_exchange("satellite_1"));game.advance(60)
	pile.midden.generated_units=400000;pile.midden.isolated_units=400000;pile.midden.revealed=true
	assert(game.set_sanitation_workers("satellite_1",2));assert(game.set_humidity_workers("satellite_1",1))
	return game
func mature_daughter() -> SimulationController:
	var game: SimulationController=daughter_game()
	for group: int in 4:
		assert(game.start_brood("satellite_1"));game.advance(360)
	assert(game.run.colony.piles.satellite_1.brood_matured_total==32)
	return game

func run(test: Object) -> bool:
	_check_imports(test);_check_generation(test);_check_old_trial(test);_check_migration(test);_check_ui(test)
	return true

func _check_imports(test: Object) -> void:
	var game: SimulationController=daughter_game(true);var pile: PileState=game.run.colony.piles.satellite_1
	test.check(pile.genetics.count_trait("lean")>0 and pile.offspring_traits().is_empty(),"Imported workers retain useful expression without rewriting their queen's offspring")
	test.check(pile.queen.generation==1 and pile.queen.parent_identity==game.run.founding.reproductive_group.parent_queen_id,"First funded daughter preserves its captured maternal ancestry")
	var imported_root:=Root.new();imported_root.simulation=game
	var imported_status: Dictionary=imported_root.inward_status("satellite_1")
	test.check(not imported_status.adaptation_options.lean.inherited and AdaptationWeb.trait_state(imported_status,"lean").begins_with("Available"),"Imported adult expression does not masquerade as a purchased maternal lineage in the web")
	imported_root.free()
	game.start_brood("satellite_1");var old: BroodCohort=pile.brood_cohorts[0]
	test.check(old.inherited_traits.is_empty() and old.parent_queen_id==pile.queen.queen_id(pile.id),"Ordinary brood captures the actual baseline mother, despite adapted immigrants")
	test.check(game.queue_adaptation("satellite_1","lean"),"An imported adult trait can still fund a distinct maternal trial")
	game.advance(0.25);var trial: BroodCohort=pile.trial_cohort()
	test.check(trial!=null and trial.inherited_traits==["lean"] and old.inherited_traits.is_empty(),"Paid daughter trial captures its own bundle while earlier brood stays fixed")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Imported expression and the independent maternal trial restore together")
	game.advance(360);twin.advance(360)
	test.check(game.run.to_dict()==twin.run.to_dict() and pile.offspring_traits()==["lean"],"Supported trial emergence establishes only the local maternal lineage with exact continuation")
	test.check(game.start_brood("satellite_1") and pile.brood_cohorts[0].inherited_traits==["lean"],"Future offspring inherit the mother's funded change")
	var root:=Root.new();root.simulation=game
	test.check(root.inward_status("satellite_1").adaptation_options.lean.inherited,"Web distinguishes the established maternal choice from earlier immigrant carriers")
	root.free()

func _check_generation(test: Object) -> void:
	var game: SimulationController=mature_daughter();var pile: PileState=game.run.colony.piles.satellite_1
	test.check(game.set_brood_intent("satellite_1","grow") and game.queue_reproduction("satellite_1",true),"Mature daughter can queue reproductive investment while Auto Brood stays on")
	game.advance(0.25);var group: ReproductionState=pile.reproduction
	test.check(group.phase=="egg" and group.parent_queen_id==pile.queen.queen_id(pile.id) and group.parent_generation==1,"Daughter-funded reproductive laying captures its current maternal identity")
	var saved: Dictionary=snapshot(game);var twin:=Controller.new();test.check(twin.restore_snapshot(saved),"Independent daughter's paid group and Auto Brood restore")
	game.advance(800);twin.advance(800)
	test.check(game.run.to_dict()==twin.run.to_dict() and group.phase=="ready","Daughter raises an actual ready group with exact continuation")
	pile.queen.condition=100;pile.resources.protein=0;game.advance(0.25);pile.deposit_resource("protein",1000)
	test.check(pile.queen_count==0 and game.replace_queen("satellite_1"),"Daughter's funded young queen offers a real queenless recovery")
	var captured: String=group.parent_queen_id;game.advance(120)
	test.check(pile.queen_count==1 and pile.queen.generation==2 and pile.queen.parent_identity==captured and pile.reproduction.phase=="none","One daughter-funded group becomes a second-generation successor without duplicated stock")
	test.check(pile.brood_intent=="grow" and pile.queen.queen_id(pile.id)!=captured,"Existing growth intent continues under the new local queen")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();copy.restore_snapshot(saved);copy.set_time_scale(scale);copy.advance(16.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Daughter lineage/investment is identical at %dx" % scale)

func _check_old_trial(test: Object) -> void:
	var game: SimulationController=mature_daughter();var pile: PileState=game.run.colony.piles.satellite_1
	game.start_reproduction("satellite_1");game.advance(780)
	game.queue_adaptation("satellite_1","lean");game.advance(0.25)
	var old_mother: String=pile.trial_cohort().parent_queen_id
	pile.queen.condition=100;pile.resources.protein=0;game.advance(0.25);pile.deposit_resource("protein",1000)
	game.replace_queen("satellite_1");game.advance(120)
	test.check(pile.queen.queen_id(pile.id)!=old_mother and pile.offspring_traits().is_empty(),"Replacement inherits the earlier paid group's bundle rather than an unfinished trial")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Historical maternal trial remains valid under a different successor")
	game.advance(241);twin.advance(241)
	test.check(game.run.to_dict()==twin.run.to_dict() and pile.genetics.count_trait("lean")==8 and pile.offspring_traits().is_empty(),"Old paid trial produces real carriers without rewriting a successor mother")
	test.check(game.queue_adaptation("satellite_1","lean"),"Successor may deliberately fund her own maternal adoption of the known adult trait")

func _check_migration(test: Object) -> void:
	var game: SimulationController=daughter_game(true);var saved: Dictionary=snapshot(game)
	var twin:=Controller.new();test.check(twin.restore_snapshot(saved),"Captured founding lineage restores")
	for mode: String in ["version","bundle","parent","generation","clone"]:
		var bad: Dictionary=saved.duplicate(true)
		match mode:
			"version":bad.colony.piles[1].queen.lineage_version=2
			"bundle":bad.colony.piles[1].queen.inherited_traits=["unknown"]
			"parent":bad.colony.piles[0].queen.identity=[]
			"generation":bad.colony.piles[1].queen.generation="unknown"
			"clone":bad.colony.piles[0].reproduction=bad.founding.reproductive_group.duplicate(true)
		var before: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(bad) and twin.run.to_dict()==before,"Invalid maternal "+mode+" rejects atomically")
	var old: Dictionary=snapshot(game)
	for p: Dictionary in old.colony.piles:
		p.queen.erase("lineage_version")
		p.queen.inherited_traits=[]
		for cohort: Dictionary in p.brood_cohorts:cohort.erase("parent_queen_id");cohort.erase("parent_generation")
		p.reproduction.erase("parent_queen_id");p.reproduction.erase("parent_generation")
	test.check(twin.restore_snapshot(old) and twin.run.colony.piles.home.offspring_traits()==["lean"] and twin.run.colony.piles.satellite_1.offspring_traits().is_empty(),"Old Home proxy/founder bundles migrate explicitly without granting immigrant genes to Daughter")
	test.check(twin.run.colony.piles.home.genetics.living==game.run.colony.piles.home.genetics.living,"Lineage migration does not convert or duplicate old adults")

func _check_ui(test: Object) -> void:
	var root:=Root.new();root.simulation=daughter_game();root.inward_pile_id="satellite_1"
	var view:=InwardView.new();test.get_root().add_child(view);view.status_provider=root.focused_inward_status;view.reproduction_command=root.toggle_reproductive_queue;view.adaptation_command=root.queue_adaptation;view._process(0)
	var before: Dictionary=root.simulation.run.to_dict();view.selected_id="queen"
	test.check(view.activate_at(view._queen_tab_rect("reproduction").get_center()) and view.queen_tab=="reproduction" and root.simulation.run.to_dict()==before,"Daughter reproductive inspection is free attention")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view._reproduction_rect().get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.colony.piles.satellite_1.investments.reproduction,"Daughter touch queues real local reproductive intent before prerequisites finish")
	view.selected_id="adaptation";view.web_selection="lean";view.web_family="foraging";view._process(0)
	touch.position=view._adaptation_rect("lean").get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.colony.piles.satellite_1.queued_adaptation=="lean" and root.simulation.run.colony.piles.home.queued_adaptation=="","Daughter adaptation touch uses her maternal intent and payer")
	view.free();root.free()
