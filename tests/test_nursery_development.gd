extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const CONFIG = preload("res://data/resources/default_nursery_development.tres")
const Service = preload("res://src/core/save_service.gd")
const SLOT: String = "res://.godot/card031_test_slot.json"


func _funded() -> SimulationController:
	var game := Controller.new(3031)
	var pile: PileState = game.run.colony.piles.home
	for category: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(category, 100.0)
	return game


func run(test: Object) -> bool:
	_test_build_and_two_cohorts(test)
	_test_overlap_turnover(test)
	_test_inward_actions(test)
	return true


func _test_build_and_two_cohorts(test: Object) -> void:
	var game := Controller.new(3031)
	var pile: PileState = game.run.colony.piles.home
	var initial: Dictionary = game.run.to_dict()
	test.check(not game.start_nursery_development("missing") and game.run.to_dict() == initial, "Unknown pile rejects Nursery development atomically")
	test.check(not game.start_nursery_development("home") and game.run.to_dict() == initial, "Insufficient resources reject without labor transfer")
	game = _funded()
	pile = game.run.colony.piles.home
	test.check(pile.workers.create_commitment("test:busy", "other", "busy") and pile.workers.allocate("test:busy", 37), "Build fixture leaves three available workers")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.start_nursery_development("home") and game.run.to_dict() == before, "Insufficient labor rejects without payment")
	test.check(pile.workers.release("test:busy", 37) and pile.workers.retire_commitment("test:busy"), "Fixture labor returns through ledger")
	var events: Array[String] = []
	game.nursery.chamber_online.connect(func(id: String) -> void: events.append(id))
	test.check(game.start_nursery_development("home"), "Funded Primitive Nursery starts development")
	test.check(pile.nursery_state == "developing" and pile.nursery_progress_seconds == 0.0 and pile.workers.count("nursery:home") == CONFIG.workers_required and pile.resources == {"carbohydrate": 92.0, "protein": 97.0, "water": 104.0}, "Start pays once and commits four workers")
	before = game.run.to_dict()
	test.check(not game.start_nursery_development("home") and game.run.to_dict() == before, "Duplicate build start cannot double-charge")
	game.advance(89.75)
	test.check(pile.nursery_state == "developing" and pile.nursery_progress_seconds == 89.75 and pile.nursery_brood_capacity() == 8 and events.is_empty(), "Benefit stays dormant during fixed-time construction")
	var mid: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(mid) and copy.run.to_dict() == game.run.to_dict(), "Mid-build save restores exact progress and commitment")
	var service: SaveService = Service.new(SLOT)
	var disk_copy := Controller.new()
	test.check(service.save(game.run) and service.load_into(disk_copy) and disk_copy.run.to_dict() == game.run.to_dict(), "Mid-build disk save restores development labor and time")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT))
	var intact: Dictionary = copy.run.to_dict()
	var invalid: Dictionary = mid.duplicate(true)
	invalid.colony.piles[0].nursery_progress_seconds = CONFIG.build_seconds
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Impossible unfinished progress rejects atomically")
	invalid = mid.duplicate(true)
	invalid.colony.piles[0].workers.commitments.erase("nursery:home")
	invalid.colony.piles[0].workers.available += CONFIG.workers_required
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Developing Nursery without its ledger commitment rejects")
	game.toggle_pause()
	game.advance(20.0)
	test.check(pile.nursery_progress_seconds == 89.75, "Pause freezes Nursery development")
	game.toggle_pause()
	game.set_time_scale(4)
	game.advance(0.0625)
	game.set_time_scale(1)
	copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict() and pile.nursery_state == "developed" and pile.nursery_brood_capacity() == 16 and pile.nursery_max_care_capacity() == 16, "Equal simulated time completes identically at 4× and after reload")
	test.check(pile.workers.count("nursery:home") == -1 and pile.workers_available == 40 and events == ["home"] and pile.workers.invariant_holds(), "Completion releases workers and emits chamber event once")
	game.advance(1.0)
	test.check(events == ["home"] and not game.start_nursery_development("home"), "Completed Nursery cannot restart or re-emit")

	test.check(game.start_brood("home") and pile.brood_cohorts.size() == 2 and pile.brood_cohorts[0].id == "brood_1" and pile.brood_cohorts[1].id == "brood_2" and pile.nursery_occupied_space() == 16, "Developed Nursery supports a second distinct aggregate cohort")
	before = game.run.to_dict()
	test.check(not game.start_brood("home") and game.brood.last_error == "Nursery lacks brood space" and game.run.to_dict() == before, "Third concurrent cohort rejects at capacity")
	test.check(pile.workers.create_commitment("test:care", "other", "care") and pile.workers.allocate("test:care", 38), "Care fixture leaves two available workers")
	var progress_a: float = pile.brood_cohorts[0].progress_seconds
	var progress_b: float = pile.brood_cohorts[1].progress_seconds
	game.advance(0.25)
	test.check(pile.nursery_care_capacity() == 8 and pile.brood_cohorts[0].care == 0.5 and pile.brood_cohorts[1].care == 0.5 and pile.brood_cohorts[0].progress_seconds == progress_a and pile.brood_cohorts[1].progress_seconds == progress_b, "Two carers cannot fully support sixteen brood and both cohorts pause")
	test.check(pile.workers.release("test:care", 2), "Two more workers become available")
	game.advance(0.25)
	test.check(pile.nursery_care_capacity() == 16 and pile.brood_cohorts[0].care == 1.0 and pile.brood_cohorts[1].care == 1.0 and pile.brood_cohorts[0].progress_seconds > progress_a and pile.brood_cohorts[1].progress_seconds > progress_b, "Four carers support both cohorts")
	var concurrent: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	test.check(copy.restore_snapshot(concurrent) and copy.run.to_dict() == game.run.to_dict(), "Two active cohorts and care labor restore exactly")
	invalid = concurrent.duplicate(true)
	invalid.colony.piles[0].brood_cohorts[1].id = "brood_1"
	intact = copy.run.to_dict()
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Duplicate concurrent cohort ID rejects atomically")
	invalid = concurrent.duplicate(true)
	invalid.colony.piles[0].brood_cohorts.append(invalid.colony.piles[0].brood_cohorts[1].duplicate(true))
	invalid.colony.piles[0].brood_cohorts[2].id = "brood_3"
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Third saved cohort cannot exceed developed space")
	for tick: int in 40:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Concurrent brood continuation remains deterministic for forty ticks")
	test.check(pile.workers.release("test:care", 36) and pile.workers.retire_commitment("test:care"), "Remaining care fixture labor returns")
	game.advance(370.0)
	test.check(pile.brood_cohorts.is_empty() and pile.brood_matured_total == 16 and pile.workers_total == 56 and pile.nursery_occupied_space() == 0 and pile.workers.invariant_holds(), "Both cohorts emerge exactly once through the worker ledger")
	test.check(game.start_brood("home") and pile.brood_cohorts[0].id == "brood_3", "Next laying uses a unique sequential cohort ID")


