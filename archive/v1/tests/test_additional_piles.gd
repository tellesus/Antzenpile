extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Maternal=preload("res://tests/test_maternal_lineage.gd")
const Root=preload("res://src/core/game_root.gd")
const ALT="known:nest_site_02"
const FOOD="known:carb_exposed"
func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func fixture() -> SimulationController:
	var game: SimulationController=Maternal.new().mature_daughter()
	var authored:=Controller.new()
	var site: WorldNodeState=authored.run.world.nodes.nest_site_02;site.position=Vector2(28,22)
	var food: WorldNodeState=authored.run.world.nodes.carb_exposed;food.position=Vector2(30,22);food.quantity=1000
	game.run.world.nodes[site.id]=site;game.run.world.nodes[food.id]=food
	assert(game.dispatch_scout("satellite_1",0))
	var agent: ScoutAgent=game.run.scouts.values()[0];var origin: Vector2=game.run.colony.piles.satellite_1.position
	agent.path=[origin]
	for x: int in range(roundi(origin.x),29):agent.path.append(Vector2(x,22))
	agent.mission_target=Vector2(28,22)
	for tick: int in 2000:
		game.advance(0.25)
		if game.run.scouts.is_empty():break
	assert(game.run.knowledge.nodes.has(ALT));assert(game.run.knowledge.nodes.has(FOOD))
	assert(game.start_reproduction("satellite_1"));game.advance(800)
	assert(game.run.colony.piles.satellite_1.reproduction.phase=="ready")
	return game
func three_piles() -> SimulationController:
	var game: SimulationController=fixture();assert(game.start_founding(ALT,"satellite_1"))
	for tick: int in 3000:
		game.advance(0.25)
		if game.run.extra_foundings.values()[0].phase=="ready":break
	assert(game.establish_daughter(ALT,"satellite_1"))
	return game
func run(test: Object) -> bool:
	_check_founding(test);_check_first_connection(test);_check_independent_work(test);_check_saves(test);_check_attention(test)
	return true
func _check_founding(test: Object) -> void:
	var game: SimulationController=fixture();var parent: PileState=game.run.colony.piles.satellite_1
	var legacy: Dictionary=game.run.founding.to_dict();var home_workers: Dictionary=game.run.colony.piles.home.workers.to_dict()
	var total: int=game.run.colony.workers_total
	test.check(game.start_founding(ALT,"satellite_1"),"A mature daughter funds her own real founding party")
	var camp: FoundingState=game.run.extra_foundings.values()[0]
	test.check(camp.origin_pile=="satellite_1" and camp.destination_pile=="satellite_2" and parent.workers.count("trail:"+camp.route_id)==12 and parent.reproduction.phase=="none","Additional party owns explicit origin/destination, real workers and one transferred group")
	test.check(game.reproduction.summary("satellite_1").phase=="departed","Daughter Queen controls name the actually departed reproductive group")
	test.check(game.run.founding.to_dict()==legacy and game.run.colony.piles.home.workers.to_dict()==home_workers,"Additional founding cannot repurpose the legacy Home connection or labor")
	var before: Dictionary=game.run.to_dict()
	test.check(not game.start_founding(ALT,"home") and not game.start_founding(ALT,"satellite_1") and game.run.to_dict()==before,"One pending site/origin commitment rejects duplicate funding atomically")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"An additional paid party restores without inventing a third pile early")
	var elapsed: int=2*camp.leg_ticks+camp.preparation_ticks
	game.advance(elapsed*0.25);twin.advance(elapsed*0.25)
	test.check(camp.phase=="ready" and game.run.to_dict()==twin.run.to_dict(),"Actual daughter-origin travel/preparation/messenger return continues exactly")
	test.check(game.establish_daughter(ALT,"satellite_1") and game.run.colony.piles.size()==3 and game.run.colony.workers_total==total,"Eleven actual settlers become the third independently owned pile")
	var child: PileState=game.run.colony.piles.satellite_2
	test.check(child.foundation.parent_id=="satellite_1" and child.queen.generation==2 and child.queen.parent_identity==camp.reproductive_group.parent_queen_id and child.workers_total==11,"Later-generation foundation preserves maternal ancestry and the authoritative transfer")
	test.check(game.run.founding.to_dict()==legacy and game.run.trails.routes[camp.route_id].status=="inactive","Original camp proof remains while the new connection awaits its transport card")
	test.check(twin.restore_snapshot(snapshot(game)),"Three-pile foundation and aggregate profile receipts restore")
	before=game.run.to_dict();test.check(not game.start_founding(ALT,"home") and game.run.to_dict()==before,"Known colony occupation cannot be founded a second time")
