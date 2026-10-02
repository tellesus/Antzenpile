extends RefCounted
const Fixture = preload("res://tests/test_transit.gd")
const Toxic = preload("res://tests/test_food_contamination.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Memory = preload("res://src/presentation/outward/source_memory.gd")

func run(test: Object) -> bool:
	var game: SimulationController = Fixture.new().learned_game()
	game.create_trail("home", "known:carb_exposed")
	var route: TrailRouteState = game.run.trails.routes.route_1
	while game.run.trails.cohorts.is_empty(): game.advance(0.25)
	while game.run.trails.cohorts.cohort_1.direction == "outbound": game.advance(0.25)
	test.check(route.receipt.is_empty(), "Remote pickup and inbound food do not create a home receipt")
	while route.delivered_total == 0: game.advance(0.25)
	test.check(route.receipt.first_at == game.run.simulation_time and route.receipt.last_at == route.receipt.first_at and route.receipt.last_amount == route.delivered_total and not route.receipt.earlier_unrecorded, "First positive home intake records actual arrival and net amount")
	var first_at: float = route.receipt.first_at
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var twin := Controller.new(); test.check(twin.restore_snapshot(saved), "Receipt summary survives JSON restore")
	game.advance(60); twin.advance(60)
	test.check(game.run.to_dict() == twin.run.to_dict() and route.receipt.first_at == first_at and route.receipt.last_at > first_at, "Repeated actual deliveries preserve first date and exact later continuation")
	var root := Root.new(); root.simulation = game
	var entries: Array[Dictionary] = Memory.entries(root.sensory_snapshot("home"),root.outward_status("home"),"carbohydrate")
	var remembered: Array[Dictionary] = entries.duplicate(true)
	game.run.world.nodes.carb_exposed.quantity = 0
	game.run.world.nodes.carb_exposed.properties.contaminant_fraction = 0.9
	test.check(entries == Memory.entries(root.sensory_snapshot("home"),root.outward_status("home"),"carbohydrate"), "Hidden source depletion and chemistry cannot alter receipt evidence")
	var detached: Dictionary = root.trail_summaries("home")[0].receipt
	detached.last_amount = 999
	test.check(route.receipt.last_amount != 999 and not str(remembered).contains("contaminant"), "Normal receipt projection is detached and contains no hidden chemistry")
	test.check(Memory.receipt_label(remembered[0],game.run.simulation_time).contains("first") and Memory.receipt_label({"delivered_total":0},10) == "No food delivered home yet", "Receipt text distinguishes actual intake from sensing and no intake")
	root.free()
	# Malformed/future data rejects atomically at the full restore boundary.
	for invalid: Variant in [null, [], {"first_at":1}, {"first_at":0,"last_at":90,"last_amount":1,"earlier_unrecorded":false}, {"first_at":90,"last_at":89,"last_amount":1,"earlier_unrecorded":false}, {"first_at":90,"last_at":999999,"last_amount":1,"earlier_unrecorded":false}, {"first_at":90,"last_at":90,"last_amount":999,"earlier_unrecorded":false}, {"first_at":90,"last_at":90,"last_amount":1,"earlier_unrecorded":1}, {"first_at":90,"last_at":90,"last_amount":1,"earlier_unrecorded":false,"contaminant":true}]:
		var broken: Dictionary = saved.duplicate(true); broken.trails.routes[0].receipt = invalid
		var before: Dictionary = twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict() == before, "Malformed or inconsistent supply receipt cannot partly restore a run")
	var legacy: Dictionary = saved.duplicate(true); legacy.trails.routes[0].erase("receipt")
	var old := Controller.new(); test.check(old.restore_snapshot(legacy), "Legacy delivered route restores with unknown receipt dates")
	var old_route: TrailRouteState = old.run.trails.routes.route_1
	test.check(old_route.receipt.is_empty() and Memory.receipt_label({"delivered_total":5},100) == "Home dates unrecorded", "Existing food does not acquire an invented legacy arrival date")
	while old_route.receipt.is_empty(): old.advance(0.25)
	test.check(old_route.receipt.earlier_unrecorded and Memory.receipt_label({"receipt":old_route.receipt},old.run.simulation_time).contains("tracked"), "New post-legacy intake explicitly marks its incomplete earlier history")
	# A recalled loaded return records the energy-paid amount, not gross cargo.
	game = Toxic.new().returning_spill(true)
	route = game.run.trails.find_route("home","known:carb_spill")
	var cargo: TransitCohort
	for candidate: TransitCohort in game.run.trails.cohorts.values():
		if candidate.payload > 0: cargo = candidate; break
	var net: float = roundf(maxf(0,cargo.payload - cargo.unpaid_energy_cost) * 100000) / 100000
	game.set_trail_workers(route.id,0)
	while route.receipt.is_empty(): game.advance(0.25)
	test.check(route.receipt.last_amount == net and net < cargo.payload and route.receipt.last_at == game.run.simulation_time, "Recalled receipt counts only actual net intake after travel energy")
	var receipt: Dictionary = route.receipt.duplicate(true)
	game.advance(200)
	test.check(route.receipt == receipt, "Withdrawn supply retains dated history without inventing further deliveries")
	return true
