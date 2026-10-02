extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const Partner = preload("res://tests/test_adaptation_web.gd")


func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))


func advance_cared(game: SimulationController, seconds: float) -> void:
	for tick: int in roundi(seconds / 0.25):
		var pile: PileState = game.run.colony.piles.home
		if pile.midden.revealed and pile.midden.cleaners == 0:
			var cleaning: bool = game.set_sanitation_workers("home", 2)
			assert(cleaning)
		if game.run.guest.observation in ["loss", "foreign"] and game.run.colony.piles.home.workers.count("rejection:home") == -1:
			game.start_guest_rejection()
		game.advance(0.25)


func candidate_game() -> SimulationController:
	var game: SimulationController = Partner.new().known_fixture()
	var pile: PileState = game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(resource, 250.0)
	game.create_trail("home", "known:aphid_01")
	for tick: int in 500:
		if game.run.honeydew.relationship == "exploited":
			break
		game.advance(0.25)
	game.start_honeydew_tending("home")
	game.set_trail_workers("route_1", 0)
	advance_cared(game, 360.0)
	for attempt: int in 6:
		if pile.recognition_candidate:
			break
		game.start_brood("home")
		advance_cared(game, 360.0)
	return game


func inherited_game(id: String) -> SimulationController:
	var game := candidate_game()
	game.start_adaptation("home", id)
	advance_cared(game, 360.0)
	return game


func run(test: Object) -> bool:
	_test_opportunity(test)
	for choice: String in ["security", "tolerance"]:
		_test_trait(test, choice)
	_test_three_axes(test)
	_test_lost_trial(test)
	_test_ui(test)
	return true


func _test_opportunity(test: Object) -> void:
	var game := Controller.new()
	var before: Dictionary = game.run.to_dict()
	var root := Root.new()
	root.simulation = game
	test.check(not game.start_adaptation("home", "security") and game.run.to_dict() == before and not root.inward_status("home").adaptation_options.has("security"), "Recognition has no secret action or early trait reveal")
	advance_cared(game, 1200)
	test.check(game.run.colony.piles.home.recognition_experience and not game.run.colony.piles.home.recognition_candidate, "Local guest entry alone cannot reveal a genetic candidate")
	game = candidate_game()
	root.simulation = game
	var pile: PileState = game.run.colony.piles.home
	test.check(pile.recognition_experience and pile.recognition_candidate and pile.genetics.established.is_empty(), "Experienced partner chemistry and surviving brood reveal possibilities without expression")
	print("[RECOGNITION] candidate time=", game.run.simulation_time)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)) and copy.run.to_dict() == game.run.to_dict(), "Partner-derived recognition candidate survives exact save")
	var invalid: Dictionary = snapshot(game)
	invalid.colony.piles[0].recognition_experience = false
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Candidate without colony experience rejects atomically")
	root.free()


func _test_lost_trial(test: Object) -> void:
	var game := candidate_game()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.start_adaptation("home", "security") and pile.consume_resources({"protein": pile.resources.protein}), "Recognition loss fixture funds selection before a larval food shortage")
	game.advance(200)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Food-stalled recognition trial saves before the guest consumes it")
	game.advance(1000)
	copy.set_time_scale(16)
	copy.advance(62.5)
	copy.set_time_scale(1)
	test.check(game.run.to_dict() == copy.run.to_dict() and pile.trial_cohort() == null and pile.genetics.established.is_empty() and pile.recognition_candidate and pile.workers.count("adaptation:home") == -1, "Wholly consumed recognition trial releases nurses without expression or establishment")
	test.check(game.run.recognition_share("home") == 0 and copy.restore_snapshot(snapshot(game)), "Lost recognition trial keeps baseline effort and valid lifetime accounting")


