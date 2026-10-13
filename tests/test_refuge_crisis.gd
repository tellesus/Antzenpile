extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Founding=preload("res://tests/test_founding.gd")
const View=preload("res://src/presentation/inward/inward_view.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func advance_to(game: SimulationController, target: float) -> void:
	while game.run.simulation_time<target:game.advance(minf(60,target-game.run.simulation_time))
func fixture(build: bool=true, crisis: bool=true) -> SimulationController:
	var source: SimulationController=Founding.new().fixture()
	var raw: Dictionary=snapshot(source);raw.scenario_id="roadside";raw.nest_disturbance.enabled=crisis
	var game:=Controller.new();assert(game.restore_snapshot(raw))
	if build:assert(game.chambers.order("home","refuge_chamber"));game.advance(120)
	advance_to(game,1900)
	assert(game.start_brood("home"));assert(game.start_brood("home"))
	return game
func run(test: Object) -> bool:
	var game:=fixture();var root:=Root.new();root.simulation=game
	var pile: PileState=game.run.colony.piles.home;var refuge:=RefugeSystem.new(game.run)
	test.check(pile.chambers.complete("refuge_chamber") and root.inward_status("home").nest_crisis.ongoing,"A real paid chamber and local warning supply useful preparation")
	test.check(not JSON.stringify(root.inward_status("home").nest_crisis).contains("warning_ticks") and not JSON.stringify(root.inward_status("home").nest_crisis).contains("720"),"Local warning exposes actual age/outcome, not a private timetable")
	var available: int=pile.workers_available;var food: float=pile.resources.carbohydrate
	test.check(refuge.order("home","prepare") and pile.workers_available==available-4 and is_equal_approx(pile.resources.carbohydrate,food-3),"Explicit preparation reserves real extra carers and pays food once")
	test.check(refuge.state("home").reserved_space()==17 and refuge.state("home").targets.filter(func(target: Dictionary)->bool:return target.kind=="royal").size()==1,"Royal priority fits mother, one young group and one worker cohort in shared space")
	var preparing: Dictionary=snapshot(game);var twin:=Controller.new()
	test.check(twin.restore_snapshot(preparing) and twin.run.to_dict()==game.run.to_dict(),"Funded named shelter/body references restore exactly")
	var before: Dictionary=game.run.to_dict()
	test.check(not refuge.order("home","workers") and not refuge.order("home","prepare") and game.run.to_dict()==before,"Held bodies/priority cannot be replaced without standing down")
	game.advance(20)
	test.check(refuge.state("home").phase=="ready" and twin.restore_snapshot(snapshot(game)),"Actual local preparation completes before protection")
	advance_to(game,1980)
	var result: Dictionary=game.run.nest_disturbance.records.home
	test.check(result.queen_injury==0 and result.royals==0 and result.brood>0 and pile.reproduction.phase=="ready","Royal priority preserves the real mother/young group while unprotected worker brood takes loss")
	test.check(twin.restore_snapshot(snapshot(game)),"Impact, real losses and sheltered bodies reconcile at save")
	game.advance(60)
	test.check(refuge.state("home").phase=="none" and result.settled>0 and pile.workers.count("refuge:home")==-1,"Observed settlement releases real carers and held slots")
	test.check(twin.restore_snapshot(snapshot(game)),"Settled local receipts restore")
	var worker_game:=fixture();var worker_refuge:=RefugeSystem.new(worker_game.run)
	var worker_pile: PileState=worker_game.run.colony.piles.home
	food=worker_pile.resources.carbohydrate;available=worker_pile.workers_available
	test.check(worker_refuge.order("home","workers") and worker_pile.resources.carbohydrate==food and worker_pile.workers_available==available,"Unfunded worker priority is free")
	worker_refuge.order("home","prepare");worker_game.advance(20);advance_to(worker_game,1980)
	var worker_result: Dictionary=worker_game.run.nest_disturbance.records.home
	test.check(worker_result.brood==0 and worker_result.royals==3 and worker_result.queen_injury==0 and worker_pile.reproduction.phase=="none","Worker priority shelters both worker groups, with a real young-group opportunity cost")
	test.check(twin.restore_snapshot(snapshot(worker_game)),"Whole young-group loss releases its owner without a copied body or refund")
	var unready:=fixture(false);var exposed: PileState=unready.run.colony.piles.home
	advance_to(unready,1980)
	var unprotected: Dictionary=unready.run.nest_disturbance.records.home
	test.check(unprotected.queen_injury>0 and unprotected.brood>0 and unprotected.royals==3 and exposed.queen.condition<1000000,"Unprepared local dependents suffer the supported injury/loss")
	test.check(twin.restore_snapshot(snapshot(unready)),"Unprepared loss remains ledger/brood/royal consistent")
	var condition: int=exposed.queen.condition
	test.check(unready.queens.set_care("home",2),"A surviving injured mother accepts existing paid care")
	unready.advance(60)
	test.check(exposed.queen.condition>condition and unready.run.nest_disturbance.records.home.settled>0,"Local care and surviving brood provide actual post-crisis recovery")
	var aged:=fixture();var aged_refuge:=RefugeSystem.new(aged.run)
	aged_refuge.order("home","workers");aged_refuge.order("home","prepare");aged.advance(20)
	var held: int=aged_refuge.state("home").reserved_space()
	advance_to(aged,2400)
	test.check(aged.run.colony.piles.home.brood_matured_total>32 and aged_refuge.state("home").phase=="none" and held<=17,"Sheltered named brood matures through real birth accounting and later stand-down")
	test.check(twin.restore_snapshot(snapshot(aged)),"Maturation and released historical references save without ghost dependents")
	var held_game:=fixture(true,false);var held_system:=RefugeSystem.new(held_game.run)
	held_system.order("home","workers");held_system.order("home","prepare");held_game.advance(400)
	test.check(held_system.state("home").phase=="ready" and held_game.run.colony.piles.home.brood_cohorts.is_empty() and twin.restore_snapshot(snapshot(held_game)),"Held shelter references survive actual maturation without duplicating adults or inventing more slots")
	test.check(held_game.start_brood("home") and not held_system.state("home").protects(held_game.run.colony.piles.home.brood_cohorts[0].uid("home")),"A new laid cohort does not inherit a retired protected identity")
	var rescued: SimulationController=preload("res://tests/test_connection_residue.gd").new().fixture()
	var rescue_raw: Dictionary=snapshot(rescued);rescue_raw.nest_disturbance.enabled=true
	var rescue_game:=Controller.new();test.check(rescue_game.restore_snapshot(rescue_raw),"Established real network permits the local crisis")
	advance_to(rescue_game,1900);rescue_game.start_brood("home");rescue_game.start_brood("home")
	var link: ConnectionTrafficState=rescue_game.run.all_connections()[0]
	var uid: String=rescue_game.run.colony.piles.home.brood_cohorts[0].uid("home")
	test.check(rescue_game.connection_order(link.route_id,"home","rescue_brood",8,uid).accepted,"Local warning leaves a real staged brood rescue response")
	advance_to(rescue_game,1980)
	test.check(rescue_game.run.colony.piles.satellite_1.brood_cohorts.any(func(cohort: BroodCohort)->bool:return cohort.uid("satellite_1")==uid) and not rescue_game.run.nest_disturbance.records.has("satellite_1") and rescue_game.run.nest_disturbance.records.home.brood>0,"Paid departure/arrival preserves evacuated brood outside the affected footprint while local brood remains exposed")
	test.check(twin.restore_snapshot(snapshot(rescue_game)),"Crisis plus actual transported ancestry/care/cargo restores")
	var cover_source: SimulationController=Founding.new().fixture()
	var cover_raw: Dictionary=snapshot(cover_source);cover_raw.scenario_id="roadside";cover_raw.nest_disturbance.enabled=true
	var cover:=Controller.new();cover.restore_snapshot(cover_raw);cover.start_founding(Founding.SITE)
	for tick: int in 2000:
		if cover.run.founding.phase=="ready":break
		cover.advance(0.25)
	cover.establish_daughter(Founding.SITE)
	for resource: String in PileState.RESOURCE_IDS:cover.run.colony.piles.satellite_1.deposit_resource(resource,1000)
	advance_to(cover,1980)
	test.check(cover.run.nest_disturbance.records.satellite_1.queen_injury<cover.run.nest_disturbance.records.home.queen_injury and twin.restore_snapshot(snapshot(cover)),"Actual returned site cover softens supported exposure at a separately owned nearby nest")
	for speed: int in [1,4,16,64]:
		var paced:=Controller.new();var reference:=Controller.new();paced.restore_snapshot(preparing);reference.restore_snapshot(preparing)
		paced.set_time_scale(speed);paced.advance(150.0/speed);paced.set_time_scale(1);reference.advance(150)
		test.check(paced.run.to_dict()==reference.run.to_dict(),"Preparation/impact/settlement matches fixed ticks at "+str(speed))
	game.toggle_pause();before=game.run.to_dict();game.advance(100)
	test.check(game.run.to_dict()==before,"Pause freezes local crisis and shelter")
	for field: String in ["unknown_body","capacity","progress","pool","future_warning","false_loss","disabled"]:
		var invalid: Dictionary=preparing.duplicate(true)
		match field:
			"unknown_body":invalid.refuges.home.targets[0].uid="queen:absent:founder"
			"capacity":invalid.refuges.home.targets.append({"kind":"brood","uid":"home:brood_4","space":8})
			"progress":invalid.refuges.home.progress_ticks=81
			"pool":invalid.refuges.erase("home")
			"future_warning":invalid.nest_disturbance.records.home.warned=99999
			"false_loss":invalid.nest_disturbance.records.home.brood=1
			"disabled":invalid.nest_disturbance.enabled=false
		before=twin.run.to_dict()
		test.check(not twin.restore_snapshot(invalid) and twin.run.to_dict()==before,"Malformed shelter/crisis rejects atomically: "+field)
	var old: Dictionary=snapshot(Founding.new().fixture());old.scenario_id="roadside";old.erase("nest_disturbance");old.erase("refuges")
	test.check(twin.restore_snapshot(old) and not twin.run.nest_disturbance.enabled,"Older worlds gain no crisis or funded refuge")
	var view:=View.new();test.get_root().add_child(view);root._inward_view=view
	view.status_provider=root.focused_inward_status;view.refuge_command=root.order_refuge;view._process(0)
	for pointer: String in ["mouse","touch"]:
		view.refuge_controls.opened=false;view.activate_at(view.refuge_controls.button().get_center())
		test.check(view.refuge_controls.opened,"Free shelter inspection uses shared "+pointer+" activation")
		view.activate_at(view.refuge_controls.rect(view.get_viewport_rect().size,"back").get_center())
	test.check(View.node_at(View.positions(Vector2(1280,720)).refuge,Vector2(1280,720),false,false,false,false,true)=="refuge","Completed chamber has an actual selectable network branch")
	view.free();root.free();return true
