extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func loss_game() -> SimulationController:
	var game:=Controller.new(3043,"garden_edge")
	game.dispatch_scout("home",Vector2(11,-2).angle())
	for tick: int in 3000:
		if game.run.knowledge.nodes.has("known:carb_exposed"): break
		game.advance(0.25)
	game.advance(maxf(0,300-game.run.simulation_time))
	assert(game.create_trail("home","known:carb_exposed"))
	for tick: int in 4000:
		if game.run.trails.routes.route_1.reported_losses>0:break
		game.advance(0.25)
	assert(game.run.trails.routes.route_1.reported_losses>0)
	game.set_trail_workers("route_1",0)
	while game.run.trails.routes.route_1.allocated_workers>0: game.advance(0.25)
	return game

func ready_game() -> SimulationController:
	var game:=loss_game()
	for attempt: int in 5:
		game.journey_response.investigate("route_1")
		while game.run.journey_response.active():game.advance(0.25)
		if game.run.journey_response.reports.route_1.finding=="ambush":return game
	assert(false,"Bounded normal rechecks should witness this authored hunter")
	return game

func run(test: Object) -> bool:
	var patrol:=Controller.new(3043,"garden_edge")
	test.check(patrol.run.predator.profile_id=="beetle_hunter" and patrol.run.predator.motion.phase=="waiting", "New Garden Edge selects the bounded beetle profile")
	patrol.advance(300)
	var initial: Dictionary=snapshot(patrol)
	patrol.advance(10)
	test.check(patrol.run.predator.position()!=Vector2(24,18) and patrol.run.predator.position().distance_to(Vector2(24,18))<=5.001,"Actual patrol moves continuously at its authored speed")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(patrol)) and twin.run.to_dict()==patrol.run.to_dict(),"Moving position/progress restores exactly")
	patrol.advance(20);twin.advance(20)
	test.check(patrol.run.to_dict()==twin.run.to_dict() and patrol.run.predator.motion.phase=="paused","Seeded endpoint pause continues identically after save")
	patrol.advance(60)
	test.check(patrol.run.predator.motion.phase=="paused" and patrol.run.predator.motion.pause_total>0,"Hunter can return and pause by actual active food")
	var config: PredatorDefinition=patrol.run.predator.definition()
	var point: Vector2=patrol.run.predator.position()
	test.check(patrol.predator.crosses(point+Vector2(-5,0),point+Vector2(5,0)) and not patrol.predator.crosses(Vector2.ZERO,Vector2.ONE),"Swept real crossings include the actual hunter and exclude distant ground")
	patrol.toggle_pause();var frozen: Dictionary=patrol.run.to_dict();patrol.advance(100)
	test.check(patrol.run.to_dict()==frozen,"Pause freezes patrol, feeding pause and seeded decisions")
	for speed: int in [1,4,16,64]:
		var paced:=Controller.new();var reference:=Controller.new();paced.restore_snapshot(initial);reference.restore_snapshot(initial)
		paced.set_time_scale(speed);paced.advance(80.0/speed);paced.set_time_scale(1);reference.advance(80)
		test.check(paced.run.to_dict()==reference.run.to_dict(),"Patrol/pause matches fixed ticks at "+str(speed))
	var game:=loss_game();var root:=Root.new();root.simulation=game
	test.check(game.run.predator.kills_total==1 and game.run.colony.piles.home.workers.lost_total>=1,"An actual moving encounter debits real trail workers and returns its loss")
	game.journey_response.investigate("route_1")
	while game.run.journey_response.active():game.advance(0.25)
	test.check(game.run.journey_response.reports.route_1.finding=="inconclusive","A moved hunter can leave a paid survey inconclusive")
	game.journey_response.investigate("route_1")
	for tick: int in 1000:
		if game.run.journey_response.predator_profile!="":break
		game.advance(0.25)
	test.check(game.run.journey_response.predator_profile=="beetle_hunter" and root.outward_status("home").journey_response.reports.route_1.finding=="inconclusive","Close beetle outline stays private until the recheck returns")
	test.check(twin.restore_snapshot(snapshot(game)),"Private beetle survey restores through travel")
	while game.run.journey_response.active():game.advance(0.25)
	var report: Dictionary=game.run.journey_response.reports.route_1.duplicate(true)
	var senses: Array[Dictionary]=root.sensory_snapshot("home")
	test.check(report.predator_profile=="beetle_hunter" and report.has("estimated_position"),"Returning survey publishes supported outline and dated coarse course")
	test.check(senses.filter(func(item: Dictionary)->bool:return item.id=="threat:route_1")[0].get("predator_profile", "")=="beetle_hunter", "Cloud receives beetle anatomy only from the delivered report")
	game.advance(10)
	test.check(game.run.journey_response.reports.route_1==report and root.sensory_snapshot("home").filter(func(item: Dictionary)->bool:return item.id=="threat:route_1")[0].bearing==senses.filter(func(item: Dictionary)->bool:return item.id=="threat:route_1")[0].bearing,"Remembered sighting stays in place while actual hunter moves")
	var departed_position: Vector2=game.run.predator.position()
	test.check(game.journey_response.defend("route_1",24) and game.run.predator.position()==departed_position,"A paid force command cannot relocate the predator")
	game.journey_response.recall()
	while game.run.journey_response.active():game.advance(0.25)
	test.check(game.run.journey_response.defense.outcomes.route_1.outcome=="withdrew" and twin.restore_snapshot(snapshot(game)),"Withdrawal returns real workers and preserves moving ownership")
	for goal: String in ["clear","hunt"]:
		var combat:=ready_game();var saved_positions: Array[Vector2]=[]
		combat.journey_response.set_goal("route_1",goal)
		for attempt: int in 3:
			combat.journey_response.defend("route_1",24)
			for tick: int in 4000:
				if not combat.run.journey_response.active():break
				combat.advance(0.25)
				if combat.run.journey_response.phase=="fighting":
					if saved_positions.is_empty():saved_positions.append(combat.run.predator.position());test.check(twin.restore_snapshot(snapshot(combat)),"Engaged moving predator saves at actual contact")
					else:test.check(combat.run.predator.position()==saved_positions[0],"Actual fighting holds the contacted creature")
			if combat.run.predator.defeated_at>0:break
			combat.journey_response.investigate("route_1")
			while combat.run.journey_response.active():combat.advance(0.25)
		test.check(combat.run.predator.defeated_at>0 and combat.run.journey_response.defense.outcomes.route_1.outcome=="secured","Actual "+goal+" settles the finite creature")
		test.check(twin.restore_snapshot(snapshot(combat)),"Returned "+goal+" result/movement/cargo restores")
		if goal=="clear":
			test.check(not combat.run.predator.killed and not combat.run.world.nodes.has("ambusher_carcass"),"Physical retreat gives no edible remains")
			combat.advance(100);twin.advance(100)
			test.check(combat.run.to_dict()==twin.run.to_dict() and combat.run.predator.motion.phase=="gone" and combat.run.predator.position()==config.retreat_position,"Cleared hunter travels into cover once and does not regenerate health")
		else:
			var corpse: WorldNodeState=combat.run.world.nodes.ambusher_carcass
			test.check(corpse.position==combat.run.predator.position() and corpse.position!=Vector2(29,27) and combat.run.predator.motion.phase=="killed","Finite carcass appears at the actual beetle kill position")
			var before: float=combat.run.colony.piles.home.resources.protein
			test.check(combat.create_trail("home","known:ambusher_carcass"),"Returned kill supports an ordinary real harvesting journey")
			combat.advance(160)
			test.check(combat.run.colony.piles.home.resources.protein>before and corpse.quantity<JourneyResponseState.CONFIG.carcass_protein,"Edible reward requires real finite harvest and delivery")
	for field: String in ["motion_missing","unknown_phase","jump","course","progress","future","unpaid_flee","fake_death"]:
		var invalid: Dictionary=initial.duplicate(true)
		match field:
			"motion_missing":invalid.predator.erase("motion")
			"unknown_phase":invalid.predator.motion.phase="teleporting"
			"jump":invalid.predator.motion.position=[1,1]
			"course":invalid.predator.motion.destination=[39,39]
			"progress":invalid.predator.motion.progress=99999
			"future":invalid.predator.motion.started_tick=99999
			"unpaid_flee":invalid.predator.motion.phase="fleeing"
			"fake_death":invalid.predator.motion.phase="killed"
		var current: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(invalid) and twin.run.to_dict()==current,"Malformed motion rejects atomically: "+field)
	var old_save: Dictionary=initial.duplicate(true);old_save.predator.erase("profile_id");old_save.predator.erase("motion")
	test.check(twin.restore_snapshot(old_save) and twin.run.predator.motion==null and twin.run.predator.profile_id=="","Old Garden Edge world retains its original generic stationary predator")
	root.free();return true
