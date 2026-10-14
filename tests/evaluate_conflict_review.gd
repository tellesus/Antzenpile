extends SceneTree
## Review evidence: decisions use delivered/local facts; private state is measured only afterward.
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const GuestFixture = preload("res://tests/test_guest.gd")
const SurveyFixture = preload("res://tests/test_journey_investigation.gd")
const Pressure = preload("res://src/presentation/colony_pressure.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func save_file(name: String, value: Variant) -> void:
	var file := FileAccess.open("res://.godot/card118_" + name + ".json", FileAccess.WRITE)
	check(file != null, "Writable review evidence: " + name)
	if file != null: file.store_string(JSON.stringify(value, "\t", true, true))

func restore(saved: Dictionary) -> SimulationController:
	var game := Controller.new()
	check(game.restore_snapshot(saved), "Review branch restores")
	return game

func _run() -> void:
	var rival_records: Array[Dictionary] = []
	var initial: SimulationController
	for seed_value: int in [3048,3030,482817]:
		initial = Controller.new(seed_value)
		check(initial.dispatch_scout("home",0.0), "Directional rival-source search")
		initial.advance(670.0)
		if not initial.run.knowledge.nodes.has("known:carb_exposed"):
			initial.set_exploration(5); initial.set_exploration_bias(0.0)
			for tick: int in 2400:
				if initial.run.knowledge.nodes.has("known:carb_exposed"): break
				initial.advance(0.25)
			initial.set_exploration(0)
		check(initial.create_trail("home","known:carb_exposed"), "Returned source funds rival crossing")
		for tick: int in 1600:
			if initial.run.trails.routes.route_1.conflict_report == "contested": break
			initial.advance(0.25)
		check(initial.run.trails.routes.route_1.conflict_report == "contested", "Actual messenger delivers rival warning")
		var rival_save: Dictionary = GuestFixture.new().snapshot(initial)
		if seed_value == 3048: save_file("rival_warning", rival_save)
		for action: String in ["unchanged", "reinforce", "reinforce_twice", "reinforce_three", "withdraw"]:
			var game := restore(rival_save)
			var root := Root.new(); root.simulation = game
			var route: TrailRouteState = game.run.trails.routes.route_1
			var before_losses: int = route.reported_rival_losses
			var started: float = game.run.simulation_time
			var cargo: float = route.delivered_total
			var assigned_before: int = route.allocated_workers
			if action != "unchanged":
				var target: int = 0 if action == "withdraw" else 17 if action == "reinforce_three" else 13 if action == "reinforce_twice" else 9
				check(root.set_trail_target(route.id, target).accepted, "Returned warning permits " + action)
			var assigned_on_command: int = route.allocated_workers
			var copy := restore(GuestFixture.new().snapshot(game))
			var changes: Array[Dictionary] = []
			var last: String = "contested"
			for tick: int in 2400:
				game.advance(0.25); copy.advance(0.25)
				if route.conflict_report != last:
					last = route.conflict_report
					changes.append({"elapsed":game.run.simulation_time-started,"report":last,"losses":route.reported_rival_losses,"swarm_serial":game.run.swarm.serial})
				if seed_value == 3048 and action == "reinforce" and tick == 399: save_file("rival_after_response", GuestFixture.new().snapshot(game))
				if seed_value == 3048 and action == "reinforce_three" and tick == 479: save_file("rival_heavy_response", GuestFixture.new().snapshot(game))
			check(game.run.to_dict() == copy.run.to_dict(), "Exact rival continuation: " + action)
			check(game.run.colony.piles.home.workers.invariant_holds() and game.run.rival.workers.invariant_holds(), "Both conflict ledgers conserve: " + action)
			rival_records.append({"action":action,"seed":seed_value,"duration":600,"initial_time":started,"initial_private_losses":initial.run.colony.piles.home.workers.lost_total,"returned_losses":route.reported_rival_losses-before_losses,"net_cargo":route.delivered_total-cargo,"target":route.desired_workers,"assigned":route.allocated_workers,"assigned_before_command":assigned_before,"assigned_on_command":assigned_on_command,"reports":changes,"swarm_serial":game.run.swarm.serial,"rival_remaining":game.run.rival.workers.count("rival:trail"),"summary":root.trail_summaries("home")})
			if action == "withdraw": check(route.allocated_workers == 0 and route.conflict_report == "withdrew", "Withdrawal has returned closure")
			root.free()
	var guest_records: Array[Dictionary] = []
	initial = GuestFixture.new().loss_fixture(); initial.advance(0.25)
	check(initial.run.guest.observation == "loss", "First local symptom permits response without identifying the private species")
	var guest_save: Dictionary = GuestFixture.new().snapshot(initial)
	save_file("guest_warning", guest_save)
	for action: String in ["prompt", "delayed", "untreated"]:
		var game := restore(guest_save)
		var root := Root.new(); root.simulation = game
		var started: float = game.run.simulation_time
		var warning_attention: Dictionary = root.outward_status("home").internal_attention
		var without_guest: Dictionary = root.inward_status("home").duplicate(true)
		without_guest.erase("guest")
		var guest_affects_attention: bool = warning_attention != Pressure.attention(without_guest)
		if action == "prompt": check(root.set_guest_rejection(true).accepted, "Prompt symptom response uses real local workers")
		var copy := restore(GuestFixture.new().snapshot(game))
		var returned_at: float = -1.0
		var foreign_attention: Dictionary = {}
		for tick: int in 1040:
			if action == "delayed" and tick == 240:
				check(root.guest_summary("home").observation == "foreign", "Delayed response waits for repeated local evidence")
				save_file("guest_foreign", GuestFixture.new().snapshot(game))
				foreign_attention = root.outward_status("home").internal_attention
				check(root.set_guest_rejection(true).accepted and copy.start_guest_rejection(), "Both delayed branches reject with matching commands")
			game.advance(0.25); copy.advance(0.25)
			if returned_at < 0.0 and root.guest_summary("home").observation == "purged": returned_at = game.run.simulation_time-started
		check(game.run.to_dict() == copy.run.to_dict(), "Exact guest continuation: " + action)
		check(game.run.colony.piles.home.workers.invariant_holds(), "Guest labor conserves: " + action)
		if action == "prompt": save_file("guest_purged", GuestFixture.new().snapshot(game))
		guest_records.append({"action":action,"seed":5050,"initial_time":started,"duration":260,"total_encounter_losses":root.guest_summary("home").reported_losses,"cleared_after":returned_at,"warning_attention":warning_attention,"foreign_attention":foreign_attention,"guest_affects_attention":guest_affects_attention,"guest":root.guest_summary("home"),"alarm_count":root.returned_losses("home")})
		root.free()
	# Ordinary exploration, returned loss, paid survey and delivered intervention checkpoints.
	var survey: SimulationController = SurveyFixture.new().investigated_game(3043)
	save_file("ambush_losses", GuestFixture.new().snapshot(survey))
	var root := Root.new(); root.simulation = survey
	check(root.respond_to_journey("investigate", "route_1").accepted, "Returned harvest loss permits paid survey")
	while survey.run.journey_response.active(): survey.advance(0.25)
	save_file("ambush_survey", GuestFixture.new().snapshot(survey))
	check(root.respond_to_journey("defend", "route_1").accepted, "Returned localization permits paid defense")
	save_file("ambush_away", GuestFixture.new().snapshot(survey))
	var reinforcement_copy := restore(GuestFixture.new().snapshot(survey))
	var reinforcement_root := Root.new(); reinforcement_root.simulation = reinforcement_copy
	check(reinforcement_root.respond_to_journey("reinforce","route_1").accepted, "Known reinforcement dispatch commits four real workers")
	var pending_offer: bool = reinforcement_root.outward_status("home").journey_response.reinforcement_available
	var duplicate: Dictionary = reinforcement_root.respond_to_journey("reinforce","route_1")
	check(not duplicate.accepted, "Already traveling batch prevents duplicate dispatch")
	save_file("ambush_pending", GuestFixture.new().snapshot(reinforcement_copy))
	reinforcement_root.free()
	while survey.run.journey_response.active(): survey.advance(0.25)
	save_file("ambush_secured", GuestFixture.new().snapshot(survey))
	check(root.outward_status("home").journey_response.outcomes.route_1.outcome == "secured", "Defense closes through returned evidence")
	root.free()
	save_file("review", {"rival":rival_records,"guest":guest_records,"pending_reinforcement_offered":pending_offer,"duplicate_reinforcement_result":duplicate,"checks":checks+1,"failures":failures})
	print("[CONFLICT-REVIEW] rival trials=", rival_records.size(), " guest trials=", guest_records.size(), " checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
