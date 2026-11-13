extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_guest.gd")
const Recognition = preload("res://tests/test_recognition.gd")
const CONFIG = preload("res://data/ecology/backyard_guest.tres")


func run(test: Object) -> bool:
	var game: SimulationController = Fixture.new().loss_fixture()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.start_guest_rejection(), "First encounter funds rejection from local evidence")
	for tick: int in 240:
		if game.run.guest.phase == "purged":
			break
		game.advance(0.25)
	var due: int = game.run.guest.next_entry_tick
	var lifetime: int = pile.brood_lost_total
	var quiet: Dictionary = Fixture.new().snapshot(game)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(quiet) and due == game.run.clock.tick_count + CONFIG.quiet_interval_ticks, "Purge schedules a saved quiet interval and releases its labor")
	game.toggle_pause()
	var before: Dictionary = game.run.to_dict()
	game.advance(100)
	test.check(game.run.to_dict() == before, "Pause preserves the quiet interval without wall-time arrivals")
	game.toggle_pause()
	Fixture.new().until_tick(game, due - 1)
	copy.set_time_scale(64)
	copy.advance(float(due - 1 - copy.run.clock.tick_count) * 0.25 / 64.0)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.guest.phase == "purged" and pile.brood_lost_total == lifetime, "One/64x quiet progression matches; the cleared population causes no damage")
	game.advance(0.25)
	copy.advance(0.25)
	var root := Root.new()
	root.simulation = game
	var summary: Dictionary = root.guest_summary("home")
	before = game.run.to_dict()
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.guest.encounters_total == 2 and game.run.guest.observation == "tolerated" and summary.reported_losses == 0 and summary.total_reported_losses == lifetime, "Fresh entry resets local suspicion while retaining colony loss history")
	test.check(not game.start_guest_rejection() and game.run.to_dict() == before, "Prior losses cannot authorize rejection before this encounter has evidence")
	test.check(not summary.has("next_entry_tick") and not summary.has("entry_tick") and not summary.has("encounters_total") and not summary.has("integration_ticks"), "Normal guest summary excludes recurrence forecast and hidden acquired odor")
	test.check(copy.restore_snapshot(Fixture.new().snapshot(game)), "Fresh entry with historical brood deaths is saveable")
	Fixture.new().until_tick(game, due + CONFIG.damage_ticks - 1)
	test.check(game.run.guest.encounter_losses == 1 and game.run.guest.reported_losses == lifetime + 1 and game.run.guest.observation == "loss", "New uncertain symptom is not turned into foreignness by old losses")
	test.check(game.start_guest_rejection() and copy.restore_snapshot(Fixture.new().snapshot(game)), "Second rejection captures new effort with valid lifetime conservation")
	for tick: int in 260:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict() and game.run.guest.phase == "purged" and pile.workers.count("rejection:home") == -1, "Second purge releases exactly its commitment and continues identically")
	for field: String in ["partial", "past_due", "far_due", "entry", "losses", "encounters", "tick_type"]:
		var invalid: Dictionary = quiet.duplicate(true)
		match field:
			"partial": invalid.guest.erase("entry_tick")
			"past_due": invalid.guest.next_entry_tick = str(due - CONFIG.quiet_interval_ticks)
			"far_due": invalid.guest.next_entry_tick = str(due + 1)
			"entry": invalid.guest.entry_tick = str(due)
			"losses": invalid.guest.encounter_losses = lifetime + 1
			"encounters": invalid.guest.encounters_total = 2
			"tick_type": invalid.guest.entry_tick = CONFIG.first_tick
		before = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Invalid recurrence history rejects atomically: " + field)
	var legacy: Dictionary = quiet.duplicate(true)
	for field: String in ["encounter_losses", "encounters_total", "entry_tick", "next_entry_tick"]:
		legacy.guest.erase(field)
	test.check(copy.restore_snapshot(legacy) and copy.run.guest.encounters_total == 1 and copy.run.guest.next_entry_tick == copy.run.clock.tick_count + CONFIG.quiet_interval_ticks, "Legacy purged save begins a fresh quiet interval with preserved loss history")
	root.free()
	_test_endpoints(test)
	return true


func _test_endpoints(test: Object) -> void:
	var losses: Dictionary = {}
	var durations: Dictionary = {}
	for choice: String in ["security", "tolerance"]:
		var game: SimulationController = Recognition.new().candidate_game()
		var pile: PileState = game.run.colony.piles.home
		game.start_adaptation("home", choice)
		Recognition.new().advance_cared(game, 360)
		game.start_brood("home")
		# First intrusion is cleared as soon as causal evidence reaches home.
		for tick: int in 4000:
			if game.run.guest.observation == "foreign":
				game.start_guest_rejection()
			if game.run.guest.phase == "purged":
				break
			game.advance(0.25)
		Fixture.new().until_tick(game, game.run.guest.next_entry_tick)
		game.start_brood("home")
		var previous_losses: int = pile.brood_lost_total
		for tick: int in CONFIG.damage_ticks * 4:
			if game.run.guest.observation == "foreign":
				break
			game.advance(0.25)
		losses[choice] = pile.brood_lost_total - previous_losses
		test.check(game.start_guest_rejection(), "Expressed %s can respond to a recurring observed intrusion" % choice)
		durations[choice] = game.run.guest.rejection_duration_ticks
		var copy := Controller.new()
		test.check(copy.restore_snapshot(Fixture.new().snapshot(game)), "Recurring %s effort saves its current profile and lifetime losses" % choice)
	test.check(losses.security == 1 and losses.tolerance == 3 and durations.security < durations.tolerance, "Later security/tolerance cohorts change real recurring damage and clearing, not just the first encounter")
