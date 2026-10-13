extends RefCounted
const Driver=preload("res://tests/scenario_run_driver.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Legacy=preload("res://tests/test_refuge_crisis.gd")
func run(test: Object) -> bool:
	_versions(test)
	var backyard: Dictionary=Driver.new().play("backyard_slice","original")
	_check_arc(test,backyard,"Backyard")
	var simple: Dictionary=Driver.new().play("garden_edge","original")
	test.check(not simple.events.has("continuity") and simple.game.run.colony.piles.home.resources.carbohydrate<1,"Original-source Garden strategy demonstrates the observed carbohydrate bottleneck")
	var garden: Dictionary=Driver.new().play("garden_edge","network",6000)
	_check_arc(test,garden,"Garden")
	test.check(garden.events.has("network") and garden.game.run.colony.piles.size()==3 and garden.game.run.colony.piles.satellite_2.queen.generation==2,"Actual producer/network strategy raises daughter reproductives and establishes a real third-generation nest")
	var edge: ConnectionTrafficState=garden.game.run.all_connections()[0]
	test.check(edge.stores.home.trips_reported>0 and edge.stores.home.delivered_total()>0,"Finite carbohydrate packets solve a real mixed-supply funding wait with paid travel")
	test.check(garden.game.run.honeydew.services.has("home") and garden.game.run.honeydew.services.home.phase=="working" and garden.game.run.honeydew.services.home.count>0,"Living attendants sustain an actual producer relationship during network growth")
	var prepared: Dictionary=Driver.new().play("roadside")
	_check_arc(test,prepared,"Roadside Refuge")
	var sheltered: Dictionary=prepared.game.run.nest_disturbance.records.get("home",{})
	test.check(not sheltered.is_empty() and sheltered.settled>0 and sheltered.queen_injury==0,"A fresh ordinary Roadside run prepares actual shelter, settles and grows a successor lineage")
	var rescued: Dictionary=Driver.new().play("roadside","rescue")
	_check_arc(test,rescued,"Roadside rescue")
	var exposed: Dictionary=rescued.game.run.nest_disturbance.records.get("home",{})
	var transport: BroodTransportState=rescued.game.run.all_connections()[0].broods.home
	test.check(rescued.rescued and not transport.manifests.is_empty() and transport.current().departed_tick<exposed.impacted and transport.current().reported_tick>0,"The new warning timing makes a real pre-impact brood departure and returned rescue available")
	test.check(rescued.game.run.colony.piles.satellite_1.brood_transferred_in>0 and exposed.queen_injury>0 and rescued.game.run.colony.piles.home.queen.condition>250000,"Rescued actual bodies and paid local mother recovery allow post-crisis growth without a Refuge")
	test.check(not rescued.game.run.colony.piles.home.chambers.complete("refuge_chamber") and sheltered.queen_injury<exposed.queen_injury,"Refuge and network rescue demonstrate distinct real preparation/recovery tradeoffs")
	for result: Dictionary in [backyard,garden,prepared,rescued]:
		var game: SimulationController=result.game
		var restored:=Controller.new()
		test.check(restored.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))) and restored.run.to_dict()==game.run.to_dict(),"Complete multi-system run saves exactly: "+game.run.scenario_id)
		for pile: PileState in game.run.colony.piles.values():test.check(pile.workers.invariant_holds(),"Complete run preserves the authoritative ledger: "+pile.id)
	return true
func _check_arc(test: Object, result: Dictionary, label: String) -> void:
	var game: SimulationController=result.game
	test.check(result.events.has_all(["growth","organs","reproductives","daughter","continuity"]) and game.run.accomplishment.generation>0,label+" reaches real growth, organs, paid reproductives, expansion and successor offspring without grants")
	test.check(result.save_ok and not game.run.history.ended and RunContinuity.snapshot(game.run).phase=="viable",label+" retains exact mid-investment continuation and voluntary ongoing play")
	print("[COMPLETE RUN] ",label," events=",result.events," final=",game.run.simulation_time," piles=",game.run.colony.piles.size())
func _versions(test: Object) -> void:
	var old: SimulationController=Legacy.new().fixture()
	var snapshot: Dictionary=Legacy.new().snapshot(old);snapshot.nest_disturbance.erase("definition_id")
	var copy:=Controller.new()
	test.check(copy.restore_snapshot(snapshot) and copy.run.nest_disturbance.definition_id=="ground_v1" and copy.run.to_dict()==old.run.to_dict(),"An existing pre-definition Roadside crisis retains its original timing and paid state")
	old.advance(100);copy.advance(100)
	test.check(old.run.to_dict()==copy.run.to_dict() and old.run.nest_disturbance.records.home.impacted==7920,"Existing-world pressure does not shift after the fresh-world balance adjustment")
	var fresh:=Controller.new(3030,"roadside")
	test.check(fresh.run.nest_disturbance.definition_id=="ground_v2" and fresh.run.nest_disturbance.phase(7200)=="dormant" and fresh.run.nest_disturbance.phase(8400)=="warning" and fresh.run.nest_disturbance.phase(9120)=="pressure","Fresh-world adjustment preserves a real warning window without a fixed run ending")
	var bad: Dictionary=Legacy.new().snapshot(old);bad.nest_disturbance.definition_id="invented"
	var before: Dictionary=fresh.run.to_dict()
	test.check(not fresh.restore_snapshot(bad) and fresh.run.to_dict()==before,"Unknown crisis definition rejects atomically")
