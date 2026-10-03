extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Nest=preload("res://tests/test_nest_sites.gd")
const View=preload("res://src/presentation/outward/outward_view.gd")
const SITE="known:nest_site_01"
func fixture() -> SimulationController:
	var game: SimulationController=Nest.new().fixture()
	for tick: int in 1200:
		game.advance(0.25)
		if game.run.scouts.is_empty(): break
	var pile: PileState=game.run.colony.piles.home
	pile.workers.add_living_workers("available",32,"Mature fixture")
	pile.brood_matured_total=32; pile.brood_started_total=4; pile.brood_cohorts.clear()
	pile.nursery_state="developed"; pile.nursery_progress_seconds=90
	pile.food_exchange_state="developed"; pile.food_exchange_progress_seconds=60
	pile.resources={"carbohydrate":1000.0,"protein":1000.0,"water":1000.0}
	pile.midden.generated_units=400000; pile.midden.isolated_units=400000; pile.midden.revealed=true
	game.set_sanitation_workers("home",2); game.set_humidity_workers("home",1)
	game.start_reproduction("home")
	for tick: int in 5000:
		game.advance(0.25)
		if pile.reproduction.phase=="ready": break
	return game
func run(test: Object) -> bool:
	var game:=fixture(); var pile: PileState=game.run.colony.piles.home
	test.check(pile.reproduction.phase=="ready" and game.run.knowledge.nodes.has(SITE),"Fixture raised paid reproductives after a real shelter return")
	for gate: String in ["unknown","queen","labor","food","commitment"]:
		var blocked:=fixture(); var p: PileState=blocked.run.colony.piles.home
		match gate:
			"queen": p.reproduction=ReproductionState.new()
			"labor": p.workers.create_commitment("test:busy","internal","home"); p.workers.allocate("test:busy",p.workers_available)
			"food": p.resources.protein=0
			"commitment": p.workers.create_commitment("trail:route_1","trail","route_1")
		var before: Dictionary=blocked.run.to_dict()
		test.check(not blocked.start_founding("missing" if gate=="unknown" else SITE) and blocked.run.to_dict()==before,"Rejected founding "+gate+" gate is atomic")
	var stores: Dictionary=pile.resources.duplicate(); var available: int=pile.workers_available; var total: int=pile.workers_total
	var costs: Dictionary=game.founding._costs(game.run.knowledge.nodes[SITE].estimated_position)
	test.check(game.start_founding(SITE),"Remembered shelter funds a physical founding party")
	var route: TrailRouteState=game.run.trails.routes[game.run.founding.route_id]
	test.check(route.purpose=="founding" and game.run.trails.cohorts.is_empty() and pile.workers.count("trail:"+route.id)==12 and pile.workers_available==available-12,"Founding owns real shared-route workers without food cohorts")
	test.check(pile.workers_total==total and pile.queen_count==1 and pile.reproduction.phase=="none","Departure creates no worker or active queen")
	test.check(pile.resources.protein==stores.protein-costs.protein and pile.resources.water==stores.water-costs.water and is_equal_approx(pile.resources.carbohydrate,stores.carbohydrate-costs.carbohydrate),"Supplies and travel energy pay exactly once")
	var before: Dictionary=game.run.to_dict()
	test.check(not game.start_founding(SITE) and not game.set_trail_workers(route.id,0) and not game.create_trail("home",SITE) and game.run.to_dict()==before,"Duplicate/gatherer commands cannot alter founding labor or costs")
	var root:=Root.new(); root.simulation=game
	var phases: Array[String]=[]; var exact: bool=true; var private_summary: Dictionary={}; var private_ok: bool=true
	for tick: int in 1000:
		var state: FoundingState=game.run.founding
		if state.phase not in phases:
			phases.append(state.phase)
			var twin:=Controller.new()
			var restored: bool=twin.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict())))
			if not restored: print("FOUNDING restore failed phase=",state.phase)
			exact=exact and restored
			for step: int in 4:
				game.advance(0.25); twin.advance(0.25)
				if game.run.to_dict()!=twin.run.to_dict() and restored:
					for key: String in game.run.to_dict():
						if game.run.to_dict()[key]!=twin.run.to_dict()[key]: print("FOUNDING mismatch ",state.phase," ",key)
				exact=exact and game.run.to_dict()==twin.run.to_dict()
		if state.awaiting():
			var summary: Dictionary=game.founding.summary(SITE)
			summary.erase("age")
			if private_summary.is_empty(): private_summary=summary
			private_ok=private_ok and summary==private_summary and not summary.has("reported_at") and not summary.has("settlers")
		if state.phase=="ready": break
		game.advance(0.25)
	test.check(private_ok,"All physical founding phases stay private until messenger returns")
	test.check(phases.has("outbound") and phases.has("settling") and phases.has("messenger") and phases.has("ready") and exact,"Outbound, preparation, messenger and ready saves continue exactly")
	test.check(pile.workers_total==total and pile.workers_available==available-11 and route.active_workers==11 and game.run.colony.piles.size()==1,"One messenger returns; eleven settlers remain conserved in the original commitment")
	test.check(game.run.founding.reported_tick>=game.run.founding.departed_tick+2*game.run.founding.leg_ticks+480 and game.founding.summary(SITE).status=="ready","Camp report requires actual outward, preparation and home travel")
	test.check(game.run.trails.segments[route.segment_id].traffic==1 and game.run.trails.segments[route.segment_id].route_familiarity>0,"Only the physical return reinforces trail familiarity")
	for defect: String in ["missing","phase","clock","labor","purpose","leg","group"]:
		var forged: Dictionary=game.run.to_dict()
		match defect:
			"missing": forged.erase("founding")
			"phase": forged.founding.phase="none"
			"clock": forged.founding.reported_tick=int(forged.clock.ticks)+1
			"labor": forged.trails.routes[0].active_workers=10
			"purpose": forged.trails.routes[0].erase("purpose")
			"leg": forged.founding.leg_ticks+=1
			"group": forged.founding.reproductive_group.phase="egg"
		before=game.run.to_dict()
		test.check(not game.restore_snapshot(forged) and game.run.to_dict()==before,"Forged founding "+defect+" is rejected atomically")
	var failed:=fixture(); var p: PileState=failed.run.colony.piles.home
	var prior_group: Dictionary=p.reproduction.to_dict(); var prior_workers: int=p.workers_available; var prior_total: int=p.workers_total
	var prior_protein: float=p.resources.protein
	p.food_toxicity.mass=1.0
	failed.start_founding(SITE); var pack_mass: float=failed.run.founding.contaminant_mass
	failed.run.world.nodes.nest_site_01.quantity=0; failed.run.world.nodes.nest_site_01.active=false
	var stayed_private: bool=true
	while failed.run.founding.phase!="failed":
		if failed.run.founding.awaiting(): stayed_private=stayed_private and failed.founding.summary(SITE).status=="awaiting"
		failed.advance(0.25)
	test.check(stayed_private and p.workers_available==prior_workers and p.workers_total==prior_total and p.reproduction.to_dict()==prior_group,"Unusable shelter returns the real whole party and original reproductive group")
	test.check(pack_mass>0 and failed.founding.summary(SITE).status=="failed" and p.resources.protein==prior_protein,"Failed shelter refunds carried supplies, with captured contamination preserved")
	var twin:=Controller.new()
	test.check(twin.restore_snapshot(JSON.parse_string(JSON.stringify(failed.run.to_dict()))),"Failed camp restores including returned reproductives")
	p.reproduction=ReproductionState.new(); failed.start_reproduction("home")
	test.check(twin.restore_snapshot(JSON.parse_string(JSON.stringify(failed.run.to_dict()))),"Retired failure history cannot orphan a later reproductive group")
	var legacy:=Controller.new(); var old: Dictionary=legacy.run.to_dict(); old.erase("founding")
	test.check(legacy.restore_snapshot(old) and legacy.run.founding.phase=="none","Old snapshots default to no camp")
	var expected: Dictionary={}
	for speed: int in [1,4,16,64]:
		var timed:=fixture(); timed.start_founding(SITE); timed.set_time_scale(speed); timed.advance(200.0/speed)
		var saved: Dictionary=timed.run.to_dict(); saved.clock.scale=1
		if expected.is_empty(): expected=saved
		test.check(saved==expected,"Founding same simulated result at %dx" % speed)
		timed.toggle_pause(); before=timed.run.to_dict(); timed.advance(10); test.check(timed.run.to_dict()==before,"Paused founding cannot progress")
	var view:=View.new(); test.get_root().add_child(view)
	view._signals=root.sensory_snapshot("home"); view.selected_id=view._signals[0].id; view._status=root.outward_status("home")
	test.check(view._button_at(view._founding_rect().get_center())!="founding","Reported camp has no duplicate founding button")
	view.queue_free(); root.free()
	return true
