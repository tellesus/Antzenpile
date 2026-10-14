extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Recognition = preload("res://tests/test_recognition.gd")
const Chemistry = preload("res://tests/test_persistent_chemistry.gd")

func funded(empty: bool = true) -> SimulationController:
	var game := Controller.new(94)
	for id: String in PileState.RESOURCE_IDS: game.run.colony.piles.home.deposit_resource(id, 500)
	if empty: game.advance(360)
	return game

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))

func run(test: Object) -> bool:
	_replacement_and_priority(test)
	_waiting_and_manual(test)
	_followup_and_save(test)
	_loss(test)
	_scales(test)
	_ui(test)
	return true

func _replacement_and_priority(test: Object):
	var game := funded(false)
	var pile: PileState = game.run.colony.piles.home
	var before: Dictionary = game.run.to_dict()
	test.check(game.queue_adaptation("home", "lean"), "Full Primitive Nursery accepts a pending adaptation")
	before.colony.piles[0].queued_adaptation = "lean"
	before.colony.piles[0].investments.priority = ["adaptation"]
	test.check(game.run.to_dict() == before and game.adaptation.queued_status("home").waiting == "space", "Queue changes only saved intent, not resources, workers, brood, clock or RNG")
	test.check(game.queue_adaptation("home", "load"), "A new choice replaces the pending trait")
	before.colony.piles[0].queued_adaptation = "load"
	test.check(game.run.to_dict() == before and pile.trial_cohort() == null, "Replacement is one slot, not a list or a purchase")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)) and copy.run.to_dict() == before, "Full Nursery's editable queue round-trips before laying")
	for invalid: Variant in ["unknown", 3, null, ["lean", "load"]]:
		test.check(not game.queue_adaptation("home", invalid) and game.run.to_dict() == before, "Invalid pending selection rejects atomically")
	test.check(not game.queue_adaptation("missing", "lean") and game.run.to_dict() == before, "Unknown pile cannot queue")
	game.toggle_pause(); game.advance(1000)
	test.check(pile.queued_adaptation == "load" and pile.trial_cohort() == null and game.run.clock.simulation_time == 0, "Pause permits queue editing but prevents laying")
	game.toggle_pause(); game.set_brood_intent("home", "grow"); game.advance(359.75)
	var stores: Dictionary = pile.resources.duplicate()
	game.advance(0.25)
	test.check(pile.queued_adaptation == "" and pile.brood_cohorts.size() == 1 and pile.trial_cohort().adaptation_id == "load", "Queued choice takes the exact released brood slot before Auto Brood")
	test.check(pile.trial_cohort().progress_seconds == 0 and pile.brood_started_total == 2 and pile.workers.count("adaptation:home") == 2, "Laying locks one fresh cohort and commits two real nurses once")
	test.check(pile.resources.protein == stores.protein - 12 and pile.resources.carbohydrate == stores.carbohydrate - 12 and pile.resources.water == stores.water - 6, "Only actual laying pays the full authored cost once")
	before = game.run.to_dict()
	test.check(not game.queue_adaptation("home", "lean") and not game.queue_adaptation("home", "load") and game.run.to_dict() == before, "Laid trait and conflicting exclusive branch cannot edit this brood")
	test.check(game.queue_adaptation("home", "") and pile.trial_cohort().adaptation_id == "load" and pile.workers.count("adaptation:home") == 2, "Clearing pending intent never cancels laid brood or refunds its nurses")

func _waiting_and_manual(test: Object):
	var game := funded(); var pile: PileState = game.run.colony.piles.home
	pile.resources.protein = 0
	var stores: Dictionary = pile.resources.duplicate()
	test.check(game.queue_adaptation("home", "lean"), "Resource shortage does not block queuing")
	game.advance(0.25)
	test.check(pile.queued_adaptation == "lean" and pile.brood_cohorts.is_empty() and pile.resources == stores and pile.workers.count("adaptation:home") == -1 and game.adaptation.queued_status("home").waiting == "protein", "Unfunded queued trial waits without partial payment or nurse commitment")
	test.check(pile.workers.create_commitment("busy", "other", "busy") and pile.workers.allocate("busy", pile.workers_available), "Waiting fixture uses ledger-owned busy workers")
	pile.deposit_resource("protein", 20); game.advance(0.25)
	test.check(game.adaptation.queued_status("home").waiting == "nurses" and pile.trial_cohort() == null, "Funded queue still waits for available nurses")
	var available: int = pile.workers.count("busy")
	test.check(pile.workers.release("busy", available) and pile.workers.retire_commitment("busy"), "Busy fixture returns all workers through the ledger")
	test.check(game.start_brood("home") and pile.queued_adaptation == "" and pile.trial_cohort().adaptation_id == "lean" and pile.workers.invariant_holds(), "Manual lay obeys the queued next-brood choice and preserves the worker ledger")
	game = funded(); pile = game.run.colony.piles.home
	game.queue_adaptation("home", "load"); game.advance(0.25)
	test.check(pile.brood_intent == "manual" and pile.trial_cohort().adaptation_id == "load", "Queued trial is an explicit laying request even with ordinary Auto Brood off")
	game = funded(false); pile = game.run.colony.piles.home
	game.queue_adaptation("home", "lean")
	test.check(game.queue_adaptation("home", "") and pile.queued_adaptation == "", "Pending choice can be cancelled while space is full")
	game.advance(360)
	test.check(pile.brood_cohorts.is_empty(), "Cancelled queue does not lay later or create a waiting-list entry")

