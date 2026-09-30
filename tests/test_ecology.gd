extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")


func run(test: Object) -> bool:
	var game := Controller.new(3027)
	var nectar: WorldNodeState = game.run.world.nodes.carb_sheltered
	var other: WorldNodeState = game.run.world.nodes.carb_exposed
	var other_start: float = other.quantity
	nectar.quantity = 0.0
	nectar.active = false
	var pulses: Array[Dictionary] = []
	game.ecology.resource_pulsed.connect(func(id: String, amount: float) -> void:
		pulses.append({"id": id, "amount": amount}))
	game.advance(299.75)
	test.check(nectar.quantity == 0.0 and not nectar.active and pulses.is_empty(), "No nectar returns before the authored pulse")
	game.toggle_pause()
	game.advance(60.0)
	test.check(nectar.quantity == 0.0 and pulses.is_empty(), "Pause freezes the ecological schedule")
	game.toggle_pause()
	game.set_time_scale(4)
	game.advance(0.0625)
	game.set_time_scale(1)
	test.check(game.run.clock.tick_count == 1200 and nectar.quantity == 12.0 and nectar.active, "Fixed tick 1200 renews a depleted nectar source at 4×")
	test.check(pulses.size() == 1 and pulses[0] == {"id": "carb_sheltered", "amount": 12.0} and other.quantity == other_start, "Pulse affects only its authored physical source")
	var root := Root.new()
	root.simulation = game
	test.check(game.run.knowledge.nodes.is_empty() and root.sensory_snapshot("home").is_empty() and not root.outward_status("home").has("world"), "Hidden replenishment creates no colony knowledge or OUTWARD signal")
	root.free()
	nectar.quantity = 95.0
	game.advance(299.75)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot) and copy.run.to_dict() == game.run.to_dict(), "Mid-schedule full-precision save restores without extra ecology state")
	game.advance(0.25)
	copy.advance(0.25)
	test.check(nectar.quantity == 100.0 and pulses.size() == 2 and pulses[1].amount == 5.0, "Second pulse respects the source capacity")
	test.check(game.run.to_dict() == copy.run.to_dict(), "Continuation across a renewal pulse is exact after reload")
	game.advance(0.25)
	test.check(nectar.quantity == 100.0 and pulses.size() == 2, "A pulse occurs once per scheduled tick")
	_test_stale_knowledge_and_route(test)
	_test_busy_recheck(test)
	return true


func _test_stale_knowledge_and_route(test: Object) -> void:
	var game := Controller.new(3028)
	test.check(game.dispatch_scout("home", PI), "Scout can investigate sheltered carbohydrate before renewal")
	game.advance(100.0)
	test.check(game.run.knowledge.nodes.has("known:carb_sheltered"), "Scout returns the source report through ordinary knowledge delivery")
	if not game.run.knowledge.nodes.has("known:carb_sheltered"):
		return
	var known_before: Dictionary = game.run.knowledge.to_dict()
	var nectar: WorldNodeState = game.run.world.nodes.carb_sheltered
	nectar.quantity = 0.0
	nectar.active = false
	test.check(game.create_trail("home", "known:carb_sheltered"), "Known source can receive a trail investment")
	game.advance(50.0)
	var route: TrailRouteState = game.run.trails.routes.route_1
	test.check(route.status == "depleted", "Empty return reports unavailable source")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.recheck_trail("missing") and game.run.to_dict() == before, "Unknown recheck rejects without changing the run")
	test.check(game.recheck_trail(route.id) and route.status == "active" and not route.reported_depleted and nectar.quantity == 0.0, "Recheck changes intent without querying hidden source")
	before = game.run.to_dict()
	test.check(not game.recheck_trail(route.id) and game.run.to_dict() == before, "Active trail cannot be rechecked twice")
	game.advance(50.0)
	test.check(route.status == "depleted" and route.delivered_total == 0.0, "A still-empty source sends the trail back to depleted after travel")
	before = game.run.to_dict()
	test.check(game.set_trail_workers(route.id, 0) and not game.recheck_trail(route.id), "Inactive trail rejects recheck")
	test.check(game.create_trail("home", "known:carb_sheltered"), "The existing route can be reinvested after cancellation")
	game.advance(50.0)
	test.check(route.status == "depleted", "Reinvested dry route also returns empty")
	game.advance(150.0)
	test.check(nectar.quantity == 12.0 and route.status == "depleted", "Renewal does not secretly reactivate a depleted trail")
	test.check(game.run.knowledge.to_dict() == known_before, "Renewal does not rewrite the colony's historical report")
	var root := Root.new()
	root.simulation = game
	var view := Outward.new()
	test.get_root().add_child(view)
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = view._signals[0].id
	view.trail_recheck_command = root.recheck_trail
	var recheck_at: Vector2 = view._trail_button_rect("trail_recheck").get_center()
	test.check(view._button_at(recheck_at) == "trail_recheck", "Selected depleted route exposes a touch-sized Recheck control")
	var stored_before: float = game.run.colony.piles.home.resources.carbohydrate
	view._pointer_press(recheck_at, "touch")
	test.check(route.status == "active" and nectar.quantity == 12.0 and game.run.colony.piles.home.resources.carbohydrate == stored_before, "Touch Recheck dispatches a semantic command without instant collection")
	view.free()
	root.free()
	game.advance(0.25)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot), "Recheck in flight restores from a full-precision save")
	game.advance(10.0)
	copy.advance(10.0)
	test.check(game.run.colony.piles.home.resources.carbohydrate == stored_before, "Renewed nectar remains in transit before workers return")
	game.advance(11.0)
	copy.advance(11.0)
	test.check(game.run.colony.piles.home.resources.carbohydrate > stored_before and game.run.to_dict() == copy.run.to_dict(), "Recheck delivers renewed nectar on return and continues exactly after reload")
	test.check(game.run.colony.piles.home.workers.invariant_holds(), "Recheck preserves worker conservation")


func _test_busy_recheck(test: Object) -> void:
	var game := Controller.new(3029)
	game.dispatch_scout("home", PI)
	game.advance(100.0)
	game.run.world.nodes.carb_sheltered.quantity = 0.0
	game.run.world.nodes.carb_sheltered.active = false
	test.check(game.create_trail("home", "known:carb_sheltered") and game.set_trail_workers("route_1", 20), "Busy recheck fixture commits bounded cohorts")
	game.advance(20.25)
	var route: TrailRouteState = game.run.trails.routes.route_1
	test.check(route.status == "depleted" and route.active_workers > 0, "One empty return depletes the route while other cohorts travel")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.recheck_trail(route.id) and game.run.to_dict() == before, "Recheck waits for all travelling workers without changing state")
	test.check(game.set_trail_workers(route.id, 0) and route.status == "recalling", "Cancellation recalls the remaining cohorts")
	before = game.run.to_dict()
	test.check(not game.recheck_trail(route.id) and game.run.to_dict() == before, "Recalling route rejects recheck atomically")
