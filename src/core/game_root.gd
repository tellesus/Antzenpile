extends Node

const Controller = preload("res://src/core/simulation_controller.gd")
var simulation: SimulationController


func _ready() -> void:
	simulation = Controller.new()
	if OS.is_debug_build():
		print("[RUN] seed=%d scenario=%s time=%.2f" % [simulation.run.run_seed, simulation.run.scenario_id, simulation.run.simulation_time])


func _process(delta: float) -> void:
	simulation.advance(delta)
