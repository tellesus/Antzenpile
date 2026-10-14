extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Memory=preload("res://src/presentation/outward/source_memory.gd")
func snapshot(game: SimulationController) -> Dictionary: return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func fixture() -> SimulationController:
	var game:=Controller.new(482817,"garden_edge")
	game.dispatch_scout("home",0.0)
	for tick: int in 1000:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:carb_exposed") and game.run.scouts.is_empty(): break
	for id: String in PileState.RESOURCE_IDS: game.run.colony.piles.home.deposit_resource(id,500)
	return game
func collected(game: SimulationController, route_id: String) -> TransitCohort:
	for tick: int in 1600:
		game.advance(0.25)
		for cohort: TransitCohort in game.run.trails.cohorts.values():
			if cohort.route_id==route_id and cohort.direction=="inbound" and cohort.payload>0: return cohort
	return null
func run(test: Object) -> bool:
	var unseen:=Controller.new(482817,"garden_edge");var root:=Root.new();root.simulation=unseen
	test.check(unseen.run.world.nodes.carb_exposed.source_type=="ripe_fruit" and Memory.entries(root.sensory_snapshot("home"),root.outward_status("home"),"water").is_empty(),"Garden fruit exists physically without revealing its water role before evidence")
	var game:=fixture();root.simulation=game
	test.check(game.run.knowledge.nodes.has("known:carb_exposed") and game.create_trail("home","known:carb_exposed",3),"Returned Garden source can receive a real three-worker gathering order")
	var route: TrailRouteState=game.run.trails.find_route("home","known:carb_exposed")
	game.run.world.nodes.carb_exposed.properties.contaminant_fraction=0.5
	var initial: float=game.run.world.nodes.carb_exposed.quantity
	var cargo: TransitCohort=collected(game,route.id)
	test.check(cargo!=null and cargo.cargo_source_type=="ripe_fruit" and cargo.cargo_yields=={"carbohydrate":1.0,"water":0.25},"Physical harvest captures the concrete per-portion recipe")
	if cargo==null: root.free();return false
	test.check(initial-game.run.world.nodes.carb_exposed.quantity==cargo.payload and route.nutrient_receipts.is_empty() and route.delivered_total==0,"One portion withdrawal occurs before any stores or receipts are credited")
	var expected: Dictionary=cargo.outputs();var remembered: Array=Memory.entries(root.sensory_snapshot("home"),root.outward_status("home"),"carbohydrate")
	game.run.world.nodes.carb_exposed.quantity=0;game.run.world.nodes.carb_exposed.active=false
	test.check(Memory.entries(root.sensory_snapshot("home"),root.outward_status("home"),"carbohydrate")==remembered,"Private later depletion cannot update remembered fruit or intake")
	game.set_trail_workers(route.id,0)
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)) and twin.run.to_dict()==game.run.to_dict(),"Captured mixed cargo and real recall save exactly before arrival")
	var before_water: float=game.run.colony.piles.home.resources.water
	for tick: int in 1600:
		game.advance(0.25);twin.advance(0.25)
		if route.nutrient_receipts.has("water"): break
	test.check(route.nutrient_receipts.get("water",{}).get("total",0)==expected.water and route.delivered_total==expected.carbohydrate and game.run.to_dict()==twin.run.to_dict(),"The captured carbohydrate/water bundle arrives once and continues identically after load")
	test.check(game.run.colony.piles.home.resources.water>before_water and game.run.colony.piles.home.food_toxicity.mass>0 and route.allocated_workers==0,"Actual water/contamination arrive; returning workers release only at Home")
	game.advance(0.25)
	var signals: Array[Dictionary]=root.sensory_snapshot("home");var status: Dictionary=root.outward_status("home")
	var carb: Array=Memory.entries(signals,status,"carbohydrate");var water: Array=Memory.entries(signals,status,"water")
	var c: Dictionary={};var w: Dictionary={}
	for entry: Dictionary in carb:
		if entry.knowledge_id==route.destination_knowledge_id: c=entry
	for entry: Dictionary in water:
		if entry.knowledge_id==route.destination_knowledge_id: w=entry
	test.check(not c.is_empty() and not w.is_empty() and c.route_id==w.route_id and w.delivered_total==expected.water and c.delivered_total==expected.carbohydrate,"Both nutrient filters use one source/route and their own actual receipt quantities")
	var reports: Array=game.run.reports.entries.filter(func(entry: Dictionary) -> bool: return entry.kind=="intake" and entry.subject_id==route.id)
	test.check(reports.size()==2 and reports[0].detail!=reports[1].detail,"Routine carbohydrate and water intake are grouped separately rather than mislabeled together")
	var frozen: Dictionary=game.run.to_dict();var stored_water: float=route.nutrient_receipts.water.total
	game.advance(10)
	test.check(route.nutrient_receipts.water.total==stored_water and route.allocated_workers==0,"Recall cannot deposit the bundle twice or restart canceled gathering")
	var saved: Dictionary=frozen.duplicate(true)
	for issue: String in ["role","amount","future"]:
		var broken: Dictionary=saved.duplicate(true)
		match issue:
			"role": broken.trails.routes[0].nutrient_receipts={"iron":broken.trails.routes[0].nutrient_receipts.water}
			"amount": broken.trails.routes[0].nutrient_receipts.water.total=-1
			"future": broken.trails.routes[0].nutrient_receipts.water.last_at=float(broken.clock.ticks)*0.25+1
		var before: Dictionary=twin.run.to_dict();test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==before,"Malformed mixed receipt "+issue+" rejects atomically")
	var old: Dictionary=Controller.new(482817,"garden_edge").run.to_dict()
	for node: Dictionary in old.world.nodes:
		if node.id=="carb_exposed": node.erase("source_type")
	test.check(twin.restore_snapshot(old) and twin.run.world.nodes.carb_exposed.source_type=="","Old generic Garden sources do not acquire fruit/mixed nutrition from the newer scenario")
	_check_cargo(test)
	_check_daughter(test)
	root.free();return true
