extends SceneTree
## Unfunded command-policy measurements. Hidden state is read only for metrics/assertions.

const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const SEEDS: Array[int] = [3030, 3043, 482817]
const WINDOW: float = 3600.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var results: Array[Dictionary] = []
	for seed_value: int in SEEDS:
		for choice: String in ["baseline", "security", "tolerance"]:
			results.append(measure(seed_value, choice))
	var label: String = "after" if "after" in OS.get_cmdline_user_args() else "current"
	var file := FileAccess.open("res://.godot/balance_%s.json" % label, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t", true, true))
	print("[BALANCE] wrote nine unfunded runs: .godot/balance_%s.json" % label)
	quit()


func measure(seed_value: int, choice: String) -> Dictionary:
	var root := Root.new()
	root.simulation = Controller.new(seed_value)
	var game: SimulationController = root.simulation
	var pile: PileState = game.run.colony.piles.home
	var marks: Dictionary = {}
	var metrics: Dictionary = {"seed": seed_value, "choice": choice, "marks": marks,
		"protection_worker_seconds": 0.0, "rejection_worker_seconds": 0.0,
		"nutrition_stall_seconds": 0.0, "care_stall_seconds": 0.0,
		"rechecks": 0, "clearing_seconds": [], "samples": []}
	var next_recheck: Dictionary = {}
	var threatened: Dictionary = {}
	var reassigned: bool = false
	var previous_rejecting: bool = false
	var rejection_started: float = 0.0
	for bearing: float in [0.0, PI, PI / 4.0, -PI / 3.0, 2.0]:
		game.dispatch_scout("home", bearing)
	for tick: int in roundi(WINDOW / 0.25):
		var time: float = game.run.simulation_time
		if tick % 20 == 0:
			var inside: Dictionary = root.inward_status("home")
			var outside: Dictionary = root.outward_status("home")
			var known: Array[String] = []
			for signal_data: Dictionary in root.sensory_snapshot("home"):
				known.append(signal_data.source_knowledge_id)
				if not marks.has(signal_data.source_knowledge_id):
					marks[signal_data.source_knowledge_id] = time
			if tick % 480 == 0 and ("known:water_01" not in known or "known:protein_01" not in known):
				for bearing: float in [2.0, 2.3, -0.8, -1.1]:
					game.dispatch_scout("home", bearing)
			var routes: Dictionary = {}
			for route: Dictionary in outside.trails:
				routes[route.destination_knowledge_id] = route
				if route.reported_losses > 0 or route.foreign_reports > 0:
					threatened[route.destination_knowledge_id] = true
					if route.desired_workers > 0:
						game.set_trail_workers(route.id, 0)
				elif route.status == "depleted" and route.active_workers == 0 and time >= next_recheck.get(route.id, 0.0):
					if game.recheck_trail(route.id):
						metrics.rechecks += 1
						next_recheck[route.id] = time + 90.0
			for id: String in ["known:water_01", "known:protein_01", "known:carb_sheltered", "known:aphid_01", "known:carb_exposed", "known:protein_picnic"]:
				if id in known and not routes.has(id) and not threatened.has(id) and game.create_trail("home", id):
					var new_routes: Array[Dictionary] = root.trail_summaries("home")
					for route: Dictionary in new_routes:
						if route.destination_knowledge_id == id:
							game.set_trail_workers(route.id, 3)
			var partner: Dictionary = outside.honeydew
			if partner.get("relationship") == "exploited" and game.start_honeydew_tending("home"):
				marks.get_or_add("protection", time)
			if not reassigned and inside.adaptation_options.get(choice, {}).get("inherited", false) and partner.get("relationship") == "tended":
				game.stop_honeydew_tending("home")
				game.start_honeydew_tending("home")
				reassigned = true
			var guest: Dictionary = inside.guest
			if guest.get("observation") == "foreign" and not guest.get("rejection_active", false):
				game.start_guest_rejection()
			if inside.nursery_state == "primitive" and game.start_nursery_development("home"):
				marks.get_or_add("nursery_start", time)
			if inside.food_exchange_state == "primitive" and game.start_food_exchange("home"):
				marks.get_or_add("food_start", time)
			var started: bool = false
			for id: String in ["lean", "persistent", choice]:
				if inside.adaptation_options.get(id, {}).get("available", false) and game.start_adaptation("home", id):
					marks.get_or_add(id + "_trial", time)
					started = true
					break
			if not started and inside.resources.carbohydrate >= 18.0 and inside.resources.protein >= 5.0 and inside.resources.water >= 8.0:
				game.start_brood("home")
			for id: String in ["lean", "persistent", "security", "tolerance"]:
				if inside.adaptation_options.get(id, {}).get("inherited", false):
					marks.get_or_add(id + "_expressed", time)
			if inside.adaptation_options.has("security"):
				marks.get_or_add("recognition_candidate", time)
			if inside.nursery_state == "developed":
				marks.get_or_add("nursery_done", time)
			if inside.food_exchange_state == "developed":
				marks.get_or_add("food_done", time)
		var rejecting: bool = game.run.guest.phase == "rejecting"
		if rejecting and not previous_rejecting:
			rejection_started = time
		if previous_rejecting and not rejecting:
			metrics.clearing_seconds.append(time - rejection_started)
		previous_rejecting = rejecting
		metrics.protection_worker_seconds += game.run.honeydew.protection_workers * 0.25
		metrics.rejection_worker_seconds += maxi(0, pile.workers.count("rejection:home")) * 0.25
		var starving: bool = false
		var uncared: bool = false
		for cohort: BroodCohort in pile.brood_cohorts:
			starving = starving or (cohort.stage == "larva" and cohort.care == 1.0 and cohort.nutrition == 0.0)
			uncared = uncared or cohort.care < 1.0
		metrics.nutrition_stall_seconds += 0.25 if starving else 0.0
		metrics.care_stall_seconds += 0.25 if uncared else 0.0
		game.advance(0.25)
		if tick % 2400 == 2399:
			metrics.samples.append({"time": game.run.simulation_time, "workers": pile.workers_total,
				"stores": pile.resources.duplicate(), "available": pile.workers_available,
				"recognition_share": game.run.recognition_share("home")})
		assert(pile.workers.invariant_holds())
	metrics["workers"] = pile.workers_total
	metrics["adult_losses"] = pile.workers.lost_total
	metrics["brood_losses"] = pile.brood_lost_total
	metrics["stores"] = pile.resources.duplicate()
	metrics["available"] = pile.workers_available
	metrics["recognition_share"] = game.run.recognition_share("home")
	metrics["protection_workers"] = game.run.honeydew.protection_workers
	metrics["gene_counts"] = pile.genetics.living.duplicate()
	metrics["routes"] = root.trail_summaries("home")
	var copy := Controller.new()
	metrics["save_valid"] = copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true)))
	assert(metrics.save_valid)
	print("[BALANCE-RUN] ", seed_value, " ", choice, " workers=", metrics.workers, " losses=", metrics.brood_losses,
		" expression=", metrics.recognition_share, " stalls=", metrics.nutrition_stall_seconds, " clearing=", metrics.clearing_seconds, " stores=", metrics.stores)
	root.free()
	return metrics
