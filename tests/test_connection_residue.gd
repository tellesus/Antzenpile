extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Founding=preload("res://tests/test_founding.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func fixture(start_time: float=1200) -> SimulationController:
	# Mature paid lineage fixture; discovery, travel and establishment remain actual commands.
	var original: SimulationController=Founding.new().fixture()
	var authored:=Controller.new(6241,"roadside")
	original.run.world.nodes["nest_site_02"]=authored.run.world.nodes.nest_site_02
	var raw: Dictionary=snapshot(original);raw.scenario_id="roadside";raw.connection_residue={"enabled":true}
	var game:=Controller.new();assert(game.restore_snapshot(raw))
	assert(game.dispatch_scout("home",Vector2(16,-16).angle()))
	for tick: int in 2000:
		if game.run.scouts.is_empty():break
		game.advance(0.25)
	assert(game.run.knowledge.nodes.has("known:nest_site_02") and game.start_founding("known:nest_site_02"))
	for tick: int in 3000:
		if game.run.founding.phase=="ready":break
		game.advance(0.25)
	assert(game.establish_daughter("known:nest_site_02"))
	game.advance(maxf(0,start_time-game.run.simulation_time))
	for id: String in PileState.RESOURCE_IDS:game.run.colony.piles.home.deposit_resource(id,200)
	return game

func run(test: Object) -> bool:
	var game:=fixture();var root:=Root.new();root.simulation=game
	var link: ConnectionTrafficState=game.run.all_connections()[0]
	var sender: PileState=game.run.colony.piles.home;var receiver: PileState=game.run.colony.piles.satellite_1
	var total: int=game.run.colony.workers_total
	test.check(game.connection_order(link.route_id,"home","supply").accepted,"Source funds actual care-protected adjacent supply labor")
	for tick: int in 1000:
		if game.run.supply.residue.contact.active():break
		game.advance(0.25)
	var private_save: Dictionary=snapshot(game)
	test.check(game.run.supply.residue.exposed and game.run.supply.contaminant_mass>0 and receiver.food_toxicity.mass==0,"Actual outbound contact coats paid cargo before recipient intake")
	test.check(game.connection_summaries("home")[0].residue_report.is_empty() and game.connection_summaries("satellite_1")[0].residue_report.is_empty(),"Neither endpoint gets a source receipt from private contact")
	var twin:=Controller.new();test.check(twin.restore_snapshot(private_save) and twin.run.to_dict()==game.run.to_dict(),"Private supply residue restores exactly")
	test.check(game.connection_order(link.route_id,"home","close").accepted and not game.run.supply.enabled and game.run.supply.travelling(),"Closure stops future intent while the paid party keeps travelling")
	while game.run.supply.phase!="none":game.advance(0.25)
	test.check(receiver.food_toxicity.mass>0 and game.run.supply.trips_reported==1 and game.run.colony.workers_total==total,"Committed cargo arrives once despite closure and workers physically return")
	test.check(not game.connection_summaries("home")[0].residue_report.is_empty() and game.connection_summaries("satellite_1")[0].residue_report.is_empty(),"Only actual returning sender receives the dated link witness")
	test.check(twin.restore_snapshot(snapshot(game)),"Closed connection, actual local chemistry and returned cue restore")
	game.connection_order(link.route_id,"home","open")
	test.check(game.connection_order(link.route_id,"satellite_1","supply").accepted,"Reverse supplies use the other pile's own food/workers")
	game.advance(0.25);game.connection_order(link.route_id,"satellite_1","stop_supply")
	while link.supplies.satellite_1.phase!="none":game.advance(0.25)
	test.check(not game.connection_summaries("satellite_1")[0].residue_report.is_empty() and twin.restore_snapshot(snapshot(game)),"Reverse witness/chemistry belongs to its actual payer and restores")
	var payers: Array[String]=[]
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="link_ground":payers.append(entry.pile_id)
	test.check("home" in payers and "satellite_1" in payers and payers.size()==2,"Journal coalescing preserves two payer histories on one link")
	var store_game:=fixture();var store_link: ConnectionTrafficState=store_game.run.all_connections()[0]
	test.check(store_game.connection_order(store_link.route_id,"home","rescue_stores",8,"carbohydrate").accepted,"Finite store pack uses ordinary real carriers/payment")
	var state: StoreTransportState=store_link.stores.home
	for tick: int in 1000:
		if state.residue.contact.active():break
		store_game.advance(0.25)
	var store_private: Dictionary=snapshot(store_game)
	test.check(state.residue.exposed and state.contaminant_mass==2 and twin.restore_snapshot(store_private),"Finite manifest captures original and actual once-added residue")
	test.check(store_game.connection_order(store_link.route_id,"home","recall_stores").accepted,"Unarrived finite cargo accepts real recall")
	while state.active():store_game.advance(0.25)
	test.check(state.current().arrived==0 and state.current().reported>0 and store_game.run.colony.piles.home.food_toxicity.mass>0 and store_game.run.colony.piles.satellite_1.food_toxicity.mass==0,"Recalled suspect cargo returns to sender without a recipient duplicate")
	test.check(twin.restore_snapshot(snapshot(store_game)),"Completed contaminated recall and historical manifest restore")
	var empty:=fixture(1180);var empty_link: ConnectionTrafficState=empty.run.all_connections()[0]
	test.check(empty.connection_order(empty_link.route_id,"home","rescue_stores",8,"carbohydrate").accepted,"Pre-exposure dispatch crosses before the footprint becomes active")
	var empty_state: StoreTransportState=empty_link.stores.home
	for tick: int in 1000:
		if empty_state.residue.contact.active():break
		empty.advance(0.25)
	test.check(empty_state.phase=="returning" and empty_state.current().arrived>0 and not empty_state.residue.exposed and empty_state.contaminant_mass==0,"An empty return witness cannot contaminate food already delivered")
	test.check(twin.restore_snapshot(snapshot(empty)),"Empty returning witness and delivered packet restore")
	while empty_state.active():empty.advance(0.25)
	test.check(not empty_state.last_residue_report.is_empty() and empty.run.colony.piles.satellite_1.food_toxicity.mass==0,"Empty carriers deliver an honest ground cue with no retroactive recipient toxin")
	for speed: int in [1,4,16,64]:
		var paced:=Controller.new();var reference:=Controller.new();paced.restore_snapshot(store_private);reference.restore_snapshot(store_private)
		paced.set_time_scale(speed);paced.advance(50.0/speed);paced.set_time_scale(1);reference.advance(50)
		test.check(paced.run.to_dict()==reference.run.to_dict(),"Cargo contact/actual return matches fixed ticks at "+str(speed))
	store_game.toggle_pause();var frozen: Dictionary=store_game.run.to_dict();store_game.advance(100)
	test.check(store_game.run.to_dict()==frozen,"Pause freezes both footprint and committed cargo")
	for field: String in ["disabled","dose","contact","course","future","orphan","unexposed","extra_manifest"]:
		var invalid: Dictionary=store_private.duplicate(true)
		var party: Dictionary=invalid.connection_traffic[store_link.route_id].stores.home
		match field:
			"disabled":invalid.connection_residue.enabled=false
			"dose":party.contaminant_mass=3;party.manifests[0].contaminant=3
			"contact":party.residue.contact.position=[0,0]
			"course":party.residue.contact.position=[28,13.4];party.manifests[0].residue.contact.position=[28,13.4]
			"future":party.residue.contact.observed_tick=99999
			"orphan":party.erase("last_residue_report")
			"unexposed":party.residue.exposed=false;party.manifests[0].residue.exposed=false
			"extra_manifest":party.manifests[0].erase("residue");party.manifests[0].unexpected=true
		frozen=twin.run.to_dict()
		test.check(not twin.restore_snapshot(invalid) and twin.run.to_dict()==frozen,"Malformed connection residue rejects atomically: "+field)
	var legacy: Dictionary=snapshot(fixture(1180));legacy.erase("connection_residue")
	test.check(twin.restore_snapshot(legacy) and not twin.run.connection_residue.enabled,"Older worlds gain no connection footprint")
	var journal_id: int=0
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="link_ground" and entry.pile_id=="home":journal_id=entry.id
	test.check(journal_id>0 and root.inspect_report(journal_id).accepted,"A retained dated link cue reopens actual connection controls")
	root.free();return true
