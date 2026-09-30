extends Node

const Controller = preload("res://src/core/simulation_controller.gd")
const Perception = preload("res://src/presentation/perception_model.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
var simulation: SimulationController
var perception: PerceptionModel = Perception.new()
var _debug_view: Node


func _ready() -> void:
	simulation = Controller.new()
	if OS.is_debug_build():
		print("[RUN] seed=%d scenario=%s time=%.2f" % [simulation.run.run_seed, simulation.run.scenario_id, simulation.run.simulation_time])
	if DisplayServer.get_name() != "headless":
		var outward: OutwardView = Outward.new()
		outward.signal_provider = sensory_snapshot.bind("home")
		outward.status_provider = outward_status.bind("home")
		outward.dispatch_command = dispatch_facing
		outward.pause_command = simulation.toggle_pause
		outward.speed_command = simulation.set_time_scale
		outward.trail_create_command = create_trail_for
		outward.trail_set_command = set_trail_target
		outward.input_blocked = debug_is_open
		add_child(outward)
	# Lazy load keeps truth-view code out of the headless runtime and release input path.
	if OS.is_debug_build() and DisplayServer.get_name() != "headless":
		_debug_view = load("res://src/debug/debug_world_view.gd").new()
		_debug_view.snapshot_provider = simulation.run.to_dict
		_debug_view.signal_provider = sensory_snapshot.bind("home")
		_debug_view.dispatch_command = simulation.dispatch_scout.bind("home")
		add_child(_debug_view)


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


func outward_status(pile_id: String) -> Dictionary:
	if not simulation.run.colony.piles.has(pile_id):
		return {}
	return {"available_workers": simulation.run.colony.piles[pile_id].workers_available,
		"active_scouts": simulation.run.scouts.size(), "scout_cap": simulation.scouting.config.active_cap,
		"time": simulation.run.simulation_time, "paused": simulation.run.clock.paused,
		"time_scale": simulation.run.clock.time_scale, "trails": trail_summaries(pile_id),
		"resources": simulation.run.colony.piles[pile_id].resources.duplicate()}


func trail_summaries(pile_id: String) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for route: TrailRouteState in simulation.run.trails.routes.values():
		if route.origin_pile == pile_id:
			var segment: TrailSegmentState = simulation.run.trails.segments[route.segment_id]
			summaries.append({"id": route.id, "destination_knowledge_id": route.destination_knowledge_id,
				"desired_workers": route.desired_workers, "allocated_workers": route.allocated_workers,
				"active_workers": route.active_workers, "status": route.status,
				"delivered_total": route.delivered_total,
				"pheromone_strength": segment.pheromone_strength,
				"route_familiarity": segment.route_familiarity})
	summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return summaries


func create_trail_for(knowledge_id: String) -> Dictionary:
	var accepted: bool = simulation.create_trail("home", knowledge_id)
	return {"accepted": accepted, "reason": simulation.trails.last_error}


func set_trail_target(route_id: String, target: int) -> Dictionary:
	var accepted: bool = simulation.set_trail_workers(route_id, target)
	return {"accepted": accepted, "reason": simulation.trails.last_error}


func dispatch_facing(bearing: float) -> bool:
	return simulation.dispatch_scout("home", bearing)


func debug_is_open() -> bool:
	return _debug_view != null and _debug_view.visible
