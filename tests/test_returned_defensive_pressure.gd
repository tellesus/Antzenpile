extends RefCounted
const Fixture = preload("res://tests/test_ambusher_defense.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")

func run(test: Object) -> bool:
	var game: SimulationController = Fixture.new().ready_game()
	var root := Root.new(); root.simulation = game
	test.check(game.journey_response.defend("route_1"), "Ordinary returned survey funds defense before pressure reporting")
	while game.run.journey_response.pressure.remaining_ticks == 0: game.advance(0.25)
	var party: JourneyResponseState = game.run.journey_response
	var pressure: JourneyPressureState = party.pressure
	test.check(pressure.messengers == 1 and pressure.reports.is_empty() and root.outward_status("home").journey_response.pressure_reports.is_empty(), "One real fighter leaves front; sampled pressure cannot arrive without travel")
	var before: Dictionary = Fixture.new().snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(before), "Traveling messenger restores with conserved party commitment")
	for tick: int in pressure.remaining_ticks - 1: game.advance(0.25); copy.advance(0.25)
	test.check(pressure.reports.is_empty() and game.run.to_dict() == copy.run.to_dict(), "Every pre-arrival tick preserves hidden finding and exact saved continuation")
	game.advance(0.25); copy.advance(0.25)
	var report: Dictionary = pressure.reports.route_1
	test.check(report.observed_at < report.received_at and report.received_at == game.run.simulation_time and party.active() and game.run.to_dict() == copy.run.to_dict(), "Physical returning ant delivers an older snapshot before party settlement")
	var known: Dictionary = root.outward_status("home").journey_response
	test.check(known.pressure_reports.route_1 == report and not known.has("phase") and not known.has("resistance") and not known.has("messengers") and not known.has("remaining_ticks"), "Normal response has only delivered pressure, without combat/position or private courier facts")
	var decision: Dictionary = Fixture.new().snapshot(game)
	test.check(game.journey_response.reinforce("route_1") and game.journey_response.summary().reinforcement_pending and not game.journey_response.summary().reinforcement_available, "Informed reinforcement is a real locally known pending order")
	before = game.run.to_dict()
	test.check(not game.journey_response.reinforce("route_1") and game.run.to_dict() == before, "Duplicate pending order rejects atomically")
	while party.active(): game.advance(0.25)
	test.check(party.defense.outcomes.route_1.sent == 16 and party.pressure.messengers == 0 and game.run.colony.piles.home.workers.count("journey:home") == -1, "Final return releases surviving frontline and local liaisons without adding ants")
	var withdrawal := Controller.new(); withdrawal.restore_snapshot(decision)
	test.check(withdrawal.journey_response.recall(), "Returned pressure also permits choosing physical withdrawal")
	while withdrawal.run.journey_response.active(): withdrawal.advance(0.25)
	test.check(withdrawal.run.journey_response.defense.outcomes.route_1.outcome == "withdrew" and withdrawal.run.predator.defeated_at == 0, "Withdrawal ends this paid attempt without inventing victory")
	for field: String in ["telemetry", "count", "future", "ownership"]:
		var invalid: Dictionary = decision.duplicate(true)
		match field:
			"telemetry": invalid.journey_response.pressure.reports.route_1.pressure = "exact_health_4"
			"count": invalid.journey_response.pressure.messengers = 13
			"future": invalid.journey_response.pressure.reports.route_1.received_at = game.run.simulation_time + 1000
			"ownership": invalid.journey_response.pressure.reports.unknown_route = invalid.journey_response.pressure.reports.route_1
		var fresh := Controller.new(); before = fresh.run.to_dict()
		test.check(not fresh.restore_snapshot(invalid) and fresh.run.to_dict() == before, "Invalid pressure " + field + " rejects atomically")
	var recalled := Controller.new(); recalled.restore_snapshot(decision)
	var recalled_copy := Controller.new(); recalled_copy.restore_snapshot(decision)
	recalled.journey_response.recall(); recalled_copy.journey_response.recall()
	recalled.advance(120); recalled_copy.advance(120)
	test.check(recalled.run.to_dict() == recalled_copy.run.to_dict(), "Concurrent messenger/body recall settles with exact continuation")
	var legacy: Dictionary = Fixture.new().snapshot(Controller.new()); legacy.journey_response.erase("pressure")
	test.check(copy.restore_snapshot(legacy), "Legacy save defaults to no pressure courier/history")
	root.free()
	return true