func _check_cargo(test: Object) -> void:
	var game:=fixture();game.run.colony.piles.home.resources.carbohydrate=0
	game.create_trail("home","known:carb_exposed",3);var route: TrailRouteState=game.run.trails.find_route("home","known:carb_exposed")
	var cargo: TransitCohort=collected(game,route.id)
	if cargo==null: test.check(false,"Bootstrap fruit collection");return
	var outputs: Dictionary=cargo.outputs()
	test.check(cargo.unpaid_energy_cost>0 and outputs.water==cargo.payload*0.25 and outputs.carbohydrate==float(String.num(maxf(0,cargo.payload-cargo.unpaid_energy_cost),5)),"Only captured carbohydrates settle travel debt; water remains its real separate yield")
	var saved: Dictionary=snapshot(game);var twin:=Controller.new()
	test.check(twin.restore_snapshot(saved),"Deferred-energy mixed cargo restores before settlement")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var run:=Controller.new();run.restore_snapshot(saved);run.set_time_scale(scale);run.advance(16.0/scale);run.set_time_scale(1)
		if expected.is_empty(): expected=run.run.to_dict()
		test.check(run.run.to_dict()==expected,"Mixed cargo settlement has identical fixed-tick results at %dx" % scale)
	for issue: String in ["type","role","zero","bulk"]:
		var broken: Dictionary=saved.duplicate(true);var item: Dictionary=broken.trails.cohorts[0]
		match issue:
			"type": item.cargo_source_type="unknown"
			"role": item.cargo_yields.iron=1
			"zero": item.cargo_yields.water=0
			"bulk": item.cargo_bulk=0
		var before: Dictionary=twin.run.to_dict();test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==before,"Invalid captured cargo "+issue+" rejects atomically")
	var cohort:=TransitCohort.new();cohort.resource_id="carbohydrate";cohort.payload=2;cohort.unpaid_energy_cost=0.5
	test.check(cohort.outputs()=={"carbohydrate":1.5},"Absent old cargo recipe preserves primary-nutrient unit settlement")
	_check_split_loss(test)
func _check_split_loss(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_swarm.gd").new().forming_fixture()
	var route: TrailRouteState=game.run.trails.routes.route_1
	var held: TransitCohort=null
	for cohort: TransitCohort in game.run.trails.cohorts.values():
		if cohort.swarm_engaged: held=cohort;break
	# Prepare legitimate returning cargo at this already formed physical junction.
	game.run.world.nodes.carb_exposed.source_type="ripe_fruit";game.run.world.nodes.carb_exposed.quantity-=4
	held.direction="inbound";held.resource_id="carbohydrate";held.payload=4;held.contaminant_mass=1;held.cargo_source_type="ripe_fruit";held.cargo_yields={"carbohydrate":1.0,"water":0.25}
	var before: Dictionary=held.outputs();var ledger: Dictionary=game.run.colony.piles.home.workers.to_dict()
	var next_id: String="cohort_%d" % game.run.trails.next_cohort_id
	test.check(game.swarm._messenger(held,route,"holding"),"A physical conflict messenger can split a mixed-food return")
	var messenger: TransitCohort=game.run.trails.cohorts[next_id]
	var left: Dictionary=held.outputs();var sent: Dictionary=messenger.outputs()
	test.check(left.carbohydrate+sent.carbohydrate==before.carbohydrate and left.water+sent.water==before.water and messenger.cargo_yields==held.cargo_yields and game.run.colony.piles.home.workers.to_dict()==ledger,"Messenger splitting preserves both nutrients, captured recipe and the original worker pool")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Split mixed-food messengers restore with real junction ownership")
	game.trails.apply_loss(held,route,"rival")
	test.check(held.payload==2 and held.outputs().water==0.5 and held.contaminant_mass<1 and game.run.colony.piles.home.workers.invariant_holds(),"Losing a carrier drops proportional portions, water and contamination without duplicating adults")
func _check_daughter(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_daughter_gathering.gd").new().fixture()
	game.run.world.nodes.carb_exposed.source_type="ripe_fruit"
	var root:=Root.new();root.simulation=game;root.inward_pile_id="satellite_1"
	test.check(root.order_gathering("known:carb_exposed",3).accepted,"Daughter can gather shared fruit using local labor")
	var route: TrailRouteState=game.run.trails.find_route("satellite_1","known:carb_exposed");var cargo: TransitCohort=collected(game,route.id)
	if cargo==null: test.check(false,"Daughter mixed collection");root.free();return
	game.set_trail_workers(route.id,0)
	for tick: int in 1600:
		game.advance(0.25)
		if route.nutrient_receipts.has("water"): break
	test.check(route.nutrient_receipts.has("water") and game.run.reports.entries.any(func(entry: Dictionary) -> bool: return entry.kind=="intake" and entry.detail=="water" and entry.pile_id=="satellite_1"),"Both yields are credited and reported only at their collecting daughter")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Daughter mixed receipts preserve exact per-pile ownership")
	root.free()
