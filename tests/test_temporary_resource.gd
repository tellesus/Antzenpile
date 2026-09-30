extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")


func run(test: Object) -> bool:
	_test_boundaries_and_reload(test)
	_test_colony_encounter(test)
	return true


func _test_boundaries_and_reload(test: Object) -> void:
	var game := Controller.new(3032)
	var spill: WorldNodeState = game.run.world.nodes.protein_picnic
	var original_protein: float = game.run.world.nodes.protein_01.quantity
	var appearances: Array[Dictionary] = []
	var expiries: Array[Dictionary] = []
	game.ecology.resource_appeared.connect(func(id: String, amount: float) -> void:
		appearances.append({"id": id, "amount": amount}))
	game.ecology.resource_expired.connect(func(id: String, amount: float) -> void:
		expiries.append({"id": id, "amount": amount}))
	game.advance(449.75)
	test.check(not spill.active and spill.quantity == 0.0 and appearances.is_empty(), "Picnic crumbs are absent before the authored event")
	var before_appearance: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(before_appearance), "Pre-appearance run restores")
	game.toggle_pause()
	game.advance(20.0)
	test.check(game.run.clock.tick_count == 1799 and appearances.is_empty(), "Paused time cannot start an episode")
	game.toggle_pause()
	game.set_time_scale(4)
	game.advance(0.0625)
	game.set_time_scale(1)
	copy.advance(0.25)
	test.check(spill.active and spill.quantity == 24.0 and appearances == [{"id": "protein_picnic", "amount": 24.0}], "Fixed appearance creates one bounded protein spill at 4×")
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.world.nodes.protein_01.quantity == original_protein, "Appearance continuation is exact and leaves another protein source untouched")
	var root := Root.new()
	root.simulation = game
	test.check(game.run.knowledge.nodes.is_empty() and root.sensory_snapshot("home").is_empty() and not root.outward_status("home").has("world"), "Appearance alone reveals no hidden source to normal play")
	root.free()
	game.advance(199.75)
	test.check(spill.active and spill.quantity == 24.0 and expiries.is_empty(), "Crumbs remain until the expiry boundary")
	var before_expiry: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	test.check(copy.restore_snapshot(before_expiry), "Mid-episode run restores")
	game.advance(0.25)
	copy.advance(0.25)
	test.check(not spill.active and spill.quantity == 0.0 and expiries == [{"id": "protein_picnic", "amount": 24.0}], "Expiry removes the uncollected remainder once")
	test.check(game.run.to_dict() == copy.run.to_dict(), "Expiry continuation is exact after reload")
	game.advance(0.25)
	test.check(expiries.size() == 1, "Expiry does not repeat on later ticks")
	game.advance(399.75)
	test.check(spill.active and spill.quantity == 24.0 and appearances.size() == 2, "A later authored episode repeats without a mutable cursor")
	var minimal := Controller.new(3033)
	minimal.run.world.nodes.erase("protein_picnic")
	minimal.advance(450.0)
	test.check(not minimal.run.world.nodes.has("protein_picnic"), "Ecology safely skips a minimal world without the temporary source")


func _test_colony_encounter(test: Object) -> void:
	var game := Controller.new(3040)
	game.advance(450.0)
	test.check(game.dispatch_scout("home", PI / 4.0), "Scout can search toward the active spill")
	var known_id := "known:protein_picnic"
	var saw_report: bool = false
	for step: int in 600:
		game.advance(0.25)
		if game.run.knowledge.nodes.has(known_id):
			saw_report = true
			break
	test.check(saw_report, "Scout senses nearby picnic protein and delivers evidence on return")
	if not saw_report:
		return
	var report_before: Dictionary = game.run.knowledge.to_dict()
	# Keep this ecology fixture supplied with travel energy while brood consumes food.
	game.run.colony.piles.home.deposit_resource("carbohydrate", 10.0)
	test.check(game.create_trail("home", known_id), "Delivered report supports an ordinary route investment")
	game.advance(70.0)
	var route: TrailRouteState = game.run.trails.routes.route_1
	test.check(route.delivered_total > 0.0 and game.run.world.nodes.protein_picnic.quantity < 24.0, "Aggregate foragers collect temporary protein through normal transit")
	game.advance(200.0)
	test.check(not game.run.world.nodes.protein_picnic.active and game.run.world.nodes.protein_picnic.quantity == 0.0, "The temporary source expires despite any trail")
	test.check(game.run.knowledge.to_dict() == report_before, "Expiry does not refresh delivered colony evidence")
	test.check(route.status == "depleted", "A route eventually reports the disappeared source through an empty return")
	test.check(game.run.colony.piles.home.workers.invariant_holds(), "Temporary collection preserves worker conservation")
