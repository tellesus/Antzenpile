extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")

func fixture() -> SimulationController:
	var game := Controller.new()
	var pile: PileState = game.run.colony.piles.home
	pile.workers.add_living_workers("available",32,"Mature fixture")
	pile.brood_matured_total=32; pile.brood_started_total=4; pile.brood_cohorts.clear()
	pile.nursery_state="developed"; pile.nursery_progress_seconds=90
	pile.food_exchange_state="developed"; pile.food_exchange_progress_seconds=60
	pile.resources={"carbohydrate":1000.0,"protein":1000.0,"water":1000.0}
	pile.midden.generated_units=400000; pile.midden.isolated_units=400000; pile.midden.revealed=true
	game.set_sanitation_workers("home",2); game.set_humidity_workers("home",1)
	return game

func run(test: Object) -> bool:
	var fresh := Controller.new()
	var before: Dictionary = fresh.run.to_dict()
	test.check(not fresh.start_reproduction("home") and fresh.run.to_dict()==before,"Reproduction waits for a mature colony without spending")
	var game := fixture()
	var pile: PileState = game.run.colony.piles.home
	for gate: String in ["space","workers","food","queen","nursery","exchange","adaptation"]:
		var blocked := fixture(); var p: PileState = blocked.run.colony.piles.home
		match gate:
			"space": blocked.start_brood("home"); blocked.start_brood("home")
			"workers": p.workers.create_commitment("test:busy","internal","home"); p.workers.allocate("test:busy",p.workers_available)
			"food": p.resources.protein=0
			"queen": p.queen_count=0
			"nursery": p.nursery_state="primitive"
			"exchange": p.food_exchange_state="primitive"
			"adaptation": blocked.queue_adaptation("home","lean")
		before=blocked.run.to_dict()
		test.check(not blocked.start_reproduction("home") and blocked.run.to_dict()==before,"Rejected reproductive "+gate+" gate is atomic")
	var available: int = pile.workers_available
	var stores: Dictionary = pile.resources.duplicate()
	test.check(game.start_reproduction("home") and pile.reproduction.phase=="egg","Funded reproductive brood starts")
	test.check(pile.workers_available==available-4 and pile.workers.count("reproduction:home")==4 and pile.nursery_occupied_space()==8,"Reproductive support reserves real nurses and Nursery space")
	test.check(pile.resources.carbohydrate==stores.carbohydrate-12 and pile.resources.protein==stores.protein-12 and pile.resources.water==stores.water-8,"Laying costs debit once")
	before=game.run.to_dict()
	test.check(not game.start_reproduction("home") and game.run.to_dict()==before,"Duplicate reproductive laying is rejected without a second cost")
	var captured := fixture(); captured.start_reproduction("home")
	captured.run.colony.piles.home.genetics.established.append("lean")
	test.check(captured.run.colony.piles.home.reproduction.inherited_traits.is_empty(),"Newly established traits cannot retrofit laid reproductive brood")
	test.check(game.start_brood("home") and pile.nursery_occupied_space()==16 and not game.start_brood("home"),"Ordinary brood uses only the remaining space")
	var worker_group: BroodCohort = pile.brood_cohorts[0]
	game.advance(1)
	test.check(worker_group.care==1 and worker_group.progress_seconds==1,"Dedicated nurses do not penalize otherwise fully cared worker brood")
	# Separate stable fixture for the whole reproductive cycle.
	game=fixture(); pile=game.run.colony.piles.home; game.start_reproduction("home")
	var copy := Controller.new()
	game.advance(180)
	test.check(pile.reproduction.phase=="larva" and pile.queen_count==1 and pile.workers_total==72,"Egg phase changes without creating adults or laying queens")
	pile.resources.protein=0
	var progress: int = pile.reproduction.progress_quarters
	var carbs: float = pile.resources.carbohydrate
	game.advance(1)
	test.check(pile.reproduction.progress_quarters==progress and pile.resources.carbohydrate==carbs and pile.reproduction.food_shortfalls==["protein"],"Unfed reproductive larvae stall with no partial food debit")
	var colony := Root.new(); colony.simulation=game
	test.check("protein" in ColonyPressure.food_shortages(colony.inward_status("home")),"Local reproductive shortage participates in existing source response")
	pile.deposit_resource("protein",100)
	var exact: bool = copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict())))
	for tick: int in 2500:
		game.advance(0.25); copy.advance(0.25)
		exact=exact and game.run.to_dict()==copy.run.to_dict()
		if pile.reproduction.phase=="ready": break
	test.check(exact and pile.reproduction.phase=="ready","Fed stages continue exactly through JSON save into ready reproductives")
	test.check(pile.workers_total==72 and pile.queen_count==1 and pile.workers.count("reproduction:home")<0 and pile.nursery_occupied_space()==0,"Mature group releases nurses/immature space once without worker births or extra active queens")
	var summary: Dictionary = game.reproduction.summary("home")
	test.check(summary.ready_queens==1 and summary.ready_males==2,"Prepared young queen and supporting males remain separately counted")
	available=pile.workers_available; game.advance(10)
	test.check(pile.workers_available==available and pile.workers.invariant_holds(),"Ready group cannot release nurses twice")
	var saved: Dictionary = game.run.to_dict()
	for bad_kind: String in ["phase","progress","traits","nurses","future","premature"]:
		var bad: Dictionary = saved.duplicate(true)
		var p: Dictionary = bad.colony.piles[0]
		match bad_kind:
			"phase": p.reproduction.phase="fertile"
			"progress": p.reproduction.progress_quarters=1
			"traits": p.reproduction.inherited_traits=["lean"]
			"nurses": p.workers.commitments["reproduction:home"]={"kind":"internal","owner_id":"home","count":4}
			"future": p.reproduction.laid_tick=int(bad.clock.ticks)+1
			"premature": p.reproduction.laid_tick=int(bad.clock.ticks)-1
		before=copy.run.to_dict()
		test.check(not copy.restore_snapshot(bad) and copy.run.to_dict()==before,"Malformed reproductive "+bad_kind+" restore rejects atomically")
	var old := Controller.new().run.to_dict(); old.colony.piles[0].erase("reproduction")
	test.check(copy.restore_snapshot(old) and copy.run.colony.piles.home.reproduction.phase=="none","Old saves default to no reproductive group")
	var live := fixture(); live.start_reproduction("home"); live.advance(200)
	test.check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(live.run.to_dict()))),"Active larval group and its nurse job restore")
	old=live.run.to_dict(); old.colony.piles[0].erase("reproduction")
	before=copy.run.to_dict()
	test.check(not copy.restore_snapshot(old) and copy.run.to_dict()==before,"Missing group cannot orphan reproductive nurses in a forged old save")
	var scale_result: Dictionary = {}
	var live_save: Dictionary = live.run.to_dict()
	for scale: int in [1,4,16,64]:
		var speed_game := Controller.new(); speed_game.restore_snapshot(live_save); speed_game.set_time_scale(scale)
		speed_game.advance(16.0/scale)
		var result: Dictionary=speed_game.run.to_dict(); result.clock.scale=1
		if scale_result.is_empty(): scale_result=result
		test.check(result==scale_result,"Reproductive feeding/development is speed-independent")
	live.toggle_pause(); before=live.run.to_dict(); live.advance(100)
	test.check(live.run.to_dict()==before,"Pause freezes reproductive feeding and maturation")
	var ui := View.new(); test.get_root().add_child(ui); ui.selected_id="queen"; ui._status=colony.inward_status("home")
	before=game.run.to_dict()
	test.check(ui.activate_at(ui._queen_tab_rect("reproduction").get_center()) and ui.queen_tab=="reproduction" and game.run.to_dict()==before,"Reproductive tab is independent free attention")
	test.check(ui.activate_at(ui._brood_rect().get_center()) and game.run.to_dict()==before,"Ready reproductive panel cannot issue hidden worker-laying commands")
	ui.queue_free(); colony.free()
	return true
