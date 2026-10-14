extends RefCounted
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Rival = preload("res://tests/test_rival_counterplay.gd")

func run(test: Object) -> bool:
	var game: SimulationController = Defense.new().ready_game()
	var baseline: Dictionary = Defense.new().snapshot(game)
	var route: TrailRouteState = game.run.trails.routes.route_1
	var pile: PileState = game.run.colony.piles.home
	test.check(game.set_trail_workers(route.id,5), "Recruitment fixture restarts ordinary gathering on the alerted trail")
	for i: int in 40:
		game.advance(0.25)
		if route.active_workers>=3: break
	test.check(route.active_workers>=3, "Alerted trail has real travelers before its response order")
	var free: int = pile.workers_assignable
	var initial: int = route.allocated_workers + game.run.trails.pending_losses(route.id)
	var lineage: int = pile.workers_total + pile.workers.lost_total - pile.brood_matured_total
	test.check(game.journey_response.set_force(route.id,13), "A thirteen-worker response is a legal flexible commitment")
	var known: Dictionary = game.journey_response.summary().recruitment[route.id]
	test.check(route.desired_workers==0 and not game.run.journey_response.active() and known.returning>0, "Order draws the alerted trail first and waits for its actual travelers")
	test.check(pile.workers_assignable==free-(13-initial), "Only the remainder is reserved from free nest workers")
	var frozen: Dictionary = game.run.to_dict()
	test.check(not game.set_trail_workers(route.id,5) and game.run.to_dict()==frozen, "A recalled recruitment source cannot silently restart before its order is canceled")
	var twin := Controller.new()
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Partially assembled response restores its local reservations and recalls")
	for i: int in 800:
		game.advance(0.25); twin.advance(0.25)
		if i%40==0: test.check(game.run.to_dict()==twin.run.to_dict() and pile.workers.invariant_holds(), "Recruitment and real recalled travel continue exactly")
		if game.run.journey_response.active(): break
	test.check(game.run.journey_response.active() and game.run.journey_response.defense.sent==13 and route.active_workers==0, "Full party leaves only after the alerted trail's physical return")
	test.check(pile.workers_total+pile.workers.lost_total-pile.brood_matured_total==lineage and pile.workers.invariant_holds(), "Reassignment conserves workers alongside actual births and losses")

	game=Controller.new(); game.restore_snapshot(baseline); pile=game.run.colony.piles.home
	test.check(pile.brood_care_workers_required()>0 or game.start_brood("home"), "Care test has an ordinary local cohort to protect")
	pile.midden.revealed=true
	test.check(game.sanitation.set_workers("home",4), "Care fixture assigns the existing cleanup job through its owner")
	assert(pile.workers.create_commitment("test:ongoing", "internal", "home"))
	var busy: int = pile.workers_assignable-1
	assert(pile.allocate_workers("test:ongoing",busy))
	test.check(game.journey_response.set_force("route_1",3) and not game.run.journey_response.active() and pile.midden.cleaners==4, "Ordinary order waits rather than taking workers from other jobs")
	test.check(pile.workers_available>=pile.brood_care_workers_required(), "Recruitment preserves held brood carers")
	var queued: Dictionary = Defense.new().snapshot(game)
	for gate: String in ["count","all_hands","waiting","orphan","order"]:
		var broken: Dictionary=queued.duplicate(true)
		match gate:
			"count": broken.journey_response.recruitment.route_1.count=1.5
			"all_hands": broken.journey_response.recruitment.route_1.all_hands="yes"
			"waiting": broken.journey_response.recruitment.route_1.waiting={"missing":0}
			"orphan": broken.journey_response.recruitment.erase("route_1")
			"order": broken.journey_response.orders.route_1=4
		frozen=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==frozen, "Malformed recruitment "+gate+" rejects atomically")
	test.check(game.journey_response.set_force("route_1",0) and pile.workers.count("response:route_1")==-1, "Cancel releases reserved home workers without restarting paused jobs")
	test.check(game.journey_response.set_force("route_1",3,true) and game.run.journey_response.active(), "Explicit all hands funds the same three-worker order")
	test.check(pile.midden.cleaners==2 and pile.workers.count("test:ongoing")==busy and pile.workers_available>=pile.brood_care_workers_required(), "All hands takes only needed cleanup workers through their owner and protects care/ongoing projects")
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Care-protected small all-hands party restores exactly")
	_check_other_trail(test, baseline)
	game=Rival.new().ready_game()
	route=game.run.trails.routes.route_1
	var assigned: int=route.allocated_workers+game.run.trails.pending_losses(route.id)
	test.check(game.journey_response.reinforce_gatherers(route.id,3) and route.desired_workers==assigned+3, "Foreign-ant response adds the chosen three actual/expected gatherers without recalling the alerted front")
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Flexible rival reinforcement respects saved trail/ledger ownership")

	for count: int in [1,6,7,13,23,29]:
		game=Controller.new(); game.restore_snapshot(baseline)
		test.check(game.journey_response.set_force("route_1",count) and game.run.journey_response.defense.sent==count, "Flexible initial count %d dispatches the selected headcount" % count)
		test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Flexible count %d can be saved immediately" % count)
		for i: int in 900:
			game.advance(0.25); twin.advance(0.25)
			if i%40==0: test.check(game.run.to_dict()==twin.run.to_dict(), "Arbitrary-size combat/messengers/return remain exactly saved")
			if not game.run.journey_response.active(): break
		test.check(not game.run.journey_response.active() and game.run.journey_response.orders.targets.route_1==0 and game.run.colony.piles.home.workers.invariant_holds(), "Flexible attempt ends once with conserved physical survivors and delivered results")
		if count<=game.journey_response.CONFIG.retreat_workers:
			var outcome: Dictionary=game.run.journey_response.defense.outcomes.route_1
			test.check(outcome.outcome=="withdrew" and outcome.lost==0, "Small commitment follows the existing retreat threshold and returns a real reporter")
	var root := Root.new(); root.simulation=game
	frozen=game.run.to_dict()
	var beyond_workforce: int=game.run.colony.piles.home.workers_total+game.run.pending_for_pile("home")+1
	test.check(not root.respond_to_journey("force_1.5","route_1").accepted and not root.respond_to_journey("force_%d" % beyond_workforce,"route_1").accepted and game.run.to_dict()==frozen, "Semantic commands reject fractional and impossible local commitments before changing state")
	game=Controller.new(); game.restore_snapshot(baseline); root.simulation=game
	frozen=game.run.to_dict()
	beyond_workforce=game.run.colony.piles.home.workers_total+game.run.pending_for_pile("home")+1
	test.check(not root.respond_to_journey("commit_hunt_%d" % beyond_workforce,"route_1").accepted and game.run.to_dict()==frozen, "Rejected commitment leaves its draft goal unapplied")
	root.free()
	return true

