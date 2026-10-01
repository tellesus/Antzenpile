extends Node

const Controller = preload("res://src/core/simulation_controller.gd")
const Perception = preload("res://src/presentation/perception_model.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
const Inward = preload("res://src/presentation/inward/inward_view.gd")
const Audio = preload("res://src/audio/audio_controller.gd")
const Save = preload("res://src/core/save_service.gd")
const FOOD_CONFIG = preload("res://data/resources/default_food_exchange.tres")
const BROOD_CONFIG = preload("res://data/resources/default_brood.tres")
const NURSERY_CONFIG = preload("res://data/resources/default_nursery_development.tres")
var simulation: SimulationController
var perception: PerceptionModel = Perception.new()
var _debug_view: Node
var _outward_view: Node2D
var _inward_view: Node2D
var _audio_controller: AudioController
var save_service: SaveService = Save.new()
var mode: String = "outward"


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
		outward.trail_recheck_command = recheck_trail
		outward.investigate_command = investigate_known_source
		outward.input_blocked = debug_is_open
		outward.mode_command = set_mode.bind("inward")
		outward.save_command = quick_save
		outward.load_command = quick_load
		add_child(outward)
		_outward_view = outward
		var inward: Node2D = Inward.new()
		inward.status_provider = inward_status.bind("home")
		inward.mode_command = set_mode.bind("outward")
		inward.pause_command = simulation.toggle_pause
		inward.speed_command = simulation.set_time_scale
		inward.develop_command = start_food_exchange
		inward.nursery_develop_command = start_nursery_development
		inward.brood_command = start_brood
		inward.adaptation_command = start_adaptation
		inward.input_blocked = debug_is_open
		inward.save_command = quick_save
		inward.load_command = quick_load
		add_child(inward)
		_inward_view = inward
		var audio: AudioController = Audio.new()
		audio.state_provider = music_state.bind("home")
		add_child(audio)
		_audio_controller = audio
		set_mode("outward")
	# Lazy load keeps truth-view code out of the headless runtime and release input path.
	if OS.is_debug_build() and DisplayServer.get_name() != "headless":
		_debug_view = load("res://src/debug/debug_world_view.gd").new()
		_debug_view.snapshot_provider = simulation.run.to_dict
		_debug_view.signal_provider = sensory_snapshot.bind("home")
		_debug_view.dispatch_command = simulation.dispatch_scout.bind("home")
		add_child(_debug_view)


func _process(delta: float) -> void:
	simulation.advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_is_open() and event.is_action_pressed("save_run"):
		_show_save_feedback(quick_save(), "Run saved")
		get_viewport().set_input_as_handled()
		return
	if not debug_is_open() and event.is_action_pressed("load_run"):
		_show_save_feedback(quick_load(), "Run loaded")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_inward") and not debug_is_open():
		set_mode("inward" if mode == "outward" else "outward")
		get_viewport().set_input_as_handled()


func set_mode(next_mode: String) -> bool:
	if not next_mode in ["outward", "inward"]:
		return false
	mode = next_mode
	if _outward_view != null:
		_outward_view.visible = mode == "outward"
		_outward_view.set_process(mode == "outward")
		_outward_view.set_process_unhandled_input(mode == "outward")
	if _inward_view != null:
		_inward_view.visible = mode == "inward"
		_inward_view.set_process(mode == "inward")
		_inward_view.set_process_unhandled_input(mode == "inward")
	return true


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
	var temporal_hints: Dictionary = {}
	for known_id: String in simulation.run.knowledge.nodes:
		temporal_hints[known_id] = simulation.run.knowledge.temporal_hint(known_id)
	return {"available_workers": simulation.run.colony.piles[pile_id].workers_available,
		"active_scouts": simulation.run.active_scout_count(), "scout_cap": simulation.scouting.config.active_cap,
		"time": simulation.run.simulation_time, "paused": simulation.run.clock.paused,
		"time_scale": simulation.run.clock.time_scale, "trails": trail_summaries(pile_id),
		"resources": simulation.run.colony.piles[pile_id].resources.duplicate(),
		"rain_phase": simulation.run.rain.phase, "temporal_hints": temporal_hints}


func inward_status(pile_id: String) -> Dictionary:
	if not simulation.run.colony.piles.has(pile_id):
		return {}
	var pile: PileState = simulation.run.colony.piles[pile_id]
	var brood: Array[Dictionary] = []
	for cohort: BroodCohort in pile.brood_cohorts:
		brood.append(cohort.to_dict())
	var trail_workers: int = 0
	for route: TrailRouteState in simulation.run.trails.routes.values():
		if route.origin_pile == pile_id:
			trail_workers += route.allocated_workers
	return {"pile_id": pile_id, "queens": pile.queen_count,
		"workers_total": pile.workers_total, "workers_available": pile.workers_available,
		"brood": brood, "brood_matured_total": pile.brood_matured_total,
		"adaptation_repertoire": pile.adaptation_repertoire,
		"adaptation_trial": pile.trial_cohort().to_dict() if pile.trial_cohort() != null else {},
		"adapted_workers": pile.adapted_workers_total,
		"adaptation_fraction": pile.adaptation_fraction(),
		"adaptation_costs": AdaptationRules.COSTS.duplicate(),
		"adaptation_nurses": AdaptationRules.NURSES,
		"brood_batch_count": BROOD_CONFIG.starting_count,
		"nursery_state": pile.nursery_state, "nursery_brood_capacity": pile.nursery_brood_capacity(),
		"nursery_occupied_space": pile.nursery_occupied_space(),
		"nursery_care_capacity": pile.nursery_care_capacity(),
		"nursery_max_care_capacity": pile.nursery_max_care_capacity(),
		"nursery_progress": pile.nursery_progress_seconds,
		"nursery_build_duration": NURSERY_CONFIG.build_seconds,
		"nursery_costs": NURSERY_CONFIG.costs(),
		"nursery_workers_required": NURSERY_CONFIG.workers_required,
		"nursery_developed_capacity": BROOD_CONFIG.developed_nursery_brood_capacity,
		"resources": pile.resources.duplicate(), "food_exchange_state": pile.food_exchange_state,
		"food_exchange_progress": pile.food_exchange_progress_seconds,
		"food_exchange_duration": FOOD_CONFIG.build_seconds,
		"food_exchange_costs": FOOD_CONFIG.costs(),
		"food_exchange_workers_required": FOOD_CONFIG.workers_required,
		"food_exchange_food_multiplier": FOOD_CONFIG.developed_larval_food_multiplier,
		"active_scouts": simulation.run.scouts.size(), "trail_workers": trail_workers,
		"time": simulation.run.simulation_time, "paused": simulation.run.clock.paused,
		"time_scale": simulation.run.clock.time_scale}


func music_state(pile_id: String) -> MusicState:
	if not simulation.run.colony.piles.has(pile_id):
		return MusicState.new()
	return MusicState.from_food_exchange(simulation.run.colony.piles[pile_id].food_exchange_state)


func quick_save() -> Dictionary:
	var accepted: bool = save_service.save(simulation.run)
	return {"accepted": accepted, "reason": save_service.last_error}


func quick_load() -> Dictionary:
	var accepted: bool = save_service.load_into(simulation)
	if accepted:
		if _outward_view != null:
			_outward_view.facing = 0.0
			_outward_view.selected_id = ""
		if _inward_view != null:
			_inward_view.selected_id = ""
		if _debug_view != null:
			_debug_view.snapshot_provider = simulation.run.to_dict
		if _audio_controller != null:
			_audio_controller.restart_after_load()
	return {"accepted": accepted, "reason": save_service.last_error}


func _show_save_feedback(result: Dictionary, success: String) -> void:
	var view: Node2D = _outward_view if mode == "outward" else _inward_view
	if view != null:
		view.call("show_feedback", success if result.accepted else result.reason)


func start_food_exchange() -> Dictionary:
	var accepted: bool = simulation.start_food_exchange("home")
	return {"accepted": accepted, "reason": simulation.food_exchange.last_error}


func start_brood() -> Dictionary:
	var accepted: bool = simulation.start_brood("home")
	return {"accepted": accepted, "reason": simulation.brood.last_error}


func start_adaptation(trait_id: String) -> Dictionary:
	var accepted: bool = simulation.start_adaptation("home", trait_id)
	return {"accepted": accepted, "reason": simulation.adaptation.last_error}


func start_nursery_development() -> Dictionary:
	var accepted: bool = simulation.start_nursery_development("home")
	return {"accepted": accepted, "reason": simulation.nursery.last_error}


func trail_summaries(pile_id: String) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for route: TrailRouteState in simulation.run.trails.routes.values():
		if route.origin_pile == pile_id:
			var segment: TrailSegmentState = simulation.run.trails.segments[route.segment_id]
			var checking: int = 0
			for cohort: TransitCohort in simulation.run.trails.cohorts.values():
				if cohort.route_id == route.id and cohort.detour != null:
					checking += 1
			summaries.append({"id": route.id, "destination_knowledge_id": route.destination_knowledge_id,
				"desired_workers": route.desired_workers, "allocated_workers": route.allocated_workers,
				"active_workers": route.active_workers, "checking_workers": checking, "status": route.status,
				"energy_limited": route.energy_limited,
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


func recheck_trail(route_id: String) -> Dictionary:
	var accepted: bool = simulation.recheck_trail(route_id)
	return {"accepted": accepted, "reason": simulation.trails.last_error}


func dispatch_facing(bearing: float) -> bool:
	return simulation.dispatch_scout("home", bearing)


func investigate_known_source(knowledge_id: String) -> Dictionary:
	var accepted: bool = simulation.investigate_known_source("home", knowledge_id)
	return {"accepted": accepted, "reason": simulation.scouting.last_error}


func debug_is_open() -> bool:
	return _debug_view != null and _debug_view.visible
