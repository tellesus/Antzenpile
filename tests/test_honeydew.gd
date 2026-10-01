extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")


func run(test: Object) -> bool:
	var game := Controller.new(3043)
	var pile: PileState = game.run.colony.piles.home
	var workers_before: int = pile.workers_total
	var snapshot: Dictionary = game.run.to_dict()
	test.check(not game.start_honeydew_tending("home") and game.run.to_dict() == snapshot, "Tending rejects before colony evidence")
	test.check(game.dispatch_scout("home", PI / 4.0), "Ordinary scout can search northeast")
	for step: int in 1000:
		if game.run.knowledge.nodes.has("known:aphid_01"):
			break
		game.advance(0.25)
	test.check(game.run.knowledge.nodes.has("known:aphid_01"), "Honeydew producers become known only after an ordinary scout returns")
	if not game.run.knowledge.nodes.has("known:aphid_01"):
		return true
	test.check(game.run.honeydew.relationship == "unknown" and not game.start_honeydew_tending("home"), "Scout discovery alone does not establish exploitation")
	test.check(game.create_trail("home", "known:aphid_01"), "Known honeydew source accepts an ordinary route")
	var route: TrailRouteState = game.run.trails.routes.route_1
	for step: int in 800:
		if route.delivered_total > 0.0:
			break
		game.advance(0.25)
	test.check(route.delivered_total > 0.0 and game.run.honeydew.relationship == "exploited", "Loaded route return establishes exploitation")
	if route.delivered_total <= 0.0:
		return true
	test.check(game.start_honeydew_tending("home") and game.run.honeydew.relationship == "tended" and pile.workers.count("honeydew:home") == 6 and pile.workers_total == workers_before, "Tending reserves six real workers without changing population")
	test.check(not game.start_honeydew_tending("home"), "Repeated tending request does not duplicate labor")
	var root := Root.new()
	root.simulation = game
	var outward: Dictionary = root.outward_status("home")
	test.check(outward.honeydew.relationship == "tended" and not outward.honeydew.has("condition") and not outward.has("world"), "Normal OUTWARD exposes known relationship without hidden producer condition")
	root.free()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Tended relationship and ledger survive full-precision save")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.honeydew.protection_workers = 5
	var before_invalid: Dictionary = copy.run.to_dict()
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before_invalid, "Invalid protection count rejects atomically")
	invalid = saved.duplicate(true)
	invalid.colony.piles[0].workers.commitments.erase("honeydew:home")
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before_invalid, "Missing protection commitment rejects atomically")
	game.set_trail_workers(route.id, 0)
	copy.set_trail_workers(route.id, 0)
	game.advance(60.0)
	copy.set_time_scale(4)
	copy.advance(15.0)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Honeydew continuation matches across save and simulation speed")
	var tended_before: float = game.run.world.nodes.aphid_01.quantity
	test.check(copy.stop_honeydew_tending("home"), "Comparison run can release protection independently")
	game.advance(30.0)
	copy.advance(30.0)
	var tended_added: float = game.run.world.nodes.aphid_01.quantity - tended_before
	var untended_added: float = copy.run.world.nodes.aphid_01.quantity - tended_before
	test.check(tended_added > untended_added and untended_added > 0.0 and game.run.honeydew.condition > copy.run.honeydew.condition, "Tending yields more physical carbohydrate and resists predator pressure")
	var condition_before: float = game.run.honeydew.condition
	game.toggle_pause()
	var paused: Dictionary = game.run.to_dict()
	game.advance(60.0)
	test.check(game.run.to_dict() == paused, "Pause freezes producer condition and output")
	game.toggle_pause()
	game.advance(30.0)
	test.check(game.run.honeydew.condition > condition_before and game.run.world.nodes.aphid_01.quantity <= 40.0, "Protected producers recover and physical output stays capped")
	var tended_output: float = game.run.world.nodes.aphid_01.quantity
	test.check(game.stop_honeydew_tending("home") and pile.workers.count("honeydew:home") == -1 and pile.workers_total == workers_before, "Stopping protection releases ledger commitment")
	condition_before = game.run.honeydew.condition
	game.advance(30.0)
	test.check(game.run.honeydew.condition < condition_before and game.run.world.nodes.aphid_01.quantity <= 40.0 and game.run.world.nodes.aphid_01.quantity >= tended_output, "Unprotected predator pressure lowers condition while output remains physical")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.erase("honeydew")
	for index: int in range(legacy.world.nodes.size() - 1, -1, -1):
		if legacy.world.nodes[index].id == "aphid_01":
			legacy.world.nodes.remove_at(index)
	test.check(copy.restore_snapshot(legacy) and copy.run.honeydew.relationship == "unknown" and not copy.run.world.nodes.has("aphid_01"), "Earlier version-5 snapshots without honeydew source or state still load")
	var capped := Controller.new(3044)
	capped.run.world.nodes.aphid_01.quantity = 39.5
	capped.advance(30.0)
	test.check(capped.run.world.nodes.aphid_01.quantity == 40.0, "Honeydew production respects authored physical source capacity")
	return true