func _check_other_trail(test: Object, baseline: Dictionary) -> void:
	var game := Controller.new(); game.restore_snapshot(baseline)
	test.check(game.dispatch_scout("home",0.0), "Other-job test sends an ordinary scout toward new ground")
	for i: int in 500:
		game.advance(0.25)
		if game.run.knowledge.nodes.has("known:carb_exposed"): break
	test.check(game.create_trail("home","known:carb_exposed"), "Other-job test invests in a physically reported second source")
	var route: TrailRouteState=game.run.trails.find_route("home","known:carb_exposed")
	if route==null: return
	for i: int in 40:
		game.advance(0.25)
		if route.active_workers>=3: break
	var pile: PileState=game.run.colony.piles.home
	assert(pile.workers.create_commitment("test:ongoing","internal","home"))
	assert(pile.allocate_workers("test:ongoing",pile.workers_assignable-1))
	test.check(game.journey_response.set_force("route_1",4) and route.desired_workers==5 and not game.run.journey_response.active(), "Without all hands, an unrelated active gathering job is preserved")
	test.check(game.journey_response.set_force("route_1",4,true) and route.desired_workers==2, "All hands explicitly draws only the remaining three from another trail")
	var known: Dictionary=game.journey_response.summary().recruitment.route_1
	test.check(known.returning>0 and not game.run.journey_response.active(), "All-hands travelers also must physically return before response departure")
	var twin := Controller.new()
	test.check(twin.restore_snapshot(Defense.new().snapshot(game)), "Another trail's partial recall and recruitment reservations restore")
	for i: int in 800:
		game.advance(0.25); twin.advance(0.25)
		if i%40==0: test.check(game.run.to_dict()==twin.run.to_dict(), "Other-task physical recall continues exactly")
		if game.run.journey_response.active(): break
	test.check(game.run.journey_response.active() and game.run.journey_response.defense.sent==4 and route.desired_workers==2 and pile.workers_available>=pile.brood_care_workers_required(), "The four-worker response leaves after its other-task recruits return, retaining the uncalled workers and brood care")
