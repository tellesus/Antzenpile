extends RefCounted
const Fixture = preload("res://tests/test_reproduction.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))

func experienced() -> SimulationController:
	var game: SimulationController = Fixture.new().fixture()
	game.start_brood("home"); game.advance(180)
	var pile: PileState = game.run.colony.piles.home
	pile.temperature.temperature = 32000; pile.humidity.moisture = 400000
	game.advance(300.25)
	return game

func run(test: Object) -> bool:
	_check_evidence(test); _check_rates(test); _check_food(test)
	_check_saves(test); _check_reproduction(test); _check_migration(test); _check_ui(test)
	return true

func _check_evidence(test: Object) -> void:
	var game: SimulationController = Fixture.new().fixture()
	var pile: PileState = game.run.colony.piles.home
	var before: Dictionary = game.run.to_dict()
	for id: String in BroodEnvironment.TRAITS:
		test.check(not game.queue_adaptation("home",id) and game.run.to_dict()==before,"Climate choices require actual evidence without mutation")
	pile.temperature.temperature=32000; pile.humidity.moisture=400000; game.advance(0.25)
	test.check(pile.environment.seen.is_empty(),"Unoccupied climate is not brood experience")
	game.start_brood("home"); game.advance(180)
	pile.temperature.temperature=32000; pile.humidity.moisture=400000; game.advance(0.25)
	test.check(pile.environment.seen.size()==2 and pile.environment.candidates.is_empty(),"Larval strain reveals possibilities before eligibility")
	pile.environment.survived([])
	test.check(pile.environment.candidates.is_empty(),"Unexposed progression cannot supply another cohort's evidence")
	var twin:=Controller.new(); test.check(twin.restore_snapshot(snapshot(game)),"Exposed brood restores before candidate survival")
	game.advance(200); twin.advance(200)
	test.check(pile.environment.candidates==BroodEnvironment.TRAITS and game.run.to_dict()==twin.run.to_dict(),"Exposed larvae reaching pupae earn choices with exact continuation")
	for id: String in BroodEnvironment.TRAITS: test.check(game.queue_adaptation("home",id),"Earned climate choices can replace pending intent")
	test.check(pile.queued_adaptation=="moisture_resilience","Last pending selection replaces the previous choice")

func _check_rates(test: Object) -> void:
	var pile: PileState = Fixture.new().fixture().run.colony.piles.home
	var heat: Array[String]=["heat_resilience"]; var dry: Array[String]=["moisture_resilience"]
	test.check(BroodEnvironment.larval_rate(pile,[])==1 and BroodEnvironment.larval_rate(pile,heat)==0.9,"Comfortable heat lineage has a real development disadvantage")
	pile.temperature.temperature=32000
	test.check(BroodEnvironment.larval_rate(pile,[])==0.75 and BroodEnvironment.larval_rate(pile,heat)==0.875,"Heat inheritance halves moderate warm slowdown")
	pile.temperature.temperature=35000
	test.check(BroodEnvironment.larval_rate(pile,heat)==0.5,"Severe heat retains its full penalty")
	pile.temperature.temperature=26000; pile.humidity.moisture=400000
	test.check(BroodEnvironment.larval_rate(pile,dry)==0.875,"Dry inheritance halves moderate dry slowdown")
	pile.humidity.moisture=200000
	test.check(BroodEnvironment.larval_rate(pile,dry)==0.75,"Extreme dryness still slows resilient larvae")
	pile.humidity.moisture=960000
	test.check(BroodEnvironment.larval_rate(pile,dry)==0.5,"Dry adaptation grants no excessive-moisture immunity")
	pile.humidity.moisture=400000; pile.temperature.temperature=32000
	test.check(BroodEnvironment.larval_rate(pile,BroodEnvironment.TRAITS)==0.875,"Both traits remain bounded by independent pressures")
	pile.brood_health.burden=pile.brood_health.CONFIG.severe_threshold
	test.check(BroodEnvironment.larval_rate(pile,BroodEnvironment.TRAITS)==pile.brood_health.larval_rate(),"Both climate traits still suffer actual health strain")

func _check_food(test: Object) -> void:
	var game: SimulationController=Fixture.new().fixture(); var pile: PileState=game.run.colony.piles.home
	var ordinary:=BroodCohort.new(); ordinary.stage="larva"
	var enhanced:=BroodCohort.new(); enhanced.stage="larva"; enhanced.inherited_traits=["moisture_resilience"]
	var start: Dictionary=pile.resources.duplicate(); game.brood._advance(pile,ordinary,1,1)
	var baseline: Dictionary={}
	for id: String in PileState.RESOURCE_IDS: baseline[id]=start[id]-pile.resources[id]
	start=pile.resources.duplicate(); game.brood._advance(pile,enhanced,1,1)
	for id: String in PileState.RESOURCE_IDS:
		test.check(is_equal_approx(start[id]-pile.resources[id],baseline[id]*(1.2 if id=="carbohydrate" else 1.0)),"Moisture feeding changes only carbohydrate: "+id)
	var stopped: float=enhanced.progress_seconds; game.brood._advance(pile,enhanced,1,0)
	test.check(enhanced.progress_seconds==stopped,"Resilient brood still requires real carers")
	pile.resources.protein=0; start=pile.resources.duplicate(); game.brood._advance(pile,enhanced,1,1)
	test.check(enhanced.progress_seconds==stopped and pile.resources==start,"Missing nutrition stalls resilient larvae without partial payment")
	pile.resources={"carbohydrate":1000.0,"protein":1000.0,"water":1000.0}
	enhanced.inherited_traits=["efficient_nurses","fighter","moisture_resilience"]
	start=pile.resources.duplicate(); game.brood._advance(pile,enhanced,1,1)
	test.check(absf(start.carbohydrate-pile.resources.carbohydrate-baseline.carbohydrate*1.4*1.2*1.2)<0.00001,"Combined inherited carbohydrate costs remain explicit")
	pile.brood_cohorts=[enhanced]
	var reserve: Dictionary=game.brood.remaining_food_reserve(pile)
	test.check(reserve.carbohydrate/reserve.water>2,"Auto Brood reserve accounts for existing moisture larvae's extra carbohydrate")

func _check_saves(test: Object) -> void:
	var game: SimulationController=experienced(); var pile: PileState=game.run.colony.piles.home
	game.start_brood("home"); var old: BroodCohort=pile.brood_cohorts[0]; var adults: int=pile.workers_total
	game.queue_adaptation("home","heat_resilience"); game.advance(0.25)
	var paid: BroodCohort=pile.trial_cohort()
	test.check(paid!=null and paid.inherited_traits==["heat_resilience"] and old.inherited_traits.is_empty() and pile.workers_total==adults,"Paid trait does not retrofit old brood or adults")
	game.queue_adaptation("home","moisture_resilience"); var saved: Dictionary=snapshot(game)
	var twin:=Controller.new(); test.check(twin.restore_snapshot(saved),"Paid environmental trial and follow-up intent restore")
	game.advance(400); twin.advance(400)
	test.check(game.run.to_dict()==twin.run.to_dict() and pile.genetics.count_trait("heat_resilience")==8,"Surviving trait adults conserve counts with exact continuation")
	test.check(pile.trial_cohort().inherited_traits==BroodEnvironment.TRAITS,"Compatible follow-up captures newly established heat inheritance")
	for mode: String in ["seen","candidate","exposure","unknown","duplicate","remainder"]:
		var broken: Dictionary=saved.duplicate(true); var p: Dictionary=broken.colony.piles[0]
		match mode:
			"seen": p.environment.seen.clear()
			"candidate": p.environment.candidates.clear()
			"exposure": p.brood_cohorts[0].environment_exposure=["unknown"]
			"unknown": p.environment.seen.append("unknown")
			"duplicate": p.environment.seen.append(p.environment.seen[0])
			"remainder": p.reproduction.progress_remainder=20
		var before: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==before,"Invalid climate "+mode+" rejects atomically")
	var legacy: SimulationController=Fixture.new().fixture(); legacy.start_brood("home"); legacy.start_reproduction("home")
	var legacy_save: Dictionary=snapshot(legacy); var p: Dictionary=legacy_save.colony.piles[0]
	p.erase("environment"); p.brood_cohorts[0].erase("environment_exposure"); p.reproduction.erase("environment_exposure"); p.reproduction.erase("progress_remainder")
	test.check(twin.restore_snapshot(legacy_save),"Old saves acquire no invented exposure or fractional progression")
	legacy.advance(200); twin.advance(200)
	test.check(legacy.run.to_dict()==twin.run.to_dict(),"Legacy nutrition and development continue exactly")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var run:=Controller.new(); run.restore_snapshot(saved); run.set_time_scale(scale); run.advance(32.0/scale); run.set_time_scale(1)
		if expected.is_empty(): expected=run.run.to_dict()
		test.check(run.run.to_dict()==expected,"Climate queues and development match at %dx" % scale)

