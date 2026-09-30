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
		return
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
		segment.pheromone_strength = snappedf(segment.pheromone_strength * pow(0.5, delta * segment.exposure / CONFIG.exposed_chemical_half_life_seconds), 0.0000000001)
		if segment.pheromone_strength < 0.0001:
			segment.pheromone_strength = 0.0
	var next_elapsed: float = minf(CONFIG.duration_seconds, state.elapsed_seconds + delta)
	var raining_seconds: float = next_elapsed - state.elapsed_seconds
	for pile: PileState in _run.colony.piles.values():
		assert(pile.deposit_resource("water", CONFIG.water_per_second * raining_seconds))
	state.elapsed_seconds = next_elapsed
	if state.elapsed_seconds >= CONFIG.duration_seconds:
		state.phase = "finished"
