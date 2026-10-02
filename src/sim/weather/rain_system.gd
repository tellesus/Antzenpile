class_name RainSystem
extends RefCounted
## Runs after trail traffic; washes exposed chemistry without editing memory.

signal rain_started

const CONFIG = preload("res://data/weather/default_rain.tres")
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state


func tick(delta: float) -> void:
	var state: RainState = _run.rain
	if state.phase == "finished":
		if _run.clock.tick_count < state.next_start_tick:
			return
		state.phase = "raining"
		state.elapsed_seconds = 0.0
		state.next_start_tick = 0
		rain_started.emit()
	if state.phase == "waiting":
		var sheltered: bool = false
		var exposed: bool = false
		for segment: TrailSegmentState in _run.trails.segments.values():
			if segment.traffic < CONFIG.minimum_successful_workers:
				continue
			sheltered = sheltered or segment.exposure <= CONFIG.sheltered_max_exposure
			exposed = exposed or segment.exposure >= CONFIG.exposed_min_exposure
		if not sheltered or not exposed:
			return
		state.phase = "raining"
		rain_started.emit()
	for segment: TrailSegmentState in _run.trails.segments.values():
		segment.decay_chemistry(delta * segment.exposure / CONFIG.exposed_chemical_half_life_seconds)
	var next_elapsed: float = minf(CONFIG.duration_seconds, state.elapsed_seconds + delta)
	var raining_seconds: float = next_elapsed - state.elapsed_seconds
	for pile: PileState in _run.colony.piles.values():
		assert(pile.deposit_resource("water", CONFIG.water_per_second * raining_seconds))
	_refill_exterior_water(raining_seconds)
	state.elapsed_seconds = next_elapsed
	if state.elapsed_seconds >= CONFIG.duration_seconds:
		state.phase = "finished"
		state.fronts_completed += 1
		state.next_start_tick = _run.clock.tick_count + CONFIG.dry_interval_ticks


func _refill_exterior_water(raining_seconds: float) -> void:
	if not ScenarioCatalog.uses_backyard_ecology(_run.scenario_id) or not _run.world.nodes.has(CONFIG.exterior_water_source_id):
		return
	var source: WorldNodeState = _run.world.nodes[CONFIG.exterior_water_source_id]
	assert(source.definition_id == "water")
	var added: float = minf(CONFIG.exterior_water_per_second * raining_seconds, maxf(0.0, CONFIG.exterior_water_capacity - source.quantity))
	if added <= 0.0:
		return
	source.quantity = minf(CONFIG.exterior_water_capacity, snappedf(source.quantity + added, 0.00001))
	source.active = true
