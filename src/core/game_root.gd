extends Node

const Controller = preload("res://src/core/simulation_controller.gd")
var simulation: SimulationController


func _ready() -> void:
	simulation = Controller.new()
	if OS.is_debug_build():
		print("[RUN] seed=%d scenario=%s time=%.2f" % [simulation.run.run_seed, simulation.run.scenario_id, simulation.run.simulation_time])
	# Lazy load keeps truth-view code out of the headless runtime and release input path.
	if OS.is_debug_build() and DisplayServer.get_name() != "headless":
		var debug_view: Node = load("res://src/debug/debug_world_view.gd").new()
		debug_view.snapshot_provider = simulation.run.to_dict
		debug_view.dispatch_command = simulation.dispatch_scout.bind("home")
		add_child(debug_view)


func _process(delta: float) -> void:
	simulation.advance(delta)
