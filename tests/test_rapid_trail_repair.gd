extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Fixture=preload("res://tests/test_reproduction.gd")
const Root=preload("res://src/core/game_root.gd")
const TRAILS=preload("res://data/trails/default_trails.tres")

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func route_game() -> SimulationController:
	var game: SimulationController=Fixture.new().fixture()
	game.dispatch_scout("home",0);game.advance(100)
	assert(game.create_trail("home","known:carb_exposed"))
	return game

func experienced() -> SimulationController:
	var game: SimulationController=route_game()
	game.advance(100);game.set_trail_workers("route_1",0);game.advance(100)
	assert(game.run.colony.piles.home.repair_experience)
	game.start_brood("home");game.advance(360)
	return game

func run(test: Object) -> bool:
	_check_evidence(test);_check_deposition(test);_check_travel(test);_check_combination(test);_check_saves(test);_check_ui(test)
	return true

func _check_evidence(test: Object) -> void:
	var game: SimulationController=route_game();var pile: PileState=game.run.colony.piles.home
	var before: Dictionary=game.run.to_dict()
	test.check(not game.queue_adaptation("home","rapid_repair") and game.run.to_dict()==before,"Unobserved repair cannot be purchased")
	game.advance(0.25);var cohort: TransitCohort=game.run.trails.cohorts.values()[0]
	test.check(not cohort.repair_exposure and not pile.repair_experience,"A virgin trail is not a disrupted established corridor")
	var segment: TrailSegmentState=game.run.trails.segments.segment_1
	segment.traffic=5;segment.pheromone_strength=0.1;game.advance(0.25)
	test.check(cohort.repair_exposure and not pile.repair_experience,"Weak corridor evidence remains private while the travelers are away")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Private repair exposure restores before return")
	game.set_trail_workers("route_1",0);twin.set_trail_workers("route_1",0);game.advance(100);twin.advance(100)
	test.check(pile.repair_experience and not pile.repair_candidate and game.run.to_dict()==twin.run.to_dict(),"Living return delivers experience without instant eligibility")
	game.start_brood("home");game.advance(300)
	test.check(pile.repair_candidate and game.queue_adaptation("home","rapid_repair"),"A later supported brood reaches pupae and earns repair selection")
	var root:=Root.new();root.simulation=game
	test.check(root.inward_status("home").adaptation_options.rapid_repair.available,"Delivered experience and survival project an available leaf")
	root.free()

func _check_deposition(test: Object) -> void:
	var baseline:=TrailSegmentState.new();baseline.traffic=5;baseline.pheromone_strength=0.1
	var repair:=TrailSegmentState.new();repair.traffic=5;repair.pheromone_strength=0.1
	baseline.reinforce_chemistry(0.2,0);repair.reinforce_chemistry(0.2,0,1)
	test.check(is_equal_approx(baseline.pheromone_strength,0.3) and is_equal_approx(repair.pheromone_strength,0.4),"Repair carriers add fifty-percent stronger fresh scent on worn routes")
	test.check(baseline.route_familiarity==repair.route_familiarity and baseline.traffic==repair.traffic,"Replacement deposition cannot create familiarity or traffic")
	baseline.pheromone_strength=0.6;repair.pheromone_strength=0.6
	baseline.reinforce_chemistry(0.2,0);repair.reinforce_chemistry(0.2,0,1)
	test.check(baseline.pheromone_strength==repair.pheromone_strength,"An intact corridor receives no repair bonus despite its food cost")
	baseline.traffic=0;repair.traffic=0;baseline.pheromone_strength=0;repair.pheromone_strength=0
	baseline.reinforce_chemistry(0.2,0);repair.reinforce_chemistry(0.2,0,1)
	test.check(baseline.pheromone_strength==repair.pheromone_strength,"Repair does not create a stronger virgin route")
	baseline.traffic=5;repair.traffic=5;baseline.pheromone_strength=0.1;repair.pheromone_strength=0.1
	baseline.reinforce_chemistry(0.2,0);repair.reinforce_chemistry(0.2,0,0.5)
	test.check(is_equal_approx(repair.pheromone_strength-baseline.pheromone_strength,0.05),"Mixed actual carrier share supplies only its proportional repair")
	var old: float=repair.pheromone_strength;repair.decay_chemistry(1)
	test.check(is_equal_approx(repair.pheromone_strength,old*0.5),"Repair's new ordinary scent retains the ordinary decay half-life")
	repair.pheromone_strength=0.4;repair.persistent_chemistry=0.2;repair.reinforce_chemistry(2,1,1)
	test.check(repair.pheromone_strength==1 and repair.persistent_chemistry<=1,"Persistent plus repair contributions saturate under the same scent bound")
	test.check(is_equal_approx(AdaptationRules.chemistry_food_multiplier(1,1),1.35),"Full combined chemistry food surcharges have an explicit 1.35 bound")

