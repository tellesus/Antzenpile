extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Food=preload("res://tests/test_mixed_food.gd")
const Root=preload("res://src/core/game_root.gd")
const EPISODE=preload("res://data/ecology/picnic_crumbs.tres")
func snapshot(game: SimulationController) -> Dictionary: return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func fixture() -> SimulationController:
	var game:=Controller.new(482817,"roadside")
	game.set_exploration(5)
	for tick: int in 2400:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:seed_01"): break
	game.set_exploration(0)
	for tick: int in 1200:
		game.advance(0.25)
		if game.run.scouts.is_empty(): break
	for id: String in PileState.RESOURCE_IDS: game.run.colony.piles.home.deposit_resource(id,500)
	return game
func run(test: Object) -> bool:
	var game:=fixture();var seed: WorldNodeState=game.run.world.nodes.seed_01
	test.check(seed.source_type=="cracked_seeds" and game.run.knowledge.nodes.has("known:seed_01"),"Roadside has a discoverable finite seed source")
	test.check(game.create_trail("home","known:seed_01",5),"Seeds use an ordinary chosen gathering target")
	var route: TrailRouteState=game.run.trails.find_route("home","known:seed_01")
	var cargo: TransitCohort=Food.new().collected(game,route.id)
	if cargo==null: test.check(false,"Actual seed harvest");return false
	test.check(cargo.cargo_bulk==1.5 and cargo.payload==3.33333 and cargo.outputs()=={"carbohydrate":1.33333,"protein":2.0},"Five carriers handle fewer heavy seed portions with the authored mixed recipe")
	game.set_trail_workers(route.id,0)
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)) and twin.run.to_dict()==game.run.to_dict(),"Heavy fractional cargo restores exactly")
	for tick: int in 1200:
		game.advance(0.25);twin.advance(0.25)
		if route.nutrient_receipts.has("protein"): break
	test.check(route.nutrient_receipts.get("protein",{}).get("total",0)==2.0 and route.nutrient_receipts.get("carbohydrate",{}).get("total",0)==1.33333 and game.run.to_dict()==twin.run.to_dict(),"Actual seed return credits both outputs once with exact continuation")
	var saved: Dictionary=snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();copy.restore_snapshot(saved);copy.set_time_scale(scale);copy.advance(16.0/scale);copy.set_time_scale(1)
		if expected.is_empty(): expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Mixed dry food remains identical at %dx" % scale)
	# Existing physical episode owner supplies and expires the crumbs; names do not predict it.
	game=Controller.new(482817,"roadside")
	var crumbs: WorldNodeState=game.run.world.nodes[EPISODE.source_id]
	test.check(not crumbs.active and crumbs.quantity==0 and crumbs.source_type=="picnic_crumbs" and crumbs.definition_id=="carbohydrate","Crumb blueprint has a concrete type but begins physically absent")
	game.advance(EPISODE.first_tick*0.25)
	test.check(crumbs.active and crumbs.quantity==EPISODE.quantity,"Existing picnic schedule creates actual finite crumb portions")
	for id: String in PileState.RESOURCE_IDS: game.run.colony.piles.home.deposit_resource(id,500)
	game.dispatch_source_scout("home","known:"+EPISODE.source_id) if game.run.knowledge.nodes.has("known:"+EPISODE.source_id) else game.dispatch_scout("home",(crumbs.position-game.run.colony.piles.home.position).angle())
	for tick: int in 1000:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:"+EPISODE.source_id) and game.run.scouts.is_empty(): break
	test.check(game.run.knowledge.nodes.has("known:"+EPISODE.source_id) and game.create_trail("home","known:"+EPISODE.source_id,3),"A returned picnic memory supports real temporary-food gathering")
	route=game.run.trails.find_route("home","known:"+EPISODE.source_id)
	cargo=Food.new().collected(game,route.id)
	if cargo==null: test.check(false,"Actual crumb harvest");return false
	test.check(cargo.cargo_yields=={"carbohydrate":0.8,"protein":0.2} and cargo.cargo_bulk==1,"Crumbs reuse captured mixed-food rules with easier handling")
	game.set_trail_workers(route.id,0)
	var captured: Dictionary=cargo.outputs()
	for tick: int in 1200:
		game.advance(0.25)
		if route.nutrient_receipts.has("protein"): break
	test.check(route.nutrient_receipts.get("protein",{}).get("total",0)==captured.protein and route.nutrient_receipts.get("carbohydrate",{}).get("total",0)==captured.carbohydrate,"Episodic mixed intake deposits directly into both uncapped stores")
	var until_expiry: float=(EPISODE.first_tick+EPISODE.duration_ticks)*0.25-game.run.simulation_time
	if until_expiry>0: game.advance(until_expiry)
	test.check(not crumbs.active and crumbs.quantity==0,"Picnic expiry changes reality without renewing finite seed stock")
	_check_fuel(test)
	return true
func _check_fuel(test: Object) -> void:
	var game:=fixture();var known: KnownNode=game.run.knowledge.nodes["known:seed_01"]
	# A returned long journey makes its real carrying/fuel tradeoff explicit.
	known.estimated_position=Vector2(39,39)
	for region: Dictionary in game.run.world.terrain: region.movement_cost=4.0
	game.create_trail("home",known.id,5)
	var route: TrailRouteState=game.run.trails.find_route("home",known.id)
	var pile: PileState=game.run.colony.piles.home;pile.resources.carbohydrate=0
	# It is valid to know the sampled kind; no live source stock is consulted.
	known.source_type="cracked_seeds"
	game.advance(0.25)
	test.check(route.energy_limited and route.active_workers==0 and pile.resources.carbohydrate==0,"Known heavy/low-carbohydrate food cannot promise more travel fuel than its carrying capacity")
