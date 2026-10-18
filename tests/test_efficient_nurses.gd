extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Fixture=preload("res://tests/test_reproduction.gd")
const Root=preload("res://src/core/game_root.gd")
func snapshot(game: SimulationController) -> Dictionary: return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func experienced() -> SimulationController:
	var game: SimulationController=Fixture.new().fixture()
	game.start_brood("home");game.start_brood("home");game.advance(360)
	return game
func run(test: Object) -> bool:
	var game: SimulationController=Fixture.new().fixture();var pile: PileState=game.run.colony.piles.home
	var before: Dictionary=game.run.to_dict()
	test.check(not game.queue_adaptation("home","efficient_nurses") and game.run.to_dict()==before,"Unobserved care adaptation cannot be purchased from hidden knowledge")
	game.start_brood("home");game.start_brood("home");game.advance(0.25)
	test.check(pile.care_pressure_seen and not pile.care_candidate,"Actual demanding care workload reveals experience without inventing inherited workers")
	var root:=Root.new();root.simulation=game
	test.check(root.inward_status("home").adaptation_options.has("efficient_nurses") and not root.inward_status("home").adaptation_options.efficient_nurses.available,"Care family explains the remaining supported-emergence requirement")
	game.advance(359.75)
	test.check(pile.care_candidate and game.queue_adaptation("home","efficient_nurses"),"Supported emergence permits the actual queued care trial")
	var adults: int=pile.workers_total;game.advance(0.25)
	test.check(pile.trial_cohort().inherited_traits==["efficient_nurses"] and pile.genetics.count_trait("efficient_nurses")==0 and pile.workers_total==adults,"Laying captures the trait without converting existing adult workers")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Care evidence and paid nurses/trial restore atomically")
	game.advance(360);twin.advance(360)
	test.check(pile.genetics.count_trait("efficient_nurses")==8 and pile.workers_total==adults+8 and game.run.to_dict()==twin.run.to_dict(),"Only surviving new adults express Efficient Nurses with exact continuation")
	var saved: Dictionary=snapshot(game)
	for field: String in ["care_pressure_seen","care_candidate"]:
		var broken: Dictionary=saved.duplicate(true);broken.colony.piles[0][field]=false;before=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==before,"Forged care eligibility cannot restore an established trait")
	var old: Dictionary=snapshot(Fixture.new().fixture());old.colony.piles[0].erase("care_pressure_seen");old.colony.piles[0].erase("care_candidate")
	test.check(twin.restore_snapshot(old) and not twin.run.colony.piles.home.care_candidate,"Old piles acquire no invented care evidence or trait")
	_check_care(test);_check_food(test);_check_ui(test)
	root.free();return true
func _check_care(test: Object) -> void:
	var pile:=PileState.new();pile.workers.add_living_workers("available",32,"Controlled emerged adults")
	pile.nursery_state="developed";pile.brood_cohorts.append(BroodCohort.new());pile.brood_cohorts.append(BroodCohort.new())
	test.check(pile.brood_care_workers_required()==4,"Sixteen dependents require four baseline carers")
	pile.genetics.established=["efficient_nurses"];pile.genetics.living={"efficient_nurses":16}
	test.check(pile.brood_care_workers_required()==4 and is_equal_approx(pile.care_multiplier(),1.25),"Mixed carriers improve throughput with conservative whole-carer rounding")
	pile.genetics.living.efficient_nurses=32
	test.check(pile.brood_care_workers_required()==3 and pile.care_multiplier()==1.5,"Full expression provides useful one-worker relief for a supported full Nursery")
	pile.workers.create_commitment("test:busy","internal","test")
	test.check(pile.allocate_workers("test:busy",29) and pile.nursery_care_capacity()==16 and not pile.allocate_workers("test:busy",1),"Care-protected allocation retains three real carers with no free extra labor")
	pile.workers.allocate("test:busy",3)
	test.check(pile.nursery_care_capacity()==0,"Even full Efficient Nurses cannot care with zero actual carers")
func _check_food(test: Object) -> void:
	var enhanced: SimulationController=experienced();enhanced.queue_adaptation("home","efficient_nurses");enhanced.advance(360.25)
	var baseline: SimulationController=Fixture.new().fixture()
	var p: PileState=enhanced.run.colony.piles.home;var b: PileState=baseline.run.colony.piles.home
	enhanced.start_brood("home");baseline.start_brood("home")
	var egg_seconds: float=preload("res://data/resources/default_brood.tres").egg_seconds
	enhanced.advance(egg_seconds);baseline.advance(egg_seconds)
	var before: float=p.resources.protein;var ordinary: float=b.resources.protein
	enhanced.advance(1);baseline.advance(1)
	test.check(is_equal_approx((before-p.resources.protein)/(ordinary-b.resources.protein),1.2),"Inheriting larvae pay the actual twenty-percent recurring nutrition tradeoff")
	var expected: Dictionary={};var saved: Dictionary=snapshot(enhanced)
	for scale: int in [1,4,16,64]:
		var game:=Controller.new();game.restore_snapshot(saved);game.set_time_scale(scale);game.advance(16.0/scale);game.set_time_scale(1)
		if expected.is_empty(): expected=game.run.to_dict()
		test.check(game.run.to_dict()==expected,"Care expression/feeding is identical at %dx" % scale)
func _check_ui(test: Object) -> void:
	var root:=Root.new();root.simulation=experienced()
	var view:=InwardView.new();test.get_root().add_child(view);view.status_provider=root.focused_inward_status;view.adaptation_command=root.queue_adaptation;view.selected_id="adaptation";view.web_selection="efficient_nurses";view._process(0)
	var before: Dictionary=root.simulation.run.to_dict()
	test.check(AdaptationWeb.visible_nodes(view._status,"care").has("efficient_nurses") and root.simulation.run.to_dict()==before,"Care family is free knowledge-derived attention")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view._adaptation_rect("efficient_nurses").get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.colony.piles.home.queued_adaptation=="efficient_nurses" and root.simulation.run.colony.piles.home.trial_cohort()==null,"Care leaf touch queues the existing paid-brood owner without instant conversion")
	view.free();root.free()
