extends Node

const Controller = preload("res://src/core/simulation_controller.gd")
const Perception = preload("res://src/presentation/perception_model.gd")
const Pressure = preload("res://src/presentation/colony_pressure.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
const Inward = preload("res://src/presentation/inward/inward_view.gd")
const Audio = preload("res://src/audio/audio_controller.gd")
const Save = preload("res://src/core/save_service.gd")
const FOOD_CONFIG = preload("res://data/resources/default_food_exchange.tres")
const BROOD_CONFIG = preload("res://data/resources/default_brood.tres")
const NURSERY_CONFIG = preload("res://data/resources/default_nursery_development.tres")
const SANITATION_CONFIG = preload("res://data/resources/default_sanitation.tres")
const HONEYDEW_CONFIG = preload("res://data/ecology/backyard_honeydew.tres")
var simulation: SimulationController
var perception: PerceptionModel = Perception.new()
var _debug_view: Node
var _outward_view: Node2D
var _inward_view: Node2D
var _audio_controller: AudioController
var save_service: SaveService = Save.new()
var mode: String = "outward"
var audio_preferences: AudioPreferences = preload("res://src/audio/audio_preferences.gd").new()
var _audio_settings: AudioSettings
var _colony_controls: ColonyControls
var _discovery_notice: ReturnedDiscovery = preload("res://src/presentation/returned_discovery.gd").new()
var _discovery_reports: int = 0


func _ready() -> void:
	simulation = Controller.new()
	if OS.is_debug_build():
		print("[RUN] seed=%d scenario=%s time=%.2f" % [simulation.run.run_seed, simulation.run.scenario_id, simulation.run.simulation_time])
	if DisplayServer.get_name() != "headless":
		audio_preferences.load_file()
		var outward: OutwardView = Outward.new()
		outward.signal_provider = sensory_snapshot.bind("home")
		outward.status_provider = outward_status.bind("home")
		outward.dispatch_command = dispatch_facing
		outward.exploration_command = set_exploration
		outward.exploration_bias_command = set_exploration_bias
		outward.pause_command = simulation.toggle_pause
		outward.speed_command = simulation.set_time_scale
		outward.trail_create_command = create_trail_for
		outward.trail_set_command = set_trail_target
		outward.trail_recheck_command = recheck_trail
		outward.investigate_command = toggle_investigation_priority
		outward.honeydew_start_command = start_honeydew_tending
		outward.honeydew_stop_command = stop_honeydew_tending
		outward.input_blocked = interaction_blocked
		outward.mode_command = set_mode.bind("inward")
		outward.pressure_command = inspect_internal_pressure
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
		inward.midden_develop_command = start_midden
		inward.sanitation_command = set_sanitation_workers
		inward.humidity_command = set_humidity_workers
		inward.brood_command = start_brood
		inward.guest_rejection_command = set_guest_rejection
		inward.honeydew_command = set_honeydew_protection
		inward.adaptation_command = start_adaptation
		inward.input_blocked = interaction_blocked
		inward.save_command = quick_save
		inward.load_command = quick_load
		add_child(inward)
		_inward_view = inward
		var audio: AudioController = Audio.new()
		audio.preferences = audio_preferences
		audio.state_provider = music_state.bind("home")
		audio.alarm_provider = returned_losses.bind("home")
		audio.discovery_provider = discovery_report_count
		add_child(audio)
		_audio_controller = audio
		set_mode("outward")
		_audio_settings = preload("res://src/presentation/audio_settings.gd").new()
		_audio_settings.preferences = audio_preferences
		_audio_settings.changed = audio_preferences.save_file
		_audio_settings.blocked = sound_controls_blocked
		_audio_settings.z_index = 100
		add_child(_audio_settings)
		_colony_controls = preload("res://src/presentation/colony_controls.gd").new()
		_colony_controls.seed_provider = current_seed
		_colony_controls.scenario_provider = current_scenario
		_colony_controls.start_command = start_new_colony
		_colony_controls.blocked = colony_controls_blocked
		_colony_controls.z_index = 101
		add_child(_colony_controls)
	# Lazy load keeps truth-view code out of the headless runtime and release input path.
	if OS.is_debug_build() and DisplayServer.get_name() != "headless":
		_debug_view = load("res://src/debug/debug_world_view.gd").new()
		_debug_view.snapshot_provider = simulation.run.to_dict
		_debug_view.signal_provider = sensory_snapshot.bind("home")
		_debug_view.dispatch_command = simulation.dispatch_scout.bind("home")
		add_child(_debug_view)


func _process(delta: float) -> void:
	simulation.advance(delta)
	if _outward_view != null: poll_discovery_notice()


func discovery_report_count() -> int:
	return _discovery_reports


func poll_discovery_notice() -> String:
	var message: String = _discovery_notice.poll(sensory_snapshot("home"))
	if not message.is_empty():
		_discovery_reports += 1
		var view: Node2D = _outward_view if mode == "outward" else _inward_view
		if view != null: view.show_feedback(message)
	return message


func _unhandled_input(event: InputEvent) -> void:
	if interaction_blocked(): return
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


func interaction_blocked() -> bool:
	return debug_is_open() or _audio_settings != null and _audio_settings.opened or _colony_controls != null and _colony_controls.opened


func sound_controls_blocked() -> bool:
	return debug_is_open() or _colony_controls != null and _colony_controls.opened


func colony_controls_blocked() -> bool:
	return debug_is_open() or _audio_settings != null and _audio_settings.opened


func current_seed() -> int:
	return simulation.run.run_seed


func current_scenario() -> String:
	return simulation.run.scenario_id


func start_new_colony(seed_value: Variant, scenario: Variant = "") -> Dictionary:
	var next_scenario: Variant = current_scenario() if scenario is String and scenario.is_empty() else scenario
	if not simulation.start_new_run(seed_value, next_scenario):
		return {"accepted": false, "reason": "Invalid colony seed or scenario"}
	if _audio_settings != null: _audio_settings.opened = false
	if _colony_controls != null: _colony_controls.opened = false
	set_mode("outward")
	_refresh_loaded_views()
	return {"accepted": true, "reason": ""}


func sensory_snapshot(pile_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not simulation.run.colony.piles.has(pile_id):
		return result
	var origin: Vector2 = simulation.run.colony.piles[pile_id].position
	for signal_data: PerceivedSignal in perception.project(simulation.run.knowledge.nodes.values(), origin, simulation.run.simulation_time):
		var record: Dictionary = signal_data.to_dict()
		var route: TrailRouteState = simulation.run.trails.find_route(pile_id, signal_data.source_knowledge_id)
		record["foreign_contact"] = route != null and route.foreign_reports > 0
		record["conflict_report"] = route.conflict_report if route != null else ""
		if route != null and route.reported_losses > 0:
			record.risk = "reported_loss"
		result.append(record)
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
		"rain_phase": simulation.run.rain.phase, "temporal_hints": temporal_hints,
		"scout_missions": scout_mission_summaries(pile_id),
		"honeydew": honeydew_summary(pile_id), "exploration": exploration_summary(),
		"internal_attention": Pressure.attention(inward_status(pile_id))}


func inspect_internal_pressure() -> Dictionary:
	var attention: Dictionary = Pressure.attention(inward_status("home"))
	if attention.is_empty(): return {"accepted": false, "reason": "Internal conditions are steady"}
	if _inward_view != null:
		_inward_view.selected_id = attention.organ
		_inward_view._process(0)
	if _outward_view != null:
		_outward_view.sources_open = false
		_outward_view.exploration_open = false
	set_mode("inward")
	return {"accepted": true, "reason": ""}


func exploration_summary() -> Dictionary:
	return {"target": simulation.run.exploration.target, "bias": simulation.run.exploration.bias,
		"away": simulation.scouting.standing_count(), "priorities": simulation.run.exploration.priorities.duplicate()}


func toggle_investigation_priority(knowledge_id: String) -> Dictionary:
	var route: TrailRouteState = simulation.run.trails.find_route("home", knowledge_id)
	var recovery: bool = route != null and (route.status == "depleted" or route.resume_on_report)
	var enabled: bool = not route.resume_on_report if recovery else knowledge_id not in simulation.run.exploration.priorities
	var accepted: bool = simulation.set_investigation_priority(knowledge_id, enabled)
	if accepted and recovery:
		var watched: bool = simulation.trails.set_recovery_watch(route.id, enabled)
		assert(watched)
	return {"accepted": accepted, "reason": simulation.scouting.last_error,
		"standing_priority": true, "recovery_watch": recovery, "enabled": enabled, "exploration_off": simulation.run.exploration.target == 0}


func set_exploration(target: int) -> Dictionary:
	var accepted: bool = simulation.set_exploration(target)
	return {"accepted": accepted, "reason": simulation.scouting.last_error}


func set_exploration_bias(bearing: Variant) -> Dictionary:
	var accepted: bool = simulation.set_exploration_bias(bearing)
	return {"accepted": accepted, "reason": simulation.scouting.last_error}


func scout_mission_summaries(pile_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for memory: ScoutMissionMemory in simulation.run.scout_missions.values():
		if memory.origin_pile != pile_id:
			continue
		var record: Dictionary = memory.to_dict()
		record["age"] = simulation.run.simulation_time - memory.departed_at
		record["away_seconds"] = record.age if memory.returned_at < 0.0 else memory.returned_at - memory.departed_at
		result.append(record)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a.returned_at < 0.0) != (b.returned_at < 0.0):
			return a.returned_at < 0.0
		return a.departed_at > b.departed_at if a.departed_at != b.departed_at else a.id > b.id)
	return result


