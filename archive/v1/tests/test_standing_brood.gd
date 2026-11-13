extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Expanded = preload("res://tests/test_nursery_expansion.gd")

func funded() -> SimulationController:
	var game := Controller.new(79)
	for id: String in PileState.RESOURCE_IDS: game.run.colony.piles.home.deposit_resource(id, 1000)
	return game

func run(test: Object) -> bool:
	var game: SimulationController = funded()
	var pile: PileState = game.run.colony.piles.home
	test.check(pile.brood_intent == "manual", "Existing manual production remains default")
	game.advance(360)
	test.check(pile.brood_cohorts.is_empty() and pile.brood_matured_total == 8, "Default production does not add an unsolicited cohort")
	game.toggle_pause()
	var before: Dictionary = game.run.to_dict()
	test.check(game.set_brood_intent("home", "grow") and pile.brood_cohorts.is_empty(), "Setting growth intent on pause does not lay immediately")
	before.colony.piles[0].brood_intent = "grow"
	test.check(game.run.to_dict() == before, "Intent changes only the selected pile policy, not stores/ledger/time/RNG")
	game.advance(100)
	test.check(pile.brood_cohorts.is_empty(), "Paused standing growth cannot produce brood")
	game.toggle_pause(); game.advance(0.25)
	test.check(pile.brood_cohorts.size() == 1 and pile.brood_cohorts[0].progress_seconds == 0 and pile.brood_started_total == 2, "Funded growth lays one ordinary cohort on a fixed tick")
	game.advance(720)
	test.check(pile.brood_matured_total == 24 and pile.brood_cohorts.size() == 1 and pile.workers.total == 64 and pile.workers.invariant_holds(), "Grow repeats ordinary maturation and conserved emergence without further lay commands")
	game.set_brood_intent("home", "manual")
	game.advance(720) # Existing sanitation can slow larvae; intent must not cancel them.
	test.check(pile.brood_cohorts.is_empty() and pile.brood_started_total == 4 and pile.brood_matured_total + pile.brood_lost_total == 32, "Manual intent stops new laying while existing brood finishes through unchanged ecology")
	before = game.run.to_dict()
	for intent: Variant in ["", "unlimited", true, 1, null]:
		test.check(not game.set_brood_intent("home", intent) and game.run.to_dict() == before, "Invalid intent rejects without side effects")
	test.check(not game.set_brood_intent("missing", "grow") and game.run.to_dict() == before, "Unknown pile rejects without side effects")
	for id: String in PileState.RESOURCE_IDS:
		game = funded(); pile = game.run.colony.piles.home
		game.advance(360); game.set_brood_intent("home", "grow")
		pile.resources[id] = 0
		before = pile.resources.duplicate()
		game.advance(0.25)
		test.check(pile.brood_cohorts.is_empty() and game.brood.production_status("home").waiting == id and pile.resources == before, "Missing " + id + " reserve waits without payment or new brood")
		pile.deposit_resource(id, 100)
		game.advance(0.25)
		test.check(pile.brood_cohorts.size() == 1 and pile.resources[id] == 100, "Replenished " + id + " resumes laying without prepaid food")
	_test_reserve(test)
	_test_limits(test)
	_test_saves_and_speed(test)
	_test_input(test)
	return true

func _test_reserve(test: Object):
	var game := funded()
	game.start_nursery_development("home"); game.advance(90)
	var pile: PileState = game.run.colony.piles.home
	# Exactly enough food for one additional cohort alone, but not its existing egg sibling.
	pile.resources = {"carbohydrate":14.4, "protein":4.32, "water":7.2}
	game.set_brood_intent("home", "grow"); game.advance(0.25)
	test.check(pile.brood_cohorts.size() == 1 and game.brood.production_status("home").waiting == "carbohydrate", "An existing egg's future feeding counts toward reserves")
	pile.brood_cohorts[0].stage = "larva"; pile.brood_cohorts[0].progress_seconds = 60
	var reserve: Dictionary = game.brood.remaining_food_reserve(pile)
	test.check(is_equal_approx(reserve.carbohydrate,21.6) and is_equal_approx(reserve.protein,6.48) and is_equal_approx(reserve.water,10.8), "Partly fed larvae need only remaining nutrition, not another full larval lifetime")
	pile.brood_cohorts[0].stage = "pupa"; pile.brood_cohorts[0].progress_seconds = 0
	game.advance(0.25)
	test.check(pile.brood_cohorts.size() == 2 and pile.resources == {"carbohydrate":14.4,"protein":4.32,"water":7.2}, "Pupae need no larval reserve; exact new-cohort budget permits laying without debit")
	game = funded(); pile = game.run.colony.piles.home
	game.start_nursery_development("home"); game.advance(90)
	game.start_food_exchange("home"); game.advance(60)
	pile.resources = {"carbohydrate":21.6,"protein":6.48,"water":10.8}
	game.set_brood_intent("home", "grow"); game.advance(0.25)
	test.check(pile.brood_cohorts.size() == 2, "Existing authored Food Exchange efficiency reduces the actual remaining food budget")