func _test_overlap_turnover(test: Object) -> void:
	var game := _funded()
	var pile: PileState = game.run.colony.piles.home
	test.check(game.start_nursery_development("home"), "Turnover fixture funds Nursery development")
	game.advance(CONFIG.build_seconds)
	test.check(game.start_brood("home"), "Second cohort begins while the first remains active")
	game.advance(270.0)
	test.check(pile.brood_matured_total == 8 and pile.brood_cohorts.size() == 1 and pile.brood_cohorts[0].id == "brood_2", "Older cohort emerges while younger cohort remains")
	test.check(game.start_brood("home") and pile.brood_cohorts.size() == 2 and pile.brood_cohorts[1].id == "brood_3", "Freed space permits a third unique cohort while the second is active")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot) and copy.run.to_dict() == game.run.to_dict(), "Overlapping cohort turnover restores exact identities and counts")


func _test_inward_actions(test: Object) -> void:
	var root := Root.new()
	root.simulation = _funded()
	var ui := View.new()
	test.get_root().add_child(ui)
	ui.selected_id = "nursery"
	ui._status = root.inward_status("home")
	ui.nursery_develop_command = root.start_nursery_development
	ui.brood_command = root.start_brood
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = ui._nursery_develop_rect().get_center()
	ui._unhandled_input(touch)
	test.check(root.simulation.run.colony.piles.home.nursery_state == "developing" and ui._feedback == "Nursery development started", "Nursery touch action dispatches semantic development command")
	var detached: Dictionary = root.inward_status("home")
	detached.nursery_costs.protein = 999.0
	test.check(root.inward_status("home").nursery_costs.protein == CONFIG.protein_cost and not detached.has("world"), "INWARD cost summary cannot mutate authored data or access hidden world")
	root.simulation.advance(CONFIG.build_seconds)
	ui._status = root.inward_status("home")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = ui._brood_rect().get_center()
	ui._unhandled_input(mouse)
	test.check(root.simulation.run.colony.piles.home.brood_cohorts.size() == 2 and ui._feedback == "New brood started", "Developed Nursery mouse action lays a second cohort through the same semantic path")
	test.check(ui._brood_rect().size == Vector2(260, 44) and ui._nursery_develop_rect().size == Vector2(260, 44), "Both Nursery actions use touch-sized targets")
	ui.free()
	root.free()
