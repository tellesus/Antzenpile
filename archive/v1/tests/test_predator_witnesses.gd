extends RefCounted
const Survey = preload("res://tests/test_journey_investigation.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Popover = preload("res://src/presentation/outward/conflict_popover.gd")
const Memory = preload("res://src/presentation/outward/source_memory.gd")

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))

func run(test: Object) -> bool:
	var game: SimulationController = Survey.new().investigated_game()
	var root := Root.new(); root.simulation = game
	var popover := Popover.new()
	var route: Dictionary = root.trail_summaries("home")[0]
	test.check(game.run.predator.profile_id == "wolf_spider" and PredatorCatalog.definition("wolf_spider").profile_id == "wolf_spider", "Fresh stationary predator uses an authored immutable profile")
	test.check(popover._identity(route, root.outward_status("home")) == "Unidentified threat", "Loss without a surviving survey does not identify predator anatomy")
	test.check(game.journey_response.investigate("route_1"), "Actual returned loss authorizes the ordinary paid survey")
	for step: int in 2000:
		if game.run.journey_response.predator_profile != "": break
		game.advance(0.25)
	test.check(game.run.journey_response.predator_profile == "wolf_spider" and game.run.journey_response.ambush_fraction >= 0, "Physical close survey captures spider outline privately")
	test.check(popover._identity(route, root.outward_status("home")) == "Unidentified threat" and root.outward_status("home").journey_response.reports.is_empty(), "Private outline does not leak during outbound or return travel")
	test.check(not str(root.sensory_snapshot("home")).contains("wolf_spider"), "Cloud snapshots cannot reveal a privately captured spider before return")
	var private_save: Dictionary = snapshot(game)
	var twin := Controller.new()
	test.check(twin.restore_snapshot(private_save) and twin.run.to_dict() == game.run.to_dict(), "Private captured profile restores exactly")
	var legacy: Dictionary = private_save.duplicate(true)
	legacy.predator.erase("profile_id"); legacy.journey_response.erase("predator_profile")
	var old := Controller.new()
	test.check(old.restore_snapshot(legacy) and old.run.predator.profile_id == "", "Old generic physical predator gains no invented type")
	while game.run.journey_response.active():
		game.advance(0.25); twin.advance(0.25); old.advance(0.25)
	test.check(game.run.to_dict() == twin.run.to_dict(), "Actual return and witness journal continue identically after save")
	var report: Dictionary = game.run.journey_response.reports.route_1
	test.check(report.predator_profile == "wolf_spider" and report.observed_at < report.received_at, "Only actual return publishes dated supported identity")
	var impression: Dictionary = {}
	for signal_data: Dictionary in root.sensory_snapshot("home"):
		if signal_data.category == "threat": impression = signal_data
	test.check(impression.get("predator_profile", "") == "wolf_spider" and is_equal_approx(impression.age, game.run.simulation_time - report.observed_at), "Cloud receives only returned identity and its original observation age")
	test.check(popover._identity(route, root.outward_status("home")) == "Spider-like predator" and popover.kind(route, root.outward_status("home")) == "defend", "Supported impression retains Clear/Hunt and force decisions")
	test.check(Memory.survey_label(report).contains("Spider-like") and not str(root.outward_status("satellite_1").get("journey_response", {})).contains("wolf_spider"), "Witness copy uses supported outline and stays owned by its observing pile")
	test.check(old.run.journey_response.reports.route_1.get("predator_profile", "") == "" and Memory.survey_label(old.run.journey_response.reports.route_1) == "Predator witnessed", "Old generic survey remains generic after actual delivery")
	var journal_found: bool = false
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind == "survey":
			journal_found = entry.detail == "ambush:wolf_spider" and ReportCopy.title(entry, root.outward_status("home")).contains("Spider-like")
	test.check(journal_found, "Retained Reports preserves original witnessed type rather than current hidden identity")
	var delivered: Dictionary = snapshot(game)
	test.check(twin.restore_snapshot(delivered), "Delivered typed report and journal restore")
	for field: String in ["unknown", "private_without_sighting", "physical_mismatch", "early_witness", "unsupported_report", "extra_report", "invalid_journal"]:
		var invalid: Dictionary = (private_save if field in ["unknown", "private_without_sighting"] else delivered).duplicate(true)
		match field:
			"unknown": invalid.predator.profile_id = "imaginary_monster"
			"private_without_sighting": invalid.journey_response.ambush_fraction = -1; invalid.journey_response.sampled_at = 0
			"physical_mismatch": invalid.predator.profile_id = ""
			"early_witness": invalid.journey_response.reports.route_1.observed_at = 1
			"unsupported_report": invalid.journey_response.reports.route_1.finding = "foreign"; invalid.journey_response.reports.route_1.fraction = -1
			"extra_report": invalid.journey_response.reports.route_1.health = 99
			"invalid_journal":
				for index: int in invalid.reports.records.size():
					var entry: Dictionary = JSON.parse_string(invalid.reports.records[index])
					if entry.kind == "survey": entry.detail = "surface:wolf_spider"; invalid.reports.records[index] = JSON.stringify(entry, "", true, true)
		var unchanged: Dictionary = twin.run.to_dict()
		test.check(not twin.restore_snapshot(invalid) and twin.run.to_dict() == unchanged, "Malformed/unsupported witness rejects atomically: " + field)
	for speed: int in [1, 4, 16, 64]:
		var paced := Controller.new(); var reference := Controller.new()
		paced.restore_snapshot(private_save); reference.restore_snapshot(private_save)
		paced.set_time_scale(speed); paced.advance(40.0 / speed); paced.set_time_scale(1); reference.advance(40)
		test.check(paced.run.to_dict() == reference.run.to_dict(), "Witness/return boundary matches at speed " + str(speed))
	game.toggle_pause(); var frozen: Dictionary = game.run.to_dict(); game.advance(60)
	test.check(game.run.to_dict() == frozen, "Pause cannot strengthen predator recognition")
	root.free()
	return true
