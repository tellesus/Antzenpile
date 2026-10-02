extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Cohort = preload("res://src/sim/colony/brood_cohort.gd")
const Pressure = preload("res://src/presentation/colony_pressure.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")

func hungry(ids: Array[String]) -> SimulationController:
	var game := Controller.new(78)
	var pile: PileState = game.run.colony.piles.home
	pile.brood_cohorts[0].stage = "larva" # Isolate the existing feeding step without waiting through eggs.
	for id: String in ids: pile.resources[id] = 0
	game.advance(0.25)
	return game

func run(test: Object) -> bool:
	for id: String in Cohort.RESOURCE_IDS:
		var game: SimulationController = hungry([id])
		var pile: PileState = game.run.colony.piles.home
		var cohort: BroodCohort = pile.brood_cohorts[0]
		test.check(cohort.nutrition_shortfalls == [id] and cohort.progress_seconds == 0 and cohort.care == 1.0 and cohort.nutrition == 0.0, "Failed feeding identifies only missing " + id + " without progress")
		test.check(pile.resources == {"carbohydrate": 0.0 if id == "carbohydrate" else 10.0, "protein": 0.0 if id == "protein" else 5.0, "water": 0.0 if id == "water" else 10.0}, "Failed feeding leaves all other food unspent")
		var root := Root.new(); root.simulation = game
		test.check(Pressure.food_shortages(root.inward_status("home")) == [id], "Normal presentation receives actual local missing resource")
		root.free()
		pile.deposit_resource(id, 1)
		game.advance(0.25)
		test.check(cohort.nutrition_shortfalls.is_empty() and cohort.nutrition == 1.0 and cohort.progress_seconds == 0.25, "Replenished " + id + " clears diagnosis on next assessment using unchanged progress")
	var game: SimulationController = hungry(Cohort.RESOURCE_IDS)
	var pile: PileState = game.run.colony.piles.home
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Mixed nutrient diagnosis restores exactly")
	game.advance(1); copy.advance(1)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Failed feeding and evidence preserve exact JSON continuation")
	var intact: Dictionary = copy.run.to_dict()
	for bad: String in ["type", "unknown", "duplicate", "care", "nutrition", "stage"]:
		var invalid: Dictionary = saved.duplicate(true)
		var record: Dictionary = invalid.colony.piles[0].brood_cohorts[0]
		match bad:
			"type": record.nutrition_shortfalls = "water"
			"unknown": record.nutrition_shortfalls = ["disease"]
			"duplicate": record.nutrition_shortfalls = ["water", "water"]
			"care": record.care = 0.5
			"nutrition": record.nutrition = 1.0
			"stage": record.stage = "egg"
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == intact, "Invalid " + bad + " feeding diagnosis rejects atomically")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.colony.piles[0].brood_cohorts[0].erase("nutrition_shortfalls")
	test.check(copy.restore_snapshot(legacy) and copy.run.colony.piles.home.brood_cohorts[0].nutrition_shortfalls.is_empty(), "Old shortage saves supply no invented specific diagnosis")
	var root := Root.new(); root.simulation = copy
	test.check(Pressure.nursery_causes(root.inward_status("home")) == ["FOOD"], "Legacy unclassified food shortage remains qualitative until assessed")
	root.free()
	pile.workers.create_commitment("test:care", "other", "care")
	pile.workers.allocate("test:care", 39)
	game.advance(0.25)
	root = Root.new(); root.simulation = game
	test.check(pile.brood_cohorts[0].nutrition_shortfalls.is_empty() and Pressure.nursery_causes(root.inward_status("home")) == ["CARE"], "Insufficient care leaves feeding unassessed rather than inventing simultaneous food failure")
	root.free()
	_test_attention(test)
	return true

func _test_attention(test: Object) -> void:
	var root := Root.new()
	test.get_root().add_child(root)
	root.set_process(false)
	root.simulation = hungry(["carbohydrate"])
	root.simulation.toggle_pause()
	var inward := View.new()
	root.add_child(inward); root._inward_view = inward
	inward.status_provider = root.inward_status.bind("home")
	inward.food_sources_command = root.browse_food_sources
	var outward := Outward.new()
	root.add_child(outward); root._outward_view = outward
	outward.signal_provider = root.sensory_snapshot.bind("home")
	outward.status_provider = root.outward_status.bind("home")
	outward.facing = 0.8; outward.selected_id = "remembered"
	root.set_mode("inward"); inward.selected_id = "food_exchange"; inward._process(0)
	var before: Dictionary = root.simulation.run.to_dict()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true; touch.position = inward._food_source_rect("carbohydrate").get_center()
	inward._unhandled_input(touch)
	test.check(root.mode == "outward" and outward.sources_open and outward.source_category == "carbohydrate" and outward._signals.is_empty(), "Touch opens only returned memories for the needed food, even when none are known")
	test.check(root.simulation.run.to_dict() == before and outward.facing == 0.8 and outward.selected_id == "remembered", "Browsing neither dispatches/steers nor mutates clock, workers or RNG")
	root.set_mode("inward")
	inward.input_blocked = func() -> bool: return true
	inward._unhandled_input(touch)
	test.check(root.mode == "inward", "Modal shield blocks food-source attention")
	inward.input_blocked = Callable()
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true; mouse.button_index = MOUSE_BUTTON_LEFT; mouse.position = touch.position
	inward._unhandled_input(mouse)
	test.check(root.mode == "outward" and root.simulation.run.to_dict() == before, "Mouse shares the same free source attention path")
	root.set_mode("inward")
	root.simulation.run.colony.piles.home.deposit_resource("carbohydrate", 1)
	root.simulation.toggle_pause(); root.simulation.advance(0.25); root.simulation.toggle_pause()
	before = root.simulation.run.to_dict()
	inward._unhandled_input(mouse)
	test.check(root.mode == "inward" and root.simulation.run.to_dict() == before and not root.browse_food_sources("poison").accepted, "Stale or invalid resource attention revalidates without changing mode or simulation")
	test.check(not inward._food_source_rect("carbohydrate").intersects(inward._develop_rect()) and not inward._food_source_rect("water").intersects(inward._button_rect("pause")) and inward._food_source_rect("water").size.y == 44, "Food browsing targets remain separate from development and clock controls")
	root.free()
