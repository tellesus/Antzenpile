extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Config = preload("res://data/resources/default_food_exchange.tres")


func _funded() -> SimulationController:
	var game := Controller.new()
	game.run.colony.piles.home.deposit_resource("carbohydrate", 2.0)
	return game


func run(test: Object) -> bool:
	var game := Controller.new()
	var pile: PileState = game.run.colony.piles.home
	var before: Dictionary = game.run.to_dict()
	test.check(not game.start_food_exchange("home") and game.run.to_dict() == before and not game.food_exchange.last_error.is_empty(), "Initial carbohydrate shortage rejects without cost or labor transfer")
	game = _funded()
	pile = game.run.colony.piles.home
	test.check(pile.workers.create_commitment("test:busy", "other", "test") and pile.workers.allocate("test:busy", 37), "Labor shortage fixture leaves three workers")
	before = game.run.to_dict()
	test.check(not game.start_food_exchange("home") and game.run.to_dict() == before, "Insufficient available labor rejects atomically")
	test.check(pile.workers.release("test:busy", 37) and pile.workers.retire_commitment("test:busy"), "Fixture labor released through ledger")
	var events: Array[String] = []
	game.food_exchange.chamber_online.connect(func(id: String) -> void: events.append(id))
	test.check(game.start_food_exchange("home"), "Paid Primitive development starts")
	test.check(pile.food_exchange_state == "developing" and pile.food_exchange_progress_seconds == 0.0 and pile.workers.count("food_exchange:home") == 4 and pile.workers_available == 36 and pile.resources == {"carbohydrate": 0.0, "protein": 1.0, "water": 6.0}, "Start debits exact cost and commits four workers once")
	test.check(not game.start_food_exchange("home") and pile.workers.count("food_exchange:home") == 4, "Repeated start cannot duplicate commitment or cost")
	game.advance(59.75)
	test.check(pile.food_exchange_state == "developing" and pile.food_exchange_progress_seconds == 59.75 and events.is_empty(), "Development follows fixed simulated time")
	var mid: Dictionary = game.run.to_dict()
	var restored := Controller.new()
	test.check(mid.version == RunState.SNAPSHOT_VERSION and restored.run.restore(JSON.parse_string(JSON.stringify(mid, "", true, true))) and restored.run.to_dict() == mid, "Mid-build current JSON snapshot restores commitment and progress")
	game.advance(0.25)
	test.check(pile.food_exchange_state == "developed" and pile.food_exchange_progress_seconds == Config.build_seconds and pile.workers.count("food_exchange:home") == -1 and pile.workers_available == 40 and pile.workers.invariant_holds() and events == ["home"], "Completion releases labor and emits chamber_online exactly once")
	game.advance(120.0)
	test.check(events == ["home"] and pile.workers_available == 40, "Repeated ticks do not re-emit or recreate labor")
	var restored_events: Array[String] = []
	restored.food_exchange.chamber_online.connect(func(id: String) -> void: restored_events.append(id))
	restored.advance(0.25)
	test.check(restored.run.colony.piles.home.food_exchange_state == "developed" and restored_events == ["home"], "Mid-build reload completes once")
	restored.advance(100.0)
	test.check(restored_events == ["home"], "Reloaded completed chamber cannot re-emit")
	var primitive := Controller.new()
	var developed := _funded()
	test.check(developed.start_food_exchange("home"), "Benefit fixture develops through normal command")
	developed.advance(Config.build_seconds)
	primitive.advance(Config.build_seconds)
	for fixture: SimulationController in [primitive, developed]:
		fixture.run.colony.piles.home.resources = {"carbohydrate": 30.0, "protein": 30.0, "water": 30.0}
		fixture.advance(130.0)
	var basic: Dictionary = primitive.run.colony.piles.home.resources
	var efficient: Dictionary = developed.run.colony.piles.home.resources
	test.check(is_equal_approx(30.0 - efficient.carbohydrate, (30.0 - basic.carbohydrate) * 0.75) and is_equal_approx(30.0 - efficient.protein, (30.0 - basic.protein) * 0.75) and is_equal_approx(30.0 - efficient.water, (30.0 - basic.water) * 0.75), "Developed exchange reduces all future larval food debits by 25 percent")
	var invalid: Dictionary = mid.duplicate(true)
	var intact: Dictionary = restored.run.to_dict()
	invalid.colony.piles[0].food_exchange_progress_seconds = 99.0
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == intact, "Impossible build progress rejects atomically")
	invalid = mid.duplicate(true)
	invalid.colony.piles[0].workers.commitments.erase("food_exchange:home")
	invalid.colony.piles[0].workers.available += 4
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == intact, "Developing state without its labor commitment rejects")
	invalid = mid.duplicate(true)
	invalid.colony.piles[0].workers.commitments["food_exchange:other"] = {"kind": "internal", "owner_id": "other", "count": 0}
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == intact, "Orphan development commitment rejects")
	var root := Root.new()
	root.simulation = _funded()
	var ui := View.new()
	test.get_root().add_child(ui)
	ui.selected_id = "food_exchange"
	ui._status = root.inward_status("home")
	ui.develop_command = root.start_food_exchange
	test.check(ui.activate_at(ui._develop_rect().get_center()) and root.simulation.run.colony.piles.home.food_exchange_state == "developing", "INWARD Start control dispatches semantic simulation command")
	var detached: Dictionary = root.inward_status("home")
	detached.food_exchange_costs.carbohydrate = 999.0
	test.check(root.inward_status("home").food_exchange_costs.carbohydrate == Config.carbohydrate_cost, "Requirement summary cannot mutate authored cost")
	ui.free()
	root.free()
	return true