func _check_travel(test: Object) -> void:
	var game: SimulationController=experienced();var pile: PileState=game.run.colony.piles.home
	test.check(game.queue_adaptation("home","rapid_repair"),"Real experience can queue the paid repair trial")
	game.advance(0.25);var trial: BroodCohort=pile.trial_cohort()
	test.check(trial.inherited_traits==["rapid_repair"] and pile.genetics.count_trait("rapid_repair")==0,"Repair lays a captured trial without converting old adults")
	game.advance(360)
	test.check(pile.genetics.count_trait("rapid_repair")==8,"Only new surviving adults supply repair expression")
	game.set_trail_workers("route_1",5)
	var before: float=pile.resources.carbohydrate;game.advance(0.25)
	var cohort: TransitCohort=game.run.trails.cohorts.values()[0];var segment: TrailSegmentState=game.run.trails.segments.segment_1
	var cost: float=TRAILS.round_trip_energy_cost(5,segment.length(),segment.terrain_cost(game.run.world))*cohort.energy_multiplier*AdaptationRules.chemistry_food_multiplier(cohort.chemistry_fraction,cohort.repair_fraction)
	test.check(cohort.repair_fraction>0 and absf(before-pile.resources.carbohydrate-cost)<0.00001,"Mixed repair travelers pay their actual recurring journey carbohydrate")
	var fraction: float=cohort.repair_fraction
	test.check(pile.lose_workers("available",1,0,"Known repair loss","rapid_repair"),"A carrier loss is a single actual ledger loss")
	test.check(cohort.repair_fraction==fraction and pile.genetics.count_trait("rapid_repair")==7,"Current adult losses cannot rewrite the in-flight departure phenotype")
	var saved: Dictionary=snapshot(game);var twin:=Controller.new()
	test.check(twin.restore_snapshot(saved),"Captured repair fraction and known loss restore")
	game.set_trail_workers("route_1",0);twin.set_trail_workers("route_1",0);game.advance(100);twin.advance(100)
	test.check(game.run.to_dict()==twin.run.to_dict(),"Actual repaired return and paid cargo continue exactly")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();copy.restore_snapshot(saved);copy.set_time_scale(scale);copy.advance(16.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Repair traffic is identical at %dx" % scale)
	for mode: String in ["fraction","nan","exposure","candidate","experience"]:
		var broken: Dictionary=saved.duplicate(true)
		match mode:
			"fraction":broken.trails.cohorts[0].repair_fraction=1.1
			"nan":broken.trails.cohorts[0].repair_fraction=NAN
			"exposure":broken.trails.cohorts[0].repair_exposure="true"
			"candidate":broken.colony.piles[0].repair_candidate=false
			"experience":broken.colony.piles[0].repair_experience=false
		var unchanged: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==unchanged,"Invalid repair "+mode+" rejects atomically")

func _check_combination(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_persistent_chemistry.gd").new().candidate_game()
	var pile: PileState=game.run.colony.piles.home
	test.check(game.start_adaptation("home","persistent"),"Combined comparison first funds the earned persistent trait")
	game.advance(360)
	test.check(game.start_adaptation("home","rapid_repair"),"Repair coexists with an already established persistent lineage")
	game.advance(360);game.set_trail_workers("route_1",5)
	var before: float=pile.resources.carbohydrate;game.advance(0.25)
	var cohort: TransitCohort=game.run.trails.cohorts.values()[0];var segment: TrailSegmentState=game.run.trails.segments.segment_1
	var cost: float=TRAILS.round_trip_energy_cost(cohort.worker_count,segment.length(),segment.terrain_cost(game.run.world))*cohort.energy_multiplier*AdaptationRules.chemistry_food_multiplier(cohort.chemistry_fraction,cohort.repair_fraction)
	test.check(cohort.chemistry_fraction>0 and cohort.repair_fraction>0 and absf(before-pile.resources.carbohydrate-cost)<0.00001,"Both actual captured carrier shares pay additive chemistry food costs")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Joint persistent/repair travel restores with strict phenotype ownership")
	game.advance(30);twin.advance(30)
	test.check(game.run.to_dict()==twin.run.to_dict(),"Joint deposition mixture and cargo continue exactly")

func _check_saves(test: Object) -> void:
	var game: SimulationController=route_game();game.advance(0.25)
	var old: Dictionary=snapshot(game);var pile: Dictionary=old.colony.piles[0]
	pile.erase("repair_experience");pile.erase("repair_candidate");pile.reproduction.erase("repair_comparison")
	for cohort: Dictionary in pile.brood_cohorts:cohort.erase("repair_comparison")
	for cohort: Dictionary in old.trails.cohorts:cohort.erase("repair_fraction");cohort.erase("repair_exposure")
	var twin:=Controller.new();test.check(twin.restore_snapshot(old),"Old saves acquire no invented repair genes or private report")
	game.advance(100);twin.advance(100)
	test.check(game.run.to_dict()==twin.run.to_dict(),"Legacy traffic, costs and returns continue exactly")
	var repro: SimulationController=experienced();var p: PileState=repro.run.colony.piles.home
	p.repair_candidate=false;repro.start_reproduction("home");repro.advance(660)
	test.check(p.repair_candidate,"A supported reproductive comparison can earn repair at pupation")

func _check_ui(test: Object) -> void:
	var root:=Root.new();root.simulation=experienced()
	var view:=InwardView.new();test.get_root().add_child(view);view.status_provider=root.focused_inward_status;view.adaptation_command=root.queue_adaptation
	view.selected_id="adaptation";view.web_selection="rapid_repair";view._process(0)
	var before: Dictionary=root.simulation.run.to_dict()
	test.check("rapid_repair" in AdaptationWeb.visible_nodes(view._status,"chemistry") and AdaptationWeb.known(view._status,"rapid_repair") and root.simulation.run.to_dict()==before,"Chemistry family provides a distinct free inspection context")
	for size: Vector2 in [Vector2(1280,720),Vector2(900,600)]:
		var points: Dictionary=AdaptationWeb.positions(size)
		for id: String in AdaptationWeb.visible_nodes(view._status,"chemistry"):
			test.check(AdaptationWeb.node_at(points[id],size,view._status,"chemistry")==id,"Chemistry touch targets resolve at both supported sizes")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view._adaptation_rect("rapid_repair").get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.colony.piles.home.queued_adaptation=="rapid_repair","Chemistry touch queues a single future brood choice")
	view.free();root.free()