func _test_limits(test: Object):
	var game := funded(); var pile: PileState = game.run.colony.piles.home
	game.advance(360); game.set_brood_intent("home", "grow")
	pile.workers.create_commitment("test:busy", "other", "busy")
	pile.workers.allocate("test:busy", pile.workers_available - 1)
	game.advance(0.25)
	test.check(pile.brood_cohorts.is_empty() and game.brood.production_status("home").waiting == "care", "Existing available care capacity gates standing laying")
	pile.workers.release("test:busy", 1); game.advance(0.25)
	test.check(pile.brood_cohorts.size() == 1, "Released care labor resumes automatic laying")
	game.advance(0.25)
	test.check(pile.brood_cohorts.size() == 1 and game.brood.production_status("home").waiting == "space", "Standing growth respects primitive Nursery capacity")
	game = funded(); pile = game.run.colony.piles.home
	game.advance(360); pile.queen_count = 0; game.set_brood_intent("home", "grow"); game.advance(0.25)
	test.check(pile.brood_cohorts.is_empty() and game.brood.production_status("home").waiting == "queen", "No queen produces no brood despite standing intent")
	game = Expanded.new().needed(); pile = game.run.colony.piles.home
	# Partial losses may free numeric spaces but must not create an unbounded number of groups.
	pile.brood_cohorts[0].count = 4; pile.brood_cohorts[0].lost_count = 4
	pile.brood_cohorts[1].count = 3; pile.brood_cohorts[1].lost_count = 5
	pile.brood_lost_total = 9
	game.set_brood_intent("home", "grow")
	var before: Dictionary = game.run.to_dict()
	test.check(pile.brood_cohorts.size() == 2 and pile.nursery_occupied_space() == 7 and not game.start_brood("home") and not game.start_adaptation("home", "lean") and game.run.to_dict() == before, "Partially lost groups cannot add a third normal/trial cohort beyond the two-group contract")
	game.advance(0.25)
	test.check(pile.brood_cohorts.size() == 2 and game.brood.production_status("home").waiting == "space", "Standing growth preserves the same group bound after losses")
	var restored := PileState.new()
	test.check(restored.restore(JSON.parse_string(JSON.stringify(pile.to_dict(), "", true, true))), "Bounded partial-loss groups preserve valid pile accounting independently of the guest fixture")
	game = funded(); pile = game.run.colony.piles.home
	game.advance(360); game.set_brood_intent("home", "grow")
	pile.workers.add_living_workers("available", WorkerLedger.MAX_COUNT - pile.workers.total, "population boundary fixture")
	var capped: Dictionary = game.run.to_dict()
	test.check(game.brood.production_status("home").waiting == "population" and not game.start_brood("home") and game.run.to_dict() == capped, "Standing/manual population limits reject before adding unrepresentable brood")
	game = funded(); game.start_nursery_development("home"); game.advance(90)
	test.check(game.start_adaptation("home", "lean"), "A player-chosen trial starts through its existing funded command")
	game.set_brood_intent("home", "grow"); game.advance(0.25)
	test.check(game.run.colony.piles.home.brood_cohorts.size() == 2 and game.run.colony.piles.home.trial_cohort() != null, "Standing growth does not replace or choose an adaptation trial")

func _test_saves_and_speed(test: Object):
	var game := funded(); game.set_brood_intent("home", "grow"); game.advance(100)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Saved intent restores exactly")
	game.advance(1000); copy.advance(1000)
	test.check(copy.run.to_dict() == game.run.to_dict(), "Production and emergence continue exactly after JSON restore")
	var intact: Dictionary = copy.run.to_dict()
	for bad: Variant in [false, 12, "breed", null]:
		var invalid: Dictionary = saved.duplicate(true); invalid.colony.piles[0].brood_intent = bad
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Malformed saved intent rejects atomically")
	saved.colony.piles[0].erase("brood_intent")
	test.check(copy.restore_snapshot(saved) and copy.run.colony.piles.home.brood_intent == "manual", "Legacy save defaults to manual without unsolicited growth")
	var reference: Dictionary
	for speed: int in [1,4,16,64]:
		var paced := funded(); paced.set_brood_intent("home", "grow"); paced.set_time_scale(speed)
		paced.advance(720.25 / speed)
		paced.set_time_scale(1)
		var record: Dictionary = paced.run.to_dict()
		if speed == 1: reference = record
		test.check(record == reference, "Standing production gives identical simulated results at " + str(speed) + "x")

func _test_input(test: Object):
	var root := Root.new(); test.get_root().add_child(root); root.set_process(false)
	root.simulation = funded(); root.simulation.toggle_pause()
	var view := View.new(); root.add_child(view); view.selected_id = "queen"
	view.status_provider = root.inward_status.bind("home"); view.brood_intent_command = root.set_brood_intent; view._process(0)
	var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = view._brood_intent_rect("grow").get_center()
	view._unhandled_input(touch)
	test.check(root.simulation.run.colony.piles.home.brood_intent == "grow" and root.simulation.run.colony.piles.home.brood_cohorts.size() == 1 and root.simulation.run.clock.paused, "Touch sets intent on pause without laying or resuming")
	view.input_blocked = func() -> bool: return true
	var mouse := InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = true; mouse.position = view._brood_intent_rect("manual").get_center()
	view._unhandled_input(mouse)
	test.check(root.simulation.run.colony.piles.home.brood_intent == "grow", "Modal shield blocks production policy")
	view.input_blocked = Callable(); view._unhandled_input(mouse)
	test.check(root.simulation.run.colony.piles.home.brood_intent == "manual", "Mouse uses the same policy command")
	test.check(view._brood_intent_rect("grow").size.y == 44 and not view._brood_intent_rect("grow").intersects(view._brood_rect()) and not view._brood_rect().intersects(view._button_rect("pause")), "Intent, manual laying and clock have distinct touch targets")
	root.free()
