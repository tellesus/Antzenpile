extends RefCounted
## Ordinary-command ecology scenario; truth is used only for assertions and metrics.

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Snapshot = preload("res://tests/test_guest.gd")
var events: Array[String] = []
var final_snapshot: Dictionary = {}


func _until(game: SimulationController, condition: Callable, seconds: float) -> bool:
	for tick: int in roundi(seconds / 0.25):
		if condition.call():
			return true
		game.advance(0.25)
	return condition.call()


func _event(game: SimulationController, description: String) -> void:
	events.append("%.2fs %s" % [game.run.simulation_time, description])


func run(test: Object) -> bool:
	events.clear()
	final_snapshot.clear()
	var game := Controller.new(3030)
	var root := Root.new()
	root.simulation = game
	var pile: PileState = game.run.colony.piles.home
	for bearing: float in [0.0, PI]:
		test.check(game.dispatch_scout("home", bearing), "Combined review sends an ordinary scout")
	test.check(_until(game, func() -> bool: return game.run.knowledge.nodes.has_all(["known:carb_exposed", "known:carb_sheltered"]), 150.0), "First carbohydrate reports guide subsequent exploration")
	for bearing: float in [PI / 4.0, -PI / 3.0, 2.0]:
		test.check(game.dispatch_scout("home", bearing), "Combined review sends a new-source scout")
	var ready: Callable = func() -> bool: return game.run.knowledge.nodes.has_all(["known:carb_exposed", "known:carb_sheltered", "known:aphid_01", "known:water_01", "known:protein_01"])
	var discovered: bool = _until(game, ready, 150.0)
	if not discovered:
		for bearing: float in [-0.7, -1.1]:
			test.check(game.dispatch_scout("home", bearing), "Player widens exploration when water remains unknown")
		discovered = _until(game, ready, 150.0)
	if not discovered:
		for scout: int in 5:
			test.check(game.dispatch_scout("home", -0.8), "Player commits additional scouts to the unsolved search")
		discovered = _until(game, ready, 150.0)
	test.check(discovered, "Five resource reports arrive without inserted knowledge")
	if not discovered:
		print("[ECOLOGY-DISCOVERY] ", game.run.knowledge.nodes.keys(), " scouts=", game.run.scouts.keys())
		root.free()
		return false
	_event(game, "five source reports delivered")
	for knowledge: String in ["known:carb_sheltered", "known:protein_01", "known:water_01", "known:aphid_01"]:
		test.check(game.create_trail("home", knowledge), "Combined review invests in " + knowledge)
	var honeydew: TrailRouteState = game.run.trails.find_route("home", "known:aphid_01")
	test.check(_until(game, func() -> bool: return root.outward_status("home").honeydew.relationship == "exploited", 120.0), "Real loaded honeydew return enables mutualism")
	test.check(game.start_honeydew_tending("home"), "Combined review commits six producer-protection workers")
	_event(game, "six workers tending honeydew")
	test.check(_until(game, func() -> bool: return honeydew.reported_losses > 0, 400.0), "Predation reaches colony through returning traffic")
	_event(game, "honeydew mortality reported")
	test.check(game.set_trail_workers(honeydew.id, 0), "Player stops exposed honeydew traffic after a report")
	test.check(_until(game, func() -> bool: return honeydew.allocated_workers == 0, 120.0), "Predator avoidance releases travelers only on return")
	var predecessor: int = game.run.predator.kills_total
	game.advance(60.0)
	test.check(game.run.predator.kills_total == predecessor and game.run.honeydew.relationship == "tended", "Producer protection persists independently of avoiding the ambush trail")
	test.check(_until(game, func() -> bool: return pile.resources.carbohydrate >= 18 and pile.resources.protein >= 8 and pile.resources.water >= 6, 300.0), "Exterior returns fund Nursery without artificial stores")
	test.check(game.start_nursery_development("home"), "Brood capacity competes for actual resources and four workers")
	test.check(_until(game, func() -> bool: return pile.nursery_state == "developed", 100.0), "Nursery development completes alongside continuing ecology")
	_event(game, "Nursery developed")
	if game.run.simulation_time < 670.0:
		game.advance(670.0 - game.run.simulation_time)
	test.check(game.create_trail("home", "known:carb_exposed"), "Player starts a carbohydrate trail across foreign traffic")
	var crossing: TrailRouteState = game.run.trails.find_route("home", "known:carb_exposed")
	test.check(_until(game, func() -> bool: return crossing.conflict_report == "contested", 200.0), "Foreign contact escalates and courier delivers contested evidence")
	_event(game, "contested crossing reported")
	var contested: Dictionary = Snapshot.new().snapshot(game)
	var withdrawn := Controller.new()
	test.check(withdrawn.restore_snapshot(contested) and withdrawn.set_trail_workers(crossing.id, 0), "Comparison branch loads and withdraws from the same contested run")
	test.check(game.set_trail_workers(crossing.id, crossing.desired_workers + 4), "Reinforcement branch commits real reserve labor")
	for tick: int in 400:
		game.advance(0.25)
		withdrawn.advance(0.25)
	test.check(game.run.swarm.player_losses + game.run.swarm.rival_losses > withdrawn.run.swarm.player_losses + withdrawn.run.swarm.rival_losses and withdrawn.run.trails.routes[crossing.id].allocated_workers == 0, "Reinforcing and withdrawing produce different conserved combat/labor outcomes")
	print("[ECOLOGY-BRANCH] reinforced_player_losses=", game.run.swarm.player_losses, " reinforced_rival_losses=", game.run.swarm.rival_losses, " withdrawn_player_losses=", withdrawn.run.swarm.player_losses, " withdrawn_rival_losses=", withdrawn.run.swarm.rival_losses)
	_event(game, "reinforcement branch resolved; comparison withdrew")
	test.check(game.set_trail_workers(crossing.id, 0), "Resolved crossing can release further traffic")
	test.check(_until(game, func() -> bool: return crossing.allocated_workers == 0, 100.0), "Battle survivors return before subsequent growth investment")
	# Keep depleted producer memory and tenders; use normal recheck when another source reports empty.
	for route: TrailRouteState in game.run.trails.routes.values():
		if route.status == "depleted":
			game.recheck_trail(route.id)
	test.check(_until(game, func() -> bool: return pile.brood_cohorts.is_empty() and pile.resources.carbohydrate >= 12 and pile.resources.protein >= 12 and pile.resources.water >= 6, 300.0), "Foraging reserves can fund an adaptation trial after combat")
	test.check(game.start_adaptation("home", "lean"), "Ordinary resources and nurse labor fund a trial")
	test.check(_until(game, func() -> bool: return pile.adaptation_repertoire == "lean", 400.0), "Trial survives to expression before internal guest pressure")
	_event(game, "Lean Foragers expressed")
	var laid: bool = game.start_brood("home")
	test.check(laid, "Continued growth gives the guest real brood to affect")
	test.check(_until(game, func() -> bool: return root.guest_summary("home").get("reported_losses", 0) > 0, 500.0), "New guest causes nurse-observed loss in ordinary colony growth")
	_event(game, "guest-associated nursery loss observed")
	test.check(game.start_guest_rejection(), "Rejection competes with tending and external resource labor")
	var copy := Controller.new()
	var save: Dictionary = Snapshot.new().snapshot(game)
	var loaded: bool = copy.restore_snapshot(save)
	if not loaded:
		var file := FileAccess.open("res://.godot/ecology_rejected.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(save, "\t", true, true))
	test.check(loaded, "Overlapping rejection, tended producer, adapted brood, battle history and weather save")
	for tick: int in 300:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.guest.phase == "purged", "Combined ecology continues exactly through purge")
	_event(game, "guest purged; exact saved continuation")
	test.check(pile.workers.invariant_holds() and game.run.rival.workers.invariant_holds() and pile.workers_total + pile.workers.lost_total == 40 + pile.brood_matured_total, "Both ecology populations conserve founding workers and births")
	test.check(pile.brood_started_total * 8 == pile.brood_matured_total + pile.brood_lost_total + pile.nursery_occupied_space(), "Combined immature deaths and emergence conserve all started brood")
	test.check(pile.workers.count("honeydew:home") == 6 and pile.workers.count("rejection:home") == -1 and pile.workers.count("adaptation:home") == -1, "Independent labor owners retain/release only their own commitments")
	var finite_stores: bool = true
	for value: float in pile.resources.values():
		finite_stores = finite_stores and is_finite(value) and value >= 0.0
	test.check(finite_stores and game.run.trails.cohorts.size() <= game.run.trails.routes.size() * 8, "Combined traffic and stores remain bounded")
	final_snapshot = Snapshot.new().snapshot(game)
	print("[ECOLOGY-REVIEW] events=", events, " final=", game.run.simulation_time, " player_living=", pile.workers_total, " player_lost=", pile.workers.lost_total, " rival_lost=", game.run.rival.workers.lost_total, " brood_lost=", pile.brood_lost_total, " stores=", pile.resources, " available=", pile.workers_available)
	root.free()
	return true
