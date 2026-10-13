extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Contact = preload("res://tests/test_rival_contact.gd")
const CONFIG = preload("res://data/ecology/backyard_rival.tres")

func fixture(losses: int=4) -> SimulationController:
	var game:=Controller.new(3048)
	assert(game.dispatch_scout("home",0.0))
	game.advance(800.0)
	assert(game.create_trail("home","known:carb_exposed"))
	assert(game.set_trail_workers("route_1",0))
	assert(game.run.rival.workers.remove_living_workers("rival:trail",losses,"Fixture junction attrition"))
	game.run.swarm.rival_losses=losses
	game.run.swarm.phase="finished";game.run.swarm.serial=1;game.run.swarm.route_id="route_1"
	game.run.swarm.last_finish_tick=game.run.clock.tick_count
	game.run.rival.cargo=minf(game.run.rival.cargo,game.run.rival.workers.count("rival:trail"))
	return game

func run(test: Object) -> bool:
	var game:=fixture()
	var rival: RivalState=game.run.rival
	var original_food: float=rival.stored_carbohydrate
	var original_available: int=rival.workers.available
	game.advance(0.25)
	test.check(rival.workers.count("rival:trail")==2 and rival.workers.total==26, "No casualty replacement appears on the traveling junction party")
	test.check(rival.continuity.brood_count==4 and rival.continuity.remaining_ticks==600 and rival.stored_carbohydrate==original_food-8 and rival.workers.available==original_available-2 and rival.workers.count("rival:brood")==2, "Missing workers fund one delayed group with actual food and unavailable carers")
	var funded: Dictionary=Contact.new().snapshot(game)
	var copy:=Controller.new()
	test.check(copy.restore_snapshot(funded) and copy.run.to_dict()==game.run.to_dict(), "Paid rival brood and original casualties restore exactly")
	var rested: bool=false
	for tick: int in 600:
		var returning: bool=rival.direction=="inbound" and rival.remaining_ticks==1
		game.advance(0.25);copy.advance(0.25)
		if rival.direction=="resting" and not rested:
			rested=true;test.check(returning,"A routed remnant reaches home before beginning its withdrawal interval")
		if tick==598:
			test.check(rival.workers.total==26 and rival.continuity.remaining_ticks==1,"Paid workers stay immature until the full development time")
			var last:=Controller.new();test.check(last.restore_snapshot(Contact.new().snapshot(game)),"Near-emergence rival saves validate")
	test.check(rested and rival.workers.total==30 and rival.continuity.emerged_total==4 and rival.workers.count("rival:brood")==-1 and rival.continuity.brood_count==0,"Actual emergence restores the bounded population and releases carers once")
	test.check(game.run.to_dict()==copy.run.to_dict() and rival.workers.total+rival.workers.lost_total==30+rival.continuity.emerged_total and rival.workers.invariant_holds(),"Repeated forage and emergence conserve exact saved continuation")
	test.check(copy.restore_snapshot(Contact.new().snapshot(game)),"Post-emergence identity and spent-food totals restore")
	game.advance(150.0)
	test.check(rival.workers.total==30 and rival.continuity.emerged_total==4 and rival.direction!="resting" and rival.workers.count("rival:trail")==6,"A full neighboring colony restarts from home after its withdrawal interval without exceeding its population ceiling")
	var partial:=fixture(2)
	for tick: int in 220:
		var home_arrival: bool=partial.run.rival.direction=="inbound" and partial.run.rival.remaining_ticks==1
		partial.advance(0.25)
		if partial.run.rival.workers.count("rival:trail")==6:
			test.check(home_arrival,"A reduced viable party refills from living reserves only at physical home arrival");break
	var hungry:=fixture();hungry.run.rival.stored_carbohydrate=0;hungry.advance(0.25)
	test.check(hungry.run.rival.continuity.brood_count==0 and hungry.run.rival.workers.count("rival:brood")==-1,"Unfunded brood is not a free regeneration timer")
	var depleted:=fixture()
	assert(depleted.run.rival.workers.remove_living_workers("available",24,"Fixture exhausted reserves"));depleted.run.swarm.rival_losses=28
	for tick: int in 200:
		depleted.advance(0.25)
		if depleted.run.rival.direction=="resting":break
	test.check(depleted.run.rival.direction=="resting" and depleted.run.rival.workers.count("rival:trail")==-1 and depleted.run.rival.workers.total==2,"A depleted remnant actually returns and rests rather than attacking indefinitely")
	test.check(copy.restore_snapshot(Contact.new().snapshot(depleted)),"Resting rival ledger saves without a ghost trail pool")
	depleted.advance(0.25)
	test.check(depleted.run.rival.continuity.brood_count==4 and depleted.run.rival.workers.available==0,"A surviving remnant can invest real carers and food before restarting")
	depleted.advance(150.0)
	test.check(depleted.run.rival.workers.total==6 and depleted.run.rival.direction=="outbound" and depleted.run.rival.workers.count("rival:trail")==6,"New adults restore actual local labor and depart from home")
	var extinct:=fixture(6)
	assert(extinct.run.rival.workers.remove_living_workers("available",24,"Fixture no living ants"));extinct.run.swarm.rival_losses=30
	extinct.advance(200.0)
	test.check(extinct.run.rival.workers.total==0 and extinct.run.rival.continuity.emerged_total==0 and extinct.run.rival.direction=="resting","A rival without living carers cannot revive from stores alone")
	var legacy: Dictionary=Contact.new().snapshot(fixture())
	legacy.rival.erase("continuity")
	test.check(copy.restore_snapshot(legacy) and not copy.run.rival.continuity.enabled,"Absent old-save continuity retains the finite original population")
	copy.advance(200.0)
	test.check(copy.run.rival.workers.total==26 and copy.run.rival.workers.count("rival:trail")==2,"Old attrition does not gain invisible replacements or reserve refill")
	for speed: int in [1,4,16,64]:
		var twin:=Controller.new();assert(twin.restore_snapshot(funded));twin.set_time_scale(speed)
		twin.advance(150.0/speed);twin.set_time_scale(1)
		var ordinary:=Controller.new();assert(ordinary.restore_snapshot(funded));ordinary.advance(150.0)
		test.check(twin.run.to_dict()==ordinary.run.to_dict(),"Paid rival continuation matches speed "+str(speed))
	copy.restore_snapshot(funded);copy.toggle_pause();var paused: Dictionary=copy.run.to_dict();copy.advance(150)
	test.check(copy.run.to_dict()==paused,"Pause freezes funded brood, reserves and physical travel")
	for field: String in ["enabled","food","date","pool","count","births","direction"]:
		var bad: Dictionary=funded.duplicate(true)
		match field:
			"enabled":bad.rival.continuity.enabled=false
			"food":bad.rival.continuity.replacement_spent=0
			"date":bad.rival.continuity.funded_tick+=1
			"pool":bad.rival.workers.commitments["rival:brood"].owner_id="player"
			"count":bad.rival.continuity.brood_count=5
			"births":bad.rival.continuity.emerged_total=4
			"direction":bad.rival.direction="resting"
		var fresh:=Controller.new();var before: Dictionary=fresh.run.to_dict()
		test.check(not fresh.restore_snapshot(bad) and fresh.run.to_dict()==before,"Corrupt rival continuity rejects atomically: "+field)
	var root:=preload("res://src/core/game_root.gd").new();root.simulation=game
	var known: Dictionary=root.outward_status("home")
	test.check(not known.has("rival") and not known.has("continuity") and not known.has("replacement_spent"),"Rival economics remain private rather than becoming live player numbers")
	root.free()
	_test_repeat(test)
	return true