func honeydew_summary(pile_id: String) -> Dictionary:
	var producer_knowledge_id: String = "known:" + HONEYDEW_CONFIG.source_id
	if pile_id == "home" and simulation.run.knowledge.nodes.has(producer_knowledge_id):
		return {"knowledge_id": producer_knowledge_id,
			"relationship": simulation.run.honeydew.relationship,
			"protection_workers": simulation.run.honeydew.protection_workers,
			"required_workers": AdaptationRules.protection_workers(HONEYDEW_CONFIG.protection_workers, simulation.run.recognition_share(pile_id))}
	return {}


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
			trail_workers += route.allocated_workers + simulation.run.trails.pending_losses(route.id)
	var expected_total: int = pile.workers_total + simulation.run.trails.pending_for_pile(pile_id)
	var expected_adapted: int = pile.adapted_workers_total + simulation.run.trails.pending_for_pile(pile_id, true)
	var genetic_summary: Array[Dictionary] = []
	var adaptation_options: Dictionary = {}
	for trait_id: String in AdaptationRules.TRAITS:
		if trait_id == "persistent" and not pile.chemistry_candidate:
			continue
		if trait_id in ["security", "tolerance"] and not pile.recognition_candidate:
			continue
		adaptation_options[trait_id] = {"available": AdaptationRules.can_select(pile, trait_id),
			"costs": AdaptationRules.costs(trait_id), "inherited": trait_id in pile.genetics.established,
			"expressed": pile.genetics.count_trait(trait_id) + simulation.run.trails.pending_trait(pile_id, trait_id)}
	for trait_id: String in pile.genetics.established:
		var expressed: int = pile.genetics.count_trait(trait_id) + simulation.run.trails.pending_trait(pile_id, trait_id)
		genetic_summary.append({"id": trait_id, "expressed": expressed,
			"fraction": float(expressed) / expected_total if expected_total > 0 else 0.0})
	return {"pile_id": pile_id, "queens": pile.queen_count,
		"humidity": {"moisture": pile.humidity.moisture / 10000.0,
			"carers": pile.humidity.carers, "larval_rate": pile.humidity.larval_rate(),
			"water_used": pile.humidity.water_used_units / 100000.0},
		"midden": midden_summary(pile_id),
		"workers_total": expected_total, "workers_available": pile.workers_available,
		"brood": brood, "brood_matured_total": pile.brood_matured_total,
		"brood_losses": pile.brood_lost_total, "guest": guest_summary(pile_id),
		"honeydew": honeydew_summary(pile_id),
		"adaptation_repertoire": pile.adaptation_repertoire,
		"genetic_repertoire": genetic_summary,
		"adaptation_options": adaptation_options, "wet_trail_experience": pile.rain_trace_observed,
		"chemistry_persistence": AdaptationRules.CHEMISTRY.persistence_multiplier,
		"chemistry_extra_energy": AdaptationRules.CHEMISTRY.extra_travel_energy,
		"recognition_experience": pile.recognition_experience,
		"recognition_clearing_change": AdaptationRules.RECOGNITION.clearing_change,
		"recognition_labor_change": AdaptationRules.RECOGNITION.protection_worker_change,
		"adaptation_trial": pile.trial_cohort().to_dict() if pile.trial_cohort() != null else {},
		"adapted_workers": expected_adapted,
		"adaptation_fraction": float(expected_adapted) / expected_total if expected_total > 0 else 0.0,
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


func returned_losses(pile_id: String) -> int:
	var total: int = 0
	for route: TrailRouteState in simulation.run.trails.routes.values():
		if route.origin_pile == pile_id:
			total += route.reported_losses
	return total


func music_state(pile_id: String) -> MusicState:
	if not simulation.run.colony.piles.has(pile_id):
		return MusicState.new()
	var focus: String = _inward_view.selected_id if mode == "inward" and _inward_view != null else ""
	return MusicState.from_summary(inward_status(pile_id), focus)


func quick_save() -> Dictionary:
	var accepted: bool = save_service.save(simulation.run)
	return {"accepted": accepted, "reason": save_service.last_error}


func quick_load() -> Dictionary:
	var accepted: bool = save_service.load_into(simulation)
	if accepted:
		_refresh_loaded_views()
	return {"accepted": accepted, "reason": save_service.last_error}


func _refresh_loaded_views() -> void:
	_discovery_notice.baseline(sensory_snapshot("home"))
	_discovery_reports = 0
	if _outward_view != null:
		_outward_view.facing = 0.0
		_outward_view.selected_id = ""
		_outward_view.sources_open = false
		_outward_view.source_page = 0
		_outward_view._pointer_kind = ""
		_outward_view._feedback = ""
		_outward_view.reset_mission_visuals()
		_outward_view._process(0)
	if _inward_view != null:
		_inward_view.selected_id = ""
		_inward_view._focus_gains.clear()
		_inward_view.web_selection = "foraging"
		_inward_view.web_family = "foraging"
		_inward_view._feedback = ""
		_inward_view._process(0)
	if _debug_view != null:
		_debug_view.snapshot_provider = simulation.run.to_dict
		_debug_view.model.selected_id = "home"
	if _audio_controller != null:
		_audio_controller.restart_after_load()


func _show_save_feedback(result: Dictionary, success: String) -> void:
	var view: Node2D = _outward_view if mode == "outward" else _inward_view
	if view != null:
		view.call("show_feedback", success if result.accepted else result.reason)


func start_food_exchange() -> Dictionary:
	var accepted: bool = simulation.start_food_exchange("home")
	return {"accepted": accepted, "reason": simulation.food_exchange.last_error}


func midden_summary(pile_id: String) -> Dictionary:
	if not simulation.run.colony.piles.has(pile_id):
		return {}
	var state: SanitationState = simulation.run.colony.piles[pile_id].midden
	return {"revealed": state.revealed, "state": state.state,
		"burden": float(state.burden_units) / SANITATION_CONFIG.units_per_quantity,
		"cleaners": state.cleaners, "larval_rate": state.larval_rate(),
		"progress": float(state.progress_ticks) / SANITATION_CONFIG.build_ticks,
		"costs": SANITATION_CONFIG.costs(), "build_workers": SANITATION_CONFIG.build_workers,
		"build_seconds": SANITATION_CONFIG.build_ticks * SimulationClock.TICK_INTERVAL}


func start_midden() -> Dictionary:
	var accepted: bool = simulation.start_midden("home")
	return {"accepted": accepted, "reason": simulation.sanitation.last_error}


func set_sanitation_workers(target: int) -> Dictionary:
	var accepted: bool = simulation.set_sanitation_workers("home", target)
	return {"accepted": accepted, "reason": simulation.sanitation.last_error}


func set_humidity_workers(target: int) -> Dictionary:
	var accepted: bool = simulation.set_humidity_workers("home", target)
	return {"accepted": accepted, "reason": simulation.humidity.last_error}


func guest_summary(pile_id: String) -> Dictionary:
	if pile_id != "home" or simulation.run.guest.observation == "":
		return {}
	var state: GuestState = simulation.run.guest
	return {"observation": state.observation, "reported_losses": state.encounter_losses,
		"total_reported_losses": state.reported_losses,
		"rejection_active": state.phase == "rejecting", "workers_required": simulation.guest.CONFIG.rejection_workers,
		"workers_committed": simulation.run.colony.piles.home.workers.count("rejection:home")}


func set_guest_rejection(enabled: bool) -> Dictionary:
	var accepted: bool = simulation.start_guest_rejection() if enabled else simulation.stop_guest_rejection()
	return {"accepted": accepted, "reason": simulation.guest.last_error}


func start_brood() -> Dictionary:
	var accepted: bool = simulation.start_brood("home")
	return {"accepted": accepted, "reason": simulation.brood.last_error}


func start_adaptation(trait_id: String) -> Dictionary:
	var accepted: bool = simulation.start_adaptation("home", trait_id)
	return {"accepted": accepted, "reason": simulation.adaptation.last_error}


func start_nursery_development() -> Dictionary:
	var accepted: bool = simulation.start_nursery_development("home")
	return {"accepted": accepted, "reason": simulation.nursery.last_error}


func set_honeydew_protection(enabled: bool) -> Dictionary:
	var knowledge_id: String = "known:" + HONEYDEW_CONFIG.source_id
	return start_honeydew_tending(knowledge_id) if enabled else stop_honeydew_tending(knowledge_id)


func start_honeydew_tending(knowledge_id: String) -> Dictionary:
	if knowledge_id != "known:" + HONEYDEW_CONFIG.source_id or not simulation.run.knowledge.nodes.has(knowledge_id):
		return {"accepted": false, "reason": "Honeydew source unknown"}
	var accepted: bool = simulation.start_honeydew_tending("home")
	return {"accepted": accepted, "reason": simulation.ecology.last_error}


func stop_honeydew_tending(knowledge_id: String) -> Dictionary:
	if knowledge_id != "known:" + HONEYDEW_CONFIG.source_id or not simulation.run.knowledge.nodes.has(knowledge_id):
		return {"accepted": false, "reason": "Honeydew source unknown"}
	var accepted: bool = simulation.stop_honeydew_tending("home")
	return {"accepted": accepted, "reason": simulation.ecology.last_error}


func trail_summaries(pile_id: String) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for route: TrailRouteState in simulation.run.trails.routes.values():
		if route.origin_pile == pile_id:
			var segment: TrailSegmentState = simulation.run.trails.segments[route.segment_id]
			var checking: int = 0
			for cohort: TransitCohort in simulation.run.trails.cohorts.values():
				if cohort.route_id == route.id and cohort.detour != null:
					checking += 1
			var pending: int = simulation.run.trails.pending_losses(route.id)
			var status: String = route.status
			if pending > 0 and status == "inactive":
				status = "recalling" if route.desired_workers == 0 else "depleted" if route.reported_depleted else "active"
			summaries.append({"id": route.id, "destination_knowledge_id": route.destination_knowledge_id,
				"desired_workers": route.desired_workers, "allocated_workers": route.allocated_workers + pending,
				"active_workers": route.active_workers + pending, "checking_workers": checking, "status": status,
				"conflict_report": route.conflict_report, "conflict_observed_at": route.conflict_observed_at,
				"foreign_reports": route.foreign_reports, "last_foreign_time": route.last_foreign_time,
				"reported_losses": route.reported_losses, "last_loss_time": route.last_loss_time,
				"attack_reports": route.attack_reports, "fighting_reports": route.fighting_reports,
				"missing_workers": route.missing_workers, "last_witness_time": route.last_witness_time,
				"energy_limited": route.energy_limited,
				"resume_on_report": route.resume_on_report,
				"recovery_ready": simulation.run.knowledge.recovery_report(route.destination_knowledge_id, route.last_empty_report_at),
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
