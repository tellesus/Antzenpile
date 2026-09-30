extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Config = preload("res://data/resources/default_brood.tres")
const Service = preload("res://src/core/save_service.gd")
const SLOT: String = "res://.godot/card025_test_slot.json"


func _funded() -> SimulationController:
	var game := Controller.new(3025)
	var pile: PileState = game.run.colony.piles.home
	pile.deposit_resource("carbohydrate", 90.0)
	pile.deposit_resource("protein", 95.0)
	pile.deposit_resource("water", 90.0)
	return game


func run(test: Object) -> bool:
	var game := _funded()
	var pile: PileState = game.run.colony.piles.home
	var initial: Dictionary = game.run.to_dict()
	test.check(not game.start_brood("missing") and game.brood.last_error == "Unknown pile" and game.run.to_dict() == initial, "Unknown pile rejects without mutation")
	test.check(not game.start_brood("home") and game.brood.last_error == "Nursery already has brood" and game.run.to_dict() == initial, "Cannot duplicate the starting cohort")
	game.advance(Config.egg_seconds + Config.larva_seconds + Config.pupa_seconds)
	test.check(pile.brood_cohorts.is_empty() and pile.brood_matured_total == 8 and pile.workers_total == 48 and pile.workers.invariant_holds(), "First cohort emerges before another may start")
	var legacy: Dictionary = game.run.to_dict()
	var legacy_copy := Controller.new()
	test.check(legacy.version == 5 and legacy_copy.restore_snapshot(JSON.parse_string(JSON.stringify(legacy, "", true, true))) and legacy_copy.run.to_dict() == legacy, "Single-cycle version-5 snapshot remains readable")
	var service: SaveService = Service.new(SLOT)
	var disk_copy := Controller.new()
	test.check(service.save(game.run) and service.load_into(disk_copy) and disk_copy.run.to_dict() == legacy, "Existing single-cycle version-5 disk envelope remains loadable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT))
	var forged: Dictionary = legacy.duplicate(true)
	forged.colony.piles[0].brood_matured_total = 16
	test.check(not legacy_copy.restore_snapshot(forged) and legacy_copy.run.to_dict() == legacy, "Emergence count cannot exceed workers added to the home ledger")
	test.check(game.start_brood("home") and pile.brood_cohorts.size() == 1 and pile.brood_cohorts[0].id == "brood_2" and pile.brood_cohorts[0].stage == "egg" and pile.workers_total == 48, "Manual command begins a second aggregate egg cohort")
	var started: Dictionary = game.run.to_dict()
	test.check(not game.start_brood("home") and game.run.to_dict() == started, "Second start while brood is active is atomic")
	game.advance(201.0)
	test.check(pile.brood_cohorts[0].stage == "larva" and pile.brood_cohorts[0].progress_seconds == 21.0, "Second cohort follows existing stage timing")
	var mid: Dictionary = game.run.to_dict()
	var copy := Controller.new()
	test.check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(mid, "", true, true))) and copy.run.to_dict() == mid, "Mid-second-cycle full-precision JSON restores exactly")
	for index: int in 100:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Second-cycle continuation remains exact for 100 ticks")
	var intact: Dictionary = copy.run.to_dict()
	var invalid: Dictionary = mid.duplicate(true)
	invalid.colony.piles[0].brood_cohorts[0].id = "brood_1"
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Wrong sequential cohort ID rejects atomically")
	invalid = mid.duplicate(true)
	invalid.colony.piles[0].brood_matured_total = 9
	test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Non-cohort emergence count rejects atomically")
	game.advance(134.0)
	test.check(pile.brood_cohorts.is_empty() and pile.brood_matured_total == 16 and pile.workers_total == 56 and pile.workers.invariant_holds(), "Second emergence adds eight living workers once through ledger")
	test.check(is_equal_approx(pile.resources.carbohydrate, 71.2) and is_equal_approx(pile.resources.protein, 91.36) and is_equal_approx(pile.resources.water, 85.6), "Two cycles pay the existing larval resource costs")
	game.advance(10.0)
	test.check(pile.workers_total == 56 and pile.brood_matured_total == 16, "Extra ticks cannot duplicate emergence")
	test.check(game.start_brood("home") and pile.brood_cohorts[0].id == "brood_3", "Third cycle receives a distinct ID")
	_test_growth_gates(test)
	_test_inward_action(test)
	return true


func _test_growth_gates(test: Object) -> void:
	var game := _funded()
	var pile: PileState = game.run.colony.piles.home
	game.advance(360.0)
	pile.queen_count = 0
	var before: Dictionary = game.run.to_dict()
	test.check(not game.start_brood("home") and game.brood.last_error == "No queen in pile" and game.run.to_dict() == before, "Pile without a queen cannot begin another cycle")
	pile.queen_count = 1
	test.check(game.start_brood("home"), "Queen begins a repeat cohort")
	test.check(pile.workers.create_commitment("test:busy", "other", "test") and pile.workers.allocate("test:busy", 47), "Care fixture leaves one available worker")
	game.advance(10.0)
	test.check(pile.brood_cohorts[0].stage == "egg" and pile.brood_cohorts[0].progress_seconds == 0.0 and pile.brood_cohorts[0].care < 1.0, "Second-cycle egg waits for worker care")
	test.check(pile.workers.release("test:busy", 47) and pile.workers.retire_commitment("test:busy"), "Care labor returns through ledger")
	test.check(pile.consume_resources(pile.resources.duplicate()), "Food shortage fixture empties all stores")
	game.advance(Config.egg_seconds + 1.0)
	test.check(pile.brood_cohorts[0].stage == "larva" and pile.brood_cohorts[0].progress_seconds == 0.0 and pile.brood_cohorts[0].nutrition == 0.0, "Second-cycle larva waits for nutrition")
	for category: String in PileState.RESOURCE_IDS:
		pile.deposit_resource(category, 20.0)
	game.advance(Config.larva_seconds + Config.pupa_seconds)
	test.check(pile.brood_matured_total == 16 and pile.workers_total == 56 and pile.workers.invariant_holds(), "Restored care and food complete the repeat cycle")


func _test_inward_action(test: Object) -> void:
	var root := Root.new()
	root.simulation = _funded()
	var pile: PileState = root.simulation.run.colony.piles.home
	root.simulation.advance(360.0)
	var ui: InwardView = View.new()
	test.get_root().add_child(ui)
	ui.selected_id = "nursery"
	ui._status = root.inward_status("home")
	ui.brood_command = root.start_brood
	var no_queen: Dictionary = ui._status.duplicate(true)
	no_queen.queens = 0
	ui._status = no_queen
	test.check(not ui.activate_at(ui._brood_rect().get_center()) and pile.brood_cohorts.is_empty(), "INWARD hides the brood action without a queen")
	ui._status = root.inward_status("home")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = ui._brood_rect().get_center()
	ui._unhandled_input(touch)
	test.check(pile.brood_cohorts.size() == 1 and pile.brood_cohorts[0].id == "brood_2" and ui._feedback == "New brood started", "Nursery touch action sends semantic brood command")
	root.simulation.advance(360.0)
	ui.selected_id = "queen"
	ui._status = root.inward_status("home")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = ui._brood_rect().get_center()
	ui._unhandled_input(mouse)
	test.check(pile.brood_cohorts.size() == 1 and pile.brood_cohorts[0].id == "brood_3", "Queen mouse action shares the same semantic path")
	test.check(ui._brood_rect().size == Vector2(260, 44), "Repeat-brood action has a touch-sized target")
	ui.free()
	root.free()