func _test_trait(test: Object, id: String) -> void:
	var game := candidate_game()
	var pile: PileState = game.run.colony.piles.home
	var before: Dictionary = game.run.to_dict()
	pile.resources.protein = 15
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", id) and game.run.to_dict() == before, "Recognition payment rejects atomically: " + id)
	pile.deposit_resource("protein", 150.0)
	var stores: Dictionary = pile.resources.duplicate()
	test.check(game.start_adaptation("home", id) and pile.workers.count("adaptation:home") == 2 and is_equal_approx(pile.resources.protein, stores.protein - 16), "Selected recognition trial uses real food, nurses and brood")
	test.check(game.run.recognition_share("home") == 0 and game.run.honeydew.protection_workers == 6, "Pending recognition trial has no adult effect or labor retrofit")
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", "tolerance" if id == "security" else "security") and game.run.to_dict() == before, "Focused recognition trial blocks another purchase")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)), "Recognition trial saves with captured brood and nurses")
	advance_cared(game, 360)
	advance_cared(copy, 360)
	test.check(game.run.to_dict() == copy.run.to_dict() and id in pile.genetics.established and pile.genetics.count_trait(id) > 0, "Surviving recognition adults establish expression with exact continuation")
	var share: float = game.run.recognition_share("home")
	var required: int = AdaptationRules.protection_workers(6, share)
	test.check((share > 0 and required == 7) if id == "security" else (share < 0 and required == 5), "Recognition has a real opposite mutualism labor consequence")
	test.check(game.run.honeydew.protection_workers == 6 and game.stop_honeydew_tending("home") and game.start_honeydew_tending("home") and game.run.honeydew.protection_workers == required, "Existing protection keeps captured staffing until deliberate reassignment")
	before = game.run.to_dict()
	test.check(not game.start_adaptation("home", "tolerance" if id == "security" else "security") and game.run.to_dict() == before, "Established recognition endpoints remain exclusive")
	test.check(copy.restore_snapshot(snapshot(game)), "Trait-dependent protection staffing validates against its ledger commitment")
	var invalid: Dictionary = snapshot(game)
	invalid.honeydew.recognition_share = -share
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == game.run.to_dict(), "Wrong captured protection phenotype rejects atomically")
	# A genuine local encounter supplies symptoms; no inserted guest identity.
	if game.run.simulation_time < 1200:
		game.advance(1200 - game.run.simulation_time)
	test.check(game.start_brood("home"), "Trait-bearing colony lays brood before local guest pressure")
	for tick: int in 260:
		if game.run.guest.reported_losses > 0:
			break
		game.advance(0.25)
	if game.run.guest.observation == "purged":
		# Later candidates may have already dealt with this one prototype guest.
		test.check(AdaptationRules.rejection_duration(1200, share) < 240 if id == "security" else AdaptationRules.rejection_duration(1200, share) > 240, "Captured clearing work has the promised opposite tradeoff")
	else:
		test.check(game.run.guest.observation == ("foreign" if id == "security" else "loss"), "Locally witnessed harm associates earlier under security and later under tolerance")
		test.check(game.start_guest_rejection(), "Observed harm permits real funded clearing work")
		var duration: int = game.run.guest.rejection_duration_ticks
		var baseline: int = AdaptationRules.rejection_duration(game.run.guest.integration_ticks, 0)
		test.check(duration < baseline if id == "security" else duration > baseline, "Actual clearing time trades off with protection labor")
		test.check(copy.restore_snapshot(snapshot(game)), "Captured recognition effort saves during clearing")
		game.advance(duration * 0.25)
		copy.set_time_scale(4)
		copy.advance(duration * 0.25 / 4)
		copy.set_time_scale(1)
		test.check(game.run.to_dict() == copy.run.to_dict() and game.run.guest.phase == "purged", "Clearing finishes and restores exact speed/save continuation")
	var key: String = GeneticRepertoire.profile([id])
	var adults: int = pile.genetics.count_trait(id)
	test.check(pile.lose_workers("available", adults, 0, "Known recognition adult losses", key) and game.run.recognition_share("home") == 0 and id in pile.genetics.established, "Lost recognition adults remove expression while retaining inherited possibility")
	test.check(game.run.honeydew.protection_workers == required and copy.restore_snapshot(snapshot(game)), "Previously staffed partner work remains valid after expressed adults are lost")


func _test_three_axes(test: Object) -> void:
	var game: SimulationController = load("res://tests/test_persistent_chemistry.gd").new().candidate_game()
	var pile: PileState = game.run.colony.piles.home
	game.advance(maxf(0, 1200 - game.run.simulation_time))
	game.start_adaptation("home", "lean")
	advance_cared(game, 360)
	game.start_adaptation("home", "persistent")
	advance_cared(game, 360)
	for attempt: int in 6:
		if pile.recognition_candidate:
			break
		game.start_brood("home")
		advance_cared(game, 360)
	test.check(game.start_adaptation("home", "security") and pile.trial_cohort().inherited_traits == ["lean", "persistent", "security"], "Third-axis trial captures existing foraging and chemistry traits")
	advance_cared(game, 360)
	var copy := Controller.new()
	var survivors: int = pile.genetics.living.get("lean+persistent+security", 0)
	test.check(survivors > 0 and survivors <= 8 and copy.restore_snapshot(snapshot(game)), "Three traits share one surviving phenotype with valid lifetime accounting")
	test.check(pile.lose_workers("available", 1, 1, "Known joint loss", "lean+persistent+security") and pile.genetics.count_trait("security") == survivors - 1 and pile.workers.lost_total == 1, "One third-axis worker casualty removes one ant while changing all its trait counts")
	test.check(copy.restore_snapshot(snapshot(game)), "Third-axis mortality remains saveable")


func _test_ui(test: Object) -> void:
	var root := Root.new()
	root.simulation = candidate_game()
	var view := View.new()
	test.get_root().add_child(view)
	view._status = root.inward_status("home")
	view.selected_id = "adaptation"
	view.adaptation_command = root.start_adaptation
	var before: Dictionary = root.simulation.run.to_dict()
	test.check(view.activate_at(view._web_family_rect().get_center()) and view.web_family == "recognition" and root.simulation.run.to_dict() == before, "Recognition family focus is navigation, not a trait purchase")
	for size: Vector2 in [Vector2(1280,720), Vector2(900,600)]:
		for id: String in Web.visible_nodes(view._status, "recognition"):
			test.check(Web.node_at(Web.positions(size)[id], size, view._status, "recognition") == id and Web.positions(size)[id].x + 44 <= size.x - 316, "Focused recognition graph keeps separated touch targets: " + id)
	view.activate_at(Web.positions(view.get_viewport_rect().size).tolerance)
	test.check(view.web_selection == "tolerance" and root.simulation.run.to_dict() == before, "Recognition leaf inspection is free")
	test.check(view.activate_at(view._adaptation_rect("tolerance").get_center()) and root.simulation.run.colony.piles.home.trial_cohort().adaptation_id == "tolerance", "One contextual pointer action starts the selected recognition endpoint")
	view.free()
	root.free()

