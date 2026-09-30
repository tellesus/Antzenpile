extends Node

const Controller = preload("res://src/core/simulation_controller.gd")
const Perception = preload("res://src/presentation/perception_model.gd")
var simulation: SimulationController
var perception: PerceptionModel = Perception.new()


func _ready() -> void:
	simulation = Controller.new()
	if OS.is_debug_build():
		print("[RUN] seed=%d scenario=%s time=%.2f" % [simulation.run.run_seed, simulation.run.scenario_id, simulation.run.simulation_time])
	# Lazy load keeps truth-view code out of the headless runtime and release input path.
	if OS.is_debug_build() and DisplayServer.get_name() != "headless":
		var debug_view: Node = load("res://src/debug/debug_world_view.gd").new()
		debug_view.snapshot_provider = simulation.run.to_dict
		debug_view.signal_provider = sensory_snapshot.bind("home")
		debug_view.dispatch_command = simulation.dispatch_scout.bind("home")
		add_child(debug_view)


func _process(delta: float) -> void:
	simulation.advance(delta)


func sensory_snapshot(pile_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not simulation.run.colony.piles.has(pile_id):
		return result
	var origin: Vector2 = simulation.run.colony.piles[pile_id].position
	for signal_data: PerceivedSignal in perception.project(simulation.run.knowledge.nodes.values(), origin, simulation.run.simulation_time):
		result.append(signal_data.to_dict())
	return result
