extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Driver=preload("res://tests/scenario_run_driver.gd")
const Legacy=preload("res://tests/test_connection_residue.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func run(test: Object) -> bool:
	var old: SimulationController=Legacy.new().fixture()
	var old_data: Dictionary=snapshot(old);old_data.connection_residue.erase("definition_id")
	var copy:=Controller.new()
	test.check(copy.restore_snapshot(old_data) and copy.run.connection_residue.definition_id=="link_v1" and copy.run.to_dict()==old.run.to_dict(),"Existing enabled connection worlds retain their original definition exactly")
	var result: Dictionary=Driver.new().play("roadside")
	var game: SimulationController=result.game
	var link: ConnectionTrafficState=game.run.all_connections()[0]
	var supply: InterpileSupplyState=link.supplies.home
	var sender: PileState=game.run.colony.piles.home
	var receiver: PileState=game.run.colony.piles.satellite_1
	var cue: Dictionary=game.connection_summaries("home")[0].residue_report
	test.check(game.run.connection_residue.definition_id=="link_v2" and result.events.has("continuity") and not cue.is_empty(),"A fresh ordinary reported Roadside network can encounter and return actual late cargo pressure")
	test.check(cue.observed_at>=2250 and cue.received_at>cue.observed_at and not cue.has("definition_id") and not JSON.stringify(game.connection_summaries("home")).contains("link_v2"),"Normal returned evidence keeps dates and strips private version/timetable information")
	var prior_trips: int=supply.trips_reported
	var paid_at_close: bool=supply.travelling()
	test.check(game.connection_order(link.route_id,"home","close").accepted and not supply.enabled,"Returned suspect traffic permits deliberate closure")
	while supply.phase!="none":game.advance(0.25)
	test.check(not paid_at_close or supply.trips_reported>prior_trips,"Closing after a cue preserves any already paid real delivery and return")
	test.check(copy.restore_snapshot(snapshot(game)) and copy.run.to_dict()==game.run.to_dict(),"Fresh late cue, closed edge and local chemical intake save exactly")
	test.check(game.connection_order(link.route_id,"home","open").accepted and game.connection_order(link.route_id,"home","rescue_stores",6,"carbohydrate").accepted,"A deliberate finite packet fits the actual carrying capacity and pays a real crew")
	var state: StoreTransportState=link.stores.home
	var prior_cue: Dictionary=game.connection_summaries("home")[0].residue_report
	# A player-visible departure age drives the prudent recall, not hidden contact.
	game.advance(20)
	test.check(state.residue.contact.active() and state.residue.definition_id=="link_v2" and state.contaminant_mass>0 and game.connection_summaries("home")[0].residue_report==prior_cue,"Actual new private packet contact does not prematurely update the payer's known cue")
	var private_data: Dictionary=snapshot(game)
	test.check(copy.restore_snapshot(private_data) and copy.run.to_dict()==game.run.to_dict(),"Fresh-version private finite cargo and original chemistry restore exactly")
	var source_mass: float=sender.food_toxicity.mass
	test.check(game.connection_order(link.route_id,"home","recall_stores").accepted and game.connection_order(link.route_id,"home","close").accepted,"Changed traffic intent requests real finite recall and stops new dispatch")
	assert(copy.connection_order(link.route_id,"home","recall_stores").accepted);assert(copy.connection_order(link.route_id,"home","close").accepted)
	while state.active():game.advance(0.25);copy.advance(0.25)
	test.check(state.current().arrived==0 and state.current().reported>0 and state.delivered_units.carbohydrate==0 and sender.food_toxicity.mass>source_mass,"Recalled suspect stock returns to its actual sender without a recipient duplicate or toxin refund")
	test.check(copy.run.to_dict()==game.run.to_dict() and copy.restore_snapshot(snapshot(game)) and copy.run.to_dict()==game.run.to_dict(),"Completed late-version contaminated recall continues and restores exactly with its manifest")
	var mass: float=receiver.food_toxicity.mass
	game.set_trail_workers(game.run.trails.find_route("satellite_1","known:carb_exposed").id,0)
	test.check(game.create_trail("satellite_1","known:aphid_01"),"A closed daughter can deliberately invest in a locally reachable remembered alternative")
	var route: TrailRouteState=game.run.trails.find_route("satellite_1","known:aphid_01")
	game.set_trail_workers(route.id,3);game.advance(180)
	test.check(route.delivered_total>0 and receiver.food_toxicity.mass<mass and RunContinuity.snapshot(game.run).phase=="viable","Actual healthy local returns support gradual recovery and lineage continuity under closure")
	for field: String in ["world","cargo","manifest","receipt"]:
		var bad: Dictionary=private_data.duplicate(true)
		match field:
			"world":bad.connection_residue.definition_id="link_v1"
			"cargo":bad.connection_traffic[link.route_id].stores.home.residue.definition_id="link_v1"
			"manifest":bad.connection_traffic[link.route_id].stores.home.manifests.back().residue.definition_id="invented"
			"receipt":
				if link.legacy:bad.supply.last_residue_report.definition_id="link_v1"
				else:bad.connection_traffic[link.route_id].supplies.home.last_residue_report.definition_id="link_v1"
		var fresh:=Controller.new();var before: Dictionary=fresh.run.to_dict()
		test.check(not fresh.restore_snapshot(bad) and fresh.run.to_dict()==before,"Cross-version or unknown late evidence rejects atomically: "+field)
	return true