func _check_reproduction(test: Object) -> void:
	var game: SimulationController=experienced(); var pile: PileState=game.run.colony.piles.home
	for id: String in BroodEnvironment.TRAITS: game.queue_adaptation("home",id); game.advance(410)
	game.start_reproduction("home"); game.advance(180)
	var group: ReproductionState=pile.reproduction
	test.check(group.phase=="larva" and group.inherited_traits==BroodEnvironment.TRAITS,"Reproductives capture both established environmental traits")
	pile.temperature.temperature=26000; pile.humidity.moisture=650000
	var start: Dictionary=pile.resources.duplicate(); game.advance(0.25)
	test.check(is_equal_approx(group.progress_ticks(),0.9) and group.progress_remainder>0,"Reproductive development keeps the ten-percent cost without rounding it away")
	test.check(absf(start.carbohydrate-pile.resources.carbohydrate-8*0.015*0.25*0.9*0.75*1.2)<0.00001,"Reproductive larvae pay the moisture carbohydrate cost")
	var twin:=Controller.new(); test.check(twin.restore_snapshot(snapshot(game)),"Fractional reproductive progress restores")
	game.advance(20); twin.advance(20)
	test.check(game.run.to_dict()==twin.run.to_dict(),"Fractional reproductive continuation is exact")
	var evidence: SimulationController=Fixture.new().fixture(); evidence.start_reproduction("home"); evidence.advance(180)
	var p: PileState=evidence.run.colony.piles.home
	p.temperature.temperature=32000; p.humidity.moisture=400000; evidence.advance(0.25)
	test.check(p.environment.seen.size()==2 and p.environment.candidates.is_empty(),"Reproductive larvae supply local exposure before eligibility")
	evidence.advance(650)
	test.check(p.environment.candidates.size()==2,"Surviving reproductive progression earns environmental choices")

