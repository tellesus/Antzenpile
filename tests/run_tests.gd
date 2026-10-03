extends SceneTree
## Small explicit suite registry. Run with --headless --path . --script res://tests/run_tests.gd.

const SUITES: Array[Script] = [
	preload("res://tests/test_reproduction.gd"),
	preload("res://tests/test_founding.gd"),
	preload("res://tests/test_nest_sites.gd"),
	preload("res://tests/test_hot_dry_ecology.gd"),
	preload("res://tests/test_nursery_heat.gd"),
	preload("res://tests/test_brood_health.gd"),
	preload("res://tests/test_scout_caution.gd"),
	preload("res://tests/test_scout_survival.gd"),
	preload("res://tests/test_adaptation_queue.gd"),
	preload("res://tests/test_chamber_art.gd"),
	preload("res://tests/test_interface_navigation.gd"),
	preload("res://tests/test_interface_guidance.gd"),
	preload("res://tests/test_interface_panels.gd"),
	preload("res://tests/test_journey_investigation.gd"),
	preload("res://tests/test_ambusher_defense.gd"),
	preload("res://tests/test_sensory_captions.gd"),
	preload("res://tests/test_supply_receipts.gd"),
	preload("res://tests/test_food_contamination.gd"),
	preload("res://tests/test_standing_brood.gd"),
	preload("res://tests/test_bootstrap.gd"),
	preload("res://tests/test_simulation_clock.gd"),
	preload("res://tests/test_run_state.gd"),
	preload("res://tests/test_world.gd"),
	preload("res://tests/test_worker_ledger.gd"),
	preload("res://tests/test_worker_mortality.gd"),
	preload("res://tests/test_debug_world.gd"),
	preload("res://tests/test_scouting.gd"),
	preload("res://tests/test_scout_mission_memory.gd"),
	preload("res://tests/test_persistent_scout.gd"),
	preload("res://tests/test_observations.gd"),
	preload("res://tests/test_knowledge.gd"),
	preload("res://tests/test_perception.gd"),
	preload("res://tests/test_outward.gd"),
	preload("res://tests/test_trails.gd"),
	preload("res://tests/test_transit.gd"),
	preload("res://tests/test_route_energy.gd"),
	preload("res://tests/test_pheromone.gd"),
	preload("res://tests/test_familiarity.gd"),
	preload("res://tests/test_brood.gd"),
	preload("res://tests/test_repeat_brood.gd"),
	preload("res://tests/test_nursery_capacity.gd"),
	preload("res://tests/test_nursery_development.gd"),
	preload("res://tests/test_inward.gd"),
	preload("res://tests/test_food_exchange.gd"),
	preload("res://tests/test_music.gd"),
	preload("res://tests/test_sensory_art.gd"),
	preload("res://tests/test_rain.gd"),
	preload("res://tests/test_recurring_rain.gd"),
	preload("res://tests/test_rain_fed_water.gd"),
	preload("res://tests/test_ecology.gd"),
	preload("res://tests/test_honeydew.gd"),
	preload("res://tests/test_predator.gd"),
	preload("res://tests/test_returned_loss_evidence.gd"),
	preload("res://tests/test_rival_contact.gd"),
	preload("res://tests/test_swarm.gd"),
	preload("res://tests/test_guest.gd"),
	preload("res://tests/test_ecology_integration.gd"),
	preload("res://tests/test_adaptation_web.gd"),
	preload("res://tests/test_honeydew_controls.gd"),
	preload("res://tests/test_temporary_resource.gd"),
	preload("res://tests/test_recurrence_evidence.gd"),
	preload("res://tests/test_save_load.gd"),
	preload("res://tests/test_slice_integration.gd"),
	preload("res://tests/test_extended_slice.gd"),
	preload("res://tests/test_post_slice_integration.gd"),
	preload("res://tests/test_trail_side_discovery.gd"),
	preload("res://tests/test_adaptation.gd"),
	preload("res://tests/test_genetic_repertoire.gd"),
	preload("res://tests/test_persistent_chemistry.gd"),
	preload("res://tests/test_recognition.gd"),
	preload("res://tests/test_guest_recurrence.gd"),
	preload("res://tests/test_standing_exploration.gd"),
	preload("res://tests/test_collective_search.gd"),
	preload("res://tests/test_trail_exploration.gd"),
	preload("res://tests/test_source_recovery.gd"),
	preload("res://tests/test_sanitation.gd"),
	preload("res://tests/test_source_memory.gd"),
	preload("res://tests/test_humidity.gd"),
	preload("res://tests/test_colony_activity.gd"),
	preload("res://tests/test_chamber_music.gd"),
	preload("res://tests/test_audio_preferences.gd"),
	preload("res://tests/test_new_colony.gd"),
	preload("res://tests/test_scenarios.gd"),
	preload("res://tests/test_returned_discovery.gd"),
	preload("res://tests/test_colony_guide.gd"),
	preload("res://tests/test_functional_art.gd"),
	preload("res://tests/test_scout_captions.gd"),
	preload("res://tests/test_pressure_attention.gd"),
	preload("res://tests/test_nursery_expansion.gd"),
	preload("res://tests/test_nutrition_clarity.gd"),
]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	# Defer until the tree is ready so scene smoke checks can use the root.
	_run.call_deferred()


func _run() -> void:
	for suite_script: Script in SUITES:
		var suite: RefCounted = suite_script.new()
		check(suite.run(self) == true, "Suite completed: " + suite_script.resource_path)
	print("Tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 and checks > 0 else 1)


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