func _check_first_connection(test: Object) -> void:
	var game: SimulationController=fixture();var legacy_route: String=game.run.founding.route_id
	test.check(game.set_daughter_supply(true,"home"),"Original connection can fund Home supplies before another founding")
	game.advance(0.25)
	test.check(game.start_founding(ALT,"satellite_1") and game.run.supply.phase!="none","Daughter's separate camp does not steal the active Home supply route")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Concurrent first-connection supply and extra camp restore with distinct payers")
	game.set_daughter_supply(false,"home");twin.set_daughter_supply(false,"home");game.advance(100);twin.advance(100)
	test.check(game.run.to_dict()==twin.run.to_dict() and game.run.supply.trips_reported==1 and game.run.founding.route_id==legacy_route,"Original supplies physically return over their original connection during later founding")
	test.check(game.send_daughter_workers(),"Home settlers can subsequently use the freed original connection")
	game.advance(100)
	test.check(game.run.reinforcement.arrivals==1 and game.run.colony.piles.satellite_1.workers.transferred_in==19,"Old connection settlers retain their real transfer history")
	var camp: FoundingState=game.run.extra_foundings.values()[0]
	for tick: int in 3000:
		if camp.phase=="ready":break
		game.advance(0.25)
	game.establish_daughter(ALT,"satellite_1")
	test.check(twin.restore_snapshot(snapshot(game)),"Legacy settlers and new daughter-origin migration profiles reconcile across three piles")

func _check_independent_work(test: Object) -> void:
	var game: SimulationController=three_piles();var child: PileState=game.run.colony.piles.satellite_2
	for id: String in PileState.RESOURCE_IDS:child.deposit_resource(id,100)
	test.check(game.create_trail("satellite_2",FOOD,3),"Third pile can assign its own actual gatherers")
	var route: TrailRouteState=game.run.trails.find_route("satellite_2",FOOD)
	var stores: float=child.resources.carbohydrate;game.advance(100)
	test.check(route.delivered_total>0 and child.resources.carbohydrate>stores,"Third-pile physical gathering delivers to its own stores")
	game.set_trail_workers(route.id,0);game.advance(100)
	test.check(game.start_brood("satellite_2") and child.brood_cohorts[0].parent_queen_id==child.queen.queen_id(child.id),"Third pile lays captured local worker brood")
	test.check(game.set_exploration(2,"home") and game.set_exploration(2,"satellite_1") and game.set_exploration(2,"satellite_2"),"Each pile owns independent exploration effort under one shared cap")
	var before: Dictionary=game.run.to_dict()
	test.check(not game.set_exploration(5,"satellite_2") and game.run.to_dict()==before,"Aggregate exploration cap includes every pile, not just the first pair")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Three independent policies and local paid work restore")
	game.advance(16);twin.advance(16)
	test.check(game.run.to_dict()==twin.run.to_dict() and game.run.active_scout_count()<=8,"Local care/gathering/scouts preserve exact continuation and the shared detailed-agent cap")
func _check_saves(test: Object) -> void:
	var game: SimulationController=three_piles();var saved: Dictionary=snapshot(game);var twin:=Controller.new();twin.restore_snapshot(saved)
	for mode: String in ["origin","destination","receipt","foundation","policy","name","identity"]:
		var bad: Dictionary=saved.duplicate(true)
		match mode:
			"origin":bad.extra_foundings[0].origin_pile="unknown"
			"destination":bad.extra_foundings[0].destination_pile="satellite_1"
			"receipt":bad.extra_foundings[0].settler_profiles.clear()
			"foundation":bad.colony.piles[2].foundation.parent_id="home"
			"policy":bad.extra_exploration.erase("satellite_2")
			"name":bad.colony.piles[2].display_name=""
			"identity":bad.colony.piles[2].queen.identity=bad.colony.piles[1].queen.identity
		var before: Dictionary=twin.run.to_dict();test.check(not twin.restore_snapshot(bad) and twin.run.to_dict()==before,"Malformed additional-pile "+mode+" rejects atomically")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();copy.restore_snapshot(saved);copy.set_time_scale(scale);copy.advance(16.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Additional-pile work continues identically at %dx" % scale)
	var legacy: SimulationController=Maternal.new().daughter_game();var old: Dictionary=snapshot(legacy)
	old.erase("extra_foundings");old.erase("extra_exploration")
	for p: Dictionary in old.colony.piles:p.erase("display_name")
	for field: String in ["origin_pile","destination_pile","settler_profiles"]:old.founding.erase(field)
	test.check(twin.restore_snapshot(old) and twin.run.colony.piles.size()==2,"Old two-pile state gets no invented additional nests or policies")
	legacy.advance(16);twin.advance(16)
	test.check(legacy.run.to_dict()==twin.run.to_dict(),"Legacy aliases and exactly recoverable founding migration receipt continue unchanged")
func _check_attention(test: Object) -> void:
	var root:=Root.new();root.simulation=three_piles()
	var before: Dictionary=root.simulation.run.to_dict()
	test.check(root.next_pile_id("home")=="satellite_1" and root.next_pile_id("satellite_1")=="satellite_2" and root.next_pile_id("satellite_2")=="home","Free attention cycles all stable named piles")
	test.check(root.inspect_pile("satellite_2") and root.focused_inward_status().pile_name=="Nest 2" and root.focused_outward_status().pile_name=="Nest 2" and root.simulation.run.to_dict()==before,"Third-pile attention consumes approved local/returned data without spending resources")
	var view:=InwardView.new();test.get_root().add_child(view);view.status_provider=root.focused_inward_status;view.pile_command=root.inspect_pile;view._process(0)
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view._pile_rect().get_center();view._unhandled_input(touch)
	test.check(root.inward_pile_id=="home" and root.simulation.run.to_dict()==before,"Shared touch path switches to the declared next pile")
	view.free();root.free()