func _followup_and_save(test: Object):
	var game: SimulationController = Recognition.new().candidate_game()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.start_adaptation("home", "lean") and game.queue_adaptation("home", "security"), "Compatible observed next axis can queue while another trial is growing")
	test.check(game.queue_adaptation("home", "tolerance") and pile.queued_adaptation == "tolerance" and pile.trial_cohort().adaptation_id == "lean", "Follow-up replacement leaves the already-laid trait locked")
	test.check(game.adaptation.queued_status("home").waiting == "trial", "One focused trial constraint is an explicit waiting reason")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.start_brood("home") and game.run.to_dict() == before, "Manual ordinary laying cannot skip a waiting queued trial")
	game.set_brood_intent("home", "grow")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)) and copy.run.to_dict() == game.run.to_dict(), "Save preserves active locked brood plus one pending follow-up exactly")
	for invalid: Variant in [1, null, [], "lean", "load", "unknown"]:
		var bad: Dictionary = snapshot(game); bad.colony.piles[0].queued_adaptation = invalid
		before = copy.run.to_dict()
		test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == before, "Malformed, duplicate or conflicting saved queue rejects atomically")
	game.advance(360); copy.advance(360)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Queued follow-up save continuation is exact through emergence and paid laying")
	test.check(pile.adaptation_repertoire == "lean" and pile.trial_cohort().adaptation_id == "tolerance" and pile.trial_cohort().inherited_traits == ["lean", "tolerance"] and pile.queued_adaptation == "", "Follow-up locks the replacement choice and captures established traits at actual laying")
	before = game.run.to_dict()
	test.check(not game.queue_adaptation("home", "security") and game.run.to_dict() == before, "Conflicting recognition branch cannot replace a laid trial")
	var old: Dictionary = snapshot(funded(false)); old.colony.piles[0].erase("queued_adaptation");old.colony.piles[0].erase("investments")
	test.check(copy.restore_snapshot(old) and copy.run.colony.piles.home.queued_adaptation == "", "Legacy saves default to no queued adaptation")
	var bad: Dictionary = old.duplicate(true); bad.colony.piles[0].queued_adaptation = "persistent"
	before = copy.run.to_dict()
	test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == before, "Unrevealed saved candidate cannot enter the queue")
	bad = old.duplicate(true); bad.colony.piles[0].queued_adaptation = "lean"; bad.colony.piles[0].queen_count = 0
	test.check(not copy.restore_snapshot(bad) and copy.run.to_dict() == before, "Saved queue with no laying queen rejects atomically")

func _loss(test: Object):
	var game: SimulationController = Chemistry.new().candidate_game()
	var pile: PileState = game.run.colony.piles.home
	game.advance(800)
	game.start_adaptation("home", "lean"); game.queue_adaptation("home", "persistent")
	pile.consume_resources({"protein": pile.resources.protein})
	game.advance(800)
	test.check(pile.trial_cohort() == null and pile.queued_adaptation == "persistent" and pile.workers.count("adaptation:home") == -1, "Full brood loss releases laid-trial nurses but preserves pending intent")
	for id: String in PileState.RESOURCE_IDS: pile.deposit_resource(id, 100)
	game.advance(0.25)
	test.check(pile.trial_cohort().adaptation_id == "persistent" and pile.trial_cohort().inherited_traits == ["persistent"] and pile.workers.invariant_holds(), "Next queued trial lays without inventing expression for lost brood")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Loss followed by queued laying remains a valid snapshot")

func _scales(test: Object):
	var expected: Dictionary = {}
	for scale: int in [1, 4, 16, 64]:
		var game := funded(false)
		game.queue_adaptation("home", "load"); game.set_brood_intent("home", "grow")
		game.set_time_scale(scale); game.advance(360.25 / scale); game.set_time_scale(1)
		if scale == 1: expected = game.run.to_dict()
		test.check(game.run.to_dict() == expected, "Queued priority/paid laying has identical fixed-tick results at %dx" % scale)

func _ui(test: Object):
	var root := Root.new(); root.simulation = funded(false)
	var view := View.new(); test.get_root().add_child(view)
	view.adaptation_command = root.queue_adaptation
	view.status_provider = func() -> Dictionary: return root.inward_status("home")
	view._process(0); view.selected_id = "adaptation"; view.web_selection = "lean"
	var before: Dictionary = root.simulation.run.to_dict()
	test.check(view.activate_at(view._adaptation_rect("lean").get_center()), "Full Nursery has a usable queue button")
	view._process(0)
	test.check(view._queued_trait() == "lean" and AdaptationWeb.trait_state(view._status, "lean") == "Queued · next brood" and AdaptationWeb.queue_wait(view._status).contains("space"), "UI names pending choice and actual local waiting reason")
	var touch := InputEventScreenTouch.new(); touch.pressed = true
	touch.position = AdaptationWeb.positions(view.get_viewport_rect().size).load
	view._unhandled_input(touch)
	test.check(view.web_selection == "load" and view._queued_trait() == "lean", "Inspecting another graph leaf does not silently overwrite the queue")
	touch.position = view._adaptation_rect("load").get_center(); view._unhandled_input(touch); view._process(0)
	before.colony.piles[0].queued_adaptation = "load"
	before.colony.piles[0].investments.priority = ["adaptation"]
	test.check(root.simulation.run.to_dict() == before and view._queued_trait() == "load", "Explicit touch action replaces only next-brood intent")
	view._unhandled_input(touch); view._process(0)
	test.check(view._queued_trait() == "" and root.simulation.run.colony.piles.home.trial_cohort() == null, "Queued leaf offers cancellation without changing existing brood")
	view.free(); root.free()