func _check_migration(test: Object) -> void:
	var game: SimulationController=experienced(); var source: PileState=game.run.colony.piles.home
	game.queue_adaptation("home","heat_resilience"); game.advance(410)
	var destination: PileState=Fixture.new().fixture().run.colony.piles.home
	var total: int=source.workers_total+destination.workers_total
	test.check(source.move_workers_to(destination,"available",source.workers_available),"Environmental adults migrate through the real ledger")
	test.check(destination.genetics.count_trait("heat_resilience")>0 and source.genetics.count_trait("heat_resilience")+destination.genetics.count_trait("heat_resilience")==8 and source.workers_total+destination.workers_total==total and destination.environment.seen.is_empty(),"Imported carriers conserve population without inventing local exposure")
	var copy:=PileState.new()
	test.check(copy.restore(JSON.parse_string(JSON.stringify(destination.to_dict(),"",true,true))),"Documented imported phenotype restores without false local eligibility")

func _check_ui(test: Object) -> void:
	var root:=Root.new(); root.simulation=experienced()
	var view:=InwardView.new(); test.get_root().add_child(view)
	view.status_provider=root.focused_inward_status; view.adaptation_command=root.queue_adaptation
	view.selected_id="adaptation"; view.web_family="environment"; view.web_selection="heat_resilience"; view._process(0)
	var before: Dictionary=root.simulation.run.to_dict()
	test.check(AdaptationWeb.visible_nodes(view._status,"environment")==["foraging","heat_resilience","moisture_resilience"] and root.simulation.run.to_dict()==before,"Environment family is free knowledge-derived attention")
	var touch:=InputEventScreenTouch.new(); touch.pressed=true; touch.position=view._adaptation_rect("heat_resilience").get_center(); view._unhandled_input(touch); view._process(0)
	test.check(root.simulation.run.colony.piles.home.queued_adaptation=="heat_resilience","Environment touch queues the existing single-choice owner")
	view.free(); root.free()
