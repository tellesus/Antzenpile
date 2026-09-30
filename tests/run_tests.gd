extends SceneTree
## Small explicit suite registry. Run with --headless --path . --script res://tests/run_tests.gd.

const SUITES: Array[Script] = [
	preload("res://tests/test_bootstrap.gd"),
	preload("res://tests/test_simulation_clock.gd"),
	preload("res://tests/test_run_state.gd"),
	preload("res://tests/test_world.gd"),
	preload("res://tests/test_worker_ledger.gd"),
	preload("res://tests/test_debug_world.gd"),
	preload("res://tests/test_scouting.gd"),
	preload("res://tests/test_observations.gd"),
	preload("res://tests/test_knowledge.gd"),
	preload("res://tests/test_perception.gd"),
	preload("res://tests/test_outward.gd"),
	preload("res://tests/test_trails.gd"),
	preload("res://tests/test_transit.gd"),
	preload("res://tests/test_pheromone.gd"),
	preload("res://tests/test_familiarity.gd"),
	preload("res://tests/test_brood.gd"),
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