func _test_repeat(test: Object) -> void:
	var game: SimulationController=preload("res://tests/test_rival_counterplay.gd").new().ready_game()
	var route: TrailRouteState=game.run.trails.routes.route_1
	for tick: int in 2400:
		game.advance(0.25)
		if route.conflict_report=="secured":break
	test.check(route.conflict_report=="secured","An ordinary prepared retry secures an actual junction")
	var root:=preload("res://src/core/game_root.gd").new();root.simulation=game
	var known: Dictionary=root.outward_status("home")
	var records: Array[Dictionary]=preload("res://src/presentation/outward/conflict_popover.gd").new()._history_records(root.trail_summaries("home")[0],known)
	test.check(records.any(func(record: Dictionary)->bool:return record.lines.has("Encounter ended · later traffic remains uncertain")),"Dated victory history distinguishes an ended encounter from permanent safety")
	root.free()
	var serial: int=game.run.swarm.serial;var delivered: float=route.delivered_total
	var copy:=Controller.new();test.check(copy.restore_snapshot(Contact.new().snapshot(game)),"Actual victory with paid replacement brood saves")
	game.advance(180);copy.advance(180)
	test.check(game.run.swarm.serial==serial and route.delivered_total>delivered,"Winning gives a useful gathering interval before new reserve traffic")
	for tick: int in 1600:
		game.advance(0.25);copy.advance(0.25)
		if route.conflict_serial>serial:break
	test.check(route.conflict_serial>serial and game.run.rival.continuity.emerged_total>0 and game.run.to_dict()==copy.run.to_dict(),"Paid emergence and home departure can cause a fresh physically returned encounter, with exact continuation")
	assert(game.set_trail_workers(route.id,0))
	for tick: int in 2000:
		game.advance(0.25)
		if route.allocated_workers==0:break
	serial=game.run.swarm.serial;game.advance(200)
	test.check(route.allocated_workers==0 and game.run.swarm.serial==serial,"Deliberate avoidance stops new conflict despite the neighbor's independent recovery")
