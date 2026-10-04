extends RefCounted
const Parent = preload("res://tests/test_parent_supply.gd")
const Snapshot = preload("res://tests/test_adaptation_queue.gd")
const Root = preload("res://src/core/game_root.gd")

func fixture() -> SimulationController:
	return Parent.new().fixture()
func step_until(game: SimulationController, predicate: Callable, count: int = 4000):
	for tick: int in count:
		if predicate.call(): return
		game.advance(0.25)
func run(test: Object) -> bool:
	var game := fixture()
	var home: PileState = game.run.colony.piles.home
	var daughter: PileState = game.run.colony.piles.satellite_1
	var before: Dictionary = game.run.to_dict()
	var control := SimulationController.new(); control.restore_snapshot(Snapshot.new().snapshot(game))
	var home_workers: int = home.workers_available
	var daughter_workers: int = daughter.workers_available
	test.check(game.set_daughter_supply(true,"satellite_1") and home.workers_available == home_workers and daughter.workers_available == daughter_workers-8, "Homebound supplies reserve eight actual Daughter workers, leaving Home labor unchanged")
	test.check(game.run.supply_origin == "satellite_1" and game.run.supply.phase == "none" and game.run.daughter_supply.phase == "waiting", "Reverse supply is a distinct payer history on one shared connection")
	var twin := SimulationController.new()
	test.check(twin.restore_snapshot(Snapshot.new().snapshot(game)), "Daughter-owned waiting commitment restores against the correct ledger")
	before=game.run.to_dict()
	test.check(not game.set_daughter_supply(true) and not game.reinforcement.start() and game.run.to_dict() == before, "Opposite supplies and settler traffic cannot overlap the committed connection")
	var original: Dictionary = daughter.resources.duplicate()
	var plan: Dictionary = game.daughter_supply._plan()
	game.advance(0.25); twin.advance(0.25)
	test.check(game.run.to_dict() == twin.run.to_dict() and daughter.resources.protein == original.protein-plan.costs.protein and daughter.resources.water == original.water-plan.costs.water and daughter.resources.carbohydrate < original.carbohydrate-plan.cargo.carbohydrate, "Only Daughter pays pack plus real travel food at departure")
	control.advance(game.run.simulation_time-control.run.simulation_time)
	test.check(home.resources == control.run.colony.piles.home.resources and game.run.daughter_supply.trips_reported == 0, "Departure neither deposits at Home nor fabricates a returned delivery")
	test.check(twin.restore_snapshot(Snapshot.new().snapshot(game)), "Private reverse cargo saves in physical outbound travel")
	step_until(game,func():return game.run.daughter_supply.phase=="returning")
	control.advance(game.run.simulation_time-control.run.simulation_time)
	test.check(is_equal_approx(home.resources.protein,control.run.colony.piles.home.resources.protein+plan.cargo.protein) and is_equal_approx(home.resources.water,control.run.colony.piles.home.resources.water+plan.cargo.water) and game.run.daughter_supply.trips_reported == 0, "Physical arrival adds Home stores while payer's delivery report still awaits return")
	var root := Root.new(); root.simulation=game
	test.check(root.inward_status("satellite_1").supply.trips_reported == 0 and root.inward_status("home").supply.trips_reported == 0, "Each directional report remains unknown until its payer return")
	test.check(game.set_daughter_supply(false,"satellite_1") and daughter.workers_available == daughter_workers-8, "Stopping keeps the real Daughter party committed during return")
	test.check(twin.restore_snapshot(Snapshot.new().snapshot(game)), "Stopped reverse trip round-trips")
	step_until(game,func():return game.run.daughter_supply.phase=="none")
	test.check(game.run.daughter_supply.trips_reported == 1 and daughter.workers_available == daughter_workers and game.run.supply.trips_reported == 0 and home.workers_available == home_workers, "Returning party releases to Daughter and records only its own receipt")
	var historical: Dictionary = game.run.daughter_supply.to_dict()
	test.check(game.set_daughter_supply(true) and game.run.supply_origin == "home", "Empty shared connection switches back to Home funding")
	step_until(game,func():return game.run.supply.trips_reported==1)
	game.set_daughter_supply(false)
	test.check(game.run.daughter_supply.to_dict() == historical and game.run.supply.trips_reported == 1 and twin.restore_snapshot(Snapshot.new().snapshot(game)), "Home return records never overwrite or copy Daughter history")
	test.check(game.reinforcement.start() and game.run.supply_origin == "home" and twin.restore_snapshot(Snapshot.new().snapshot(game)), "Settler traffic reuses the connection with Home history and real ownership")
	game.reinforcement.recall(); step_until(game,func():return not game.run.reinforcement.active())
	test.check(game.set_daughter_supply(true,"satellite_1") and twin.restore_snapshot(Snapshot.new().snapshot(game)), "Supplies switch after the real settler party returns")
	var saved: Dictionary = Snapshot.new().snapshot(game)
	for gate: String in ["owner","orphan","overlap","history"]:
		var bad: Dictionary = saved.duplicate(true)
		match gate:
			"owner":bad.supply_origin="home"
			"orphan":bad.erase("daughter_supply")
			"overlap":bad.supply.enabled=true;bad.supply.phase="waiting"
			"history":bad.daughter_supply.delivered_units.protein+=1
		before=twin.run.to_dict()
		test.check(not twin.restore_snapshot(bad) and twin.run.to_dict()==before,"Forged reverse supply %s rejects atomically" % gate)
	var legacy := fixture(); saved=Snapshot.new().snapshot(legacy);saved.erase("daughter_supply");saved.erase("supply_origin")
	test.check(legacy.restore_snapshot(saved) and legacy.run.daughter_supply.phase=="none" and legacy.run.supply_origin=="home", "Legacy snapshots retain Home-only supply ownership and no invented Daughter party")
	var care := fixture(); care.start_brood("satellite_1")
	test.check(care.set_daughter_supply(true,"satellite_1") and care.run.colony.piles.satellite_1.workers_available >= 2, "Homebound supply assignment preserves the Daughter's existing brood carers")
	var poor := fixture();poor.run.colony.piles.satellite_1.resources.water=0
	test.check(poor.set_daughter_supply(true,"satellite_1"), "A named Daughter supply intent can await its own food")
	poor.advance(30)
	test.check(poor.run.daughter_supply.trips_started==0 and poor.daughter_supply.summary().blocker.contains("Daughter") and poor.daughter_supply.summary().blocker.contains("water"), "Known Daughter shortage prevents departure without spending Home water")
	var tainted := fixture(); var d: PileState=tainted.run.colony.piles.satellite_1
	d.food_toxicity.mass=d.resources.carbohydrate*0.25
	tainted.set_daughter_supply(true,"satellite_1");tainted.advance(0.25)
	var mass: float=tainted.run.daughter_supply.contaminant_mass
	step_until(tainted,func():return tainted.run.daughter_supply.phase=="returning")
	test.check(mass>0 and tainted.run.colony.piles.home.food_toxicity.mass>0 and twin.restore_snapshot(Snapshot.new().snapshot(tainted)), "Actual reverse cargo carries chemical mass instead of cleansing food in transit")
	var paused := fixture();paused.set_daughter_supply(true,"satellite_1"); paused.advance(2);paused.toggle_pause();before=paused.run.to_dict();paused.advance(100)
	test.check(paused.run.to_dict()==before, "Pause freezes reverse travel and resource/report ownership")
	var expected: Dictionary = {}
	for speed: int in [1,4,16,64]:
		var timed := fixture(); timed.set_daughter_supply(true,"satellite_1"); timed.set_time_scale(speed); timed.advance(64.0/speed); timed.set_time_scale(1)
		var record: Dictionary = timed.run.to_dict()
		if expected.is_empty(): expected=record
		test.check(record==expected,"Reverse supply outcome is equal at %dx" % speed)
	var continued := fixture()
	for id: String in PileState.RESOURCE_IDS: continued.run.colony.piles.satellite_1.deposit_resource(id,100)
	continued.set_daughter_supply(true,"satellite_1");continued.advance(4)
	test.check(twin.restore_snapshot(Snapshot.new().snapshot(continued)),"Funded repeating reverse party saves in flight")
	continued.advance(240);twin.advance(240)
	test.check(continued.run.to_dict()==twin.run.to_dict() and continued.run.daughter_supply.trips_reported>1,"Repeated physical Homebound deliveries, feeding and clock history continue exactly")
	root.free();return true
